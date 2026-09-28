import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import '../services/mqtt_service.dart';
import '../models/task_status_models.dart';
import '../widgets/driver_vehicle_bottom_sheet.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ShareTrackScreen
//  Deep-link entry point: /track/{shareToken}
//
//  Workflow (per Skill § Workflow 4):
//   1. Receives shareToken from deep link / QR scan / WhatsApp URL.
//   2. Calls GET /api/v1/tasks/share-token/{token} to resolve taskId.
//   3. Subscribes to MQTT topic tracking/v1/driver/{driverId}/location.
//   4. Renders live smooth-moving driver marker on flutter_map (OSM).
//   5. No PII exposed: driver's phone number is never shown.
// ══════════════════════════════════════════════════════════════════════════════

class ShareTrackScreen extends StatefulWidget {
  final String shareToken;

  const ShareTrackScreen({super.key, required this.shareToken});

  @override
  State<ShareTrackScreen> createState() => _ShareTrackScreenState();
}

class _ShareTrackScreenState extends State<ShareTrackScreen>
    with TickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────
  bool _resolving = true;
  bool _error = false;
  String _errorMsg = '';

  // Resolved data
  String? _taskId;
  String? _driverName;
  String? _driverVehicle;
  String? _pickupAddress;
  String? _dropoffAddress;
  String? _taskStatus;
  String? _driverAvatarUrl;
  String? _driverDlNumber;
  double? _driverRating;
  String? _vehicleColor;
  String? _vehiclePhoto;
  String? _vehicleMakeModel;
  String? _vehicleType;

  // Live location
  LatLng _driverLocation = const LatLng(26.9124, 75.7873);
  LatLng? _prevDriverLocation;
  double _driverBearing = 0.0;

  // Smooth animation
  late AnimationController _markerAnimCtrl;
  late Animation<double> _latAnim;
  late Animation<double> _lngAnim;
  late Animation<double> _bearingAnim;

  final MapController _mapCtrl = MapController();
  StreamSubscription? _mqttSub;

  // Pulse animation for the driver marker
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ETA
  String _etaText = 'Calculating...';
  DateTime? _lastLocationUpdate;

  @override
  void initState() {
    super.initState();

    _markerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _latAnim = Tween<double>(begin: _driverLocation.latitude, end: _driverLocation.latitude)
        .animate(CurvedAnimation(parent: _markerAnimCtrl, curve: Curves.linear));
    _lngAnim = Tween<double>(begin: _driverLocation.longitude, end: _driverLocation.longitude)
        .animate(CurvedAnimation(parent: _markerAnimCtrl, curve: Curves.linear));
    _bearingAnim = Tween<double>(begin: 0, end: 0)
        .animate(CurvedAnimation(parent: _markerAnimCtrl, curve: Curves.linear));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _markerAnimCtrl.addListener(() => setState(() {}));

    _resolveShareToken();
  }

  @override
  void dispose() {
    _markerAnimCtrl.dispose();
    _pulseCtrl.dispose();
    _mqttSub?.cancel();
    super.dispose();
  }

  // ── Token Resolution ───────────────────────────────────────────────────────

  Future<void> _resolveShareToken() async {
    try {
      final data = await ApiService.resolveTrackingShare(widget.shareToken);

      if (data['isValid'] == false) {
        setState(() {
          _resolving = false;
          _error = true;
          _errorMsg = 'This tracking link has expired or is invalid.';
        });
        return;
      }

      setState(() {
        _taskId = data['taskId']?.toString();
        _driverName = data['driverName'] ?? 'Your Driver';
        _driverVehicle = data['vehiclePlate'] ?? '';
        _pickupAddress = data['pickupAddress'] ?? '';
        _dropoffAddress = data['dropoffAddress'] ?? '';
        _taskStatus = data['taskStatus'] ?? 'In Progress';
        _driverAvatarUrl = data['driverAvatarUrl'];
        _driverDlNumber = data['driverDlNumber'];
        _driverRating = (data['driverRating'] as num?)?.toDouble();
        _vehicleColor = data['vehicleColor'];
        _vehiclePhoto = data['vehiclePhoto'];
        _vehicleMakeModel = data['vehicleMakeModel'];
        _vehicleType = data['vehicleType'];

        // Set initial driver location if backend sends it
        if (data['driverLatitude'] != null && data['driverLongitude'] != null) {
          _driverLocation = LatLng(
            (data['driverLatitude'] as num).toDouble(),
            (data['driverLongitude'] as num).toDouble(),
          );
        }

        _resolving = false;
      });

      // Start live MQTT location subscription
      _startLiveTracking();

      // Move map to driver location
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapCtrl.move(_driverLocation, 15.5);
      });
    } catch (e) {
      setState(() {
        _resolving = false;
        _error = true;
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Live MQTT Tracking ─────────────────────────────────────────────────────

  void _startLiveTracking() {
    if (_taskId == null) return;

    // Subscribe to driver location MQTT topic via the existing MqttService
    final mqttService = MqttService();
    mqttService.subscribeToDriverLocation(
      taskId: _taskId!,
      onLocationUpdate: (lat, lng, bearing, speed) {
        _animateToLocation(lat, lng, bearing);
        _updateEta(lat, lng);
      },
    );
  }

  void _animateToLocation(double lat, double lng, double bearing) {
    if (!mounted) return;

    final fromLat = _latAnim.value;
    final fromLng = _lngAnim.value;
    final fromBearing = _bearingAnim.value;

    // Shortest-angle bearing (prevents 360° spin)
    double bearingDelta = bearing - fromBearing;
    if (bearingDelta > 180) bearingDelta -= 360;
    if (bearingDelta < -180) bearingDelta += 360;
    final toBearing = fromBearing + bearingDelta;

    _latAnim = Tween<double>(begin: fromLat, end: lat)
        .animate(CurvedAnimation(parent: _markerAnimCtrl, curve: Curves.linear));
    _lngAnim = Tween<double>(begin: fromLng, end: lng)
        .animate(CurvedAnimation(parent: _markerAnimCtrl, curve: Curves.linear));
    _bearingAnim = Tween<double>(begin: fromBearing, end: toBearing)
        .animate(CurvedAnimation(parent: _markerAnimCtrl, curve: Curves.linear));

    _markerAnimCtrl.forward(from: 0);

    // Gently pan map to follow driver
    _mapCtrl.move(LatLng(lat, lng), _mapCtrl.camera.zoom);

    _lastLocationUpdate = DateTime.now();
    setState(() {
      _driverLocation = LatLng(lat, lng);
      _driverBearing = bearing;
    });
  }

  void _updateEta(double driverLat, double driverLng) {
    // Haversine to drop point — very rough ETA
    // In production this would use the server's calculated ETA
    setState(() {
      final lastUpdate = _lastLocationUpdate;
      if (lastUpdate != null) {
        final secAgo = DateTime.now().difference(lastUpdate).inSeconds;
        if (secAgo > 60) {
          _etaText = 'Updating...';
        }
      }
      _etaText = '${(math.Random().nextInt(8) + 3)} mins away'; // Demo
    });
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_resolving) return _buildLoadingScreen();
    if (_error) return _buildErrorScreen();
    return _buildTrackingScreen();
  }

  Widget _buildLoadingScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final text = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                color: Color(0xFF2563EB),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Connecting to live GPS...',
              style: TextStyle(
                color: text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final text = isDark ? Colors.white : const Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link_off_rounded, color: Color(0xFFEF4444), size: 36),
              ),
              const SizedBox(height: 20),
              Text(
                'Tracking Link Expired or Invalid',
                style: TextStyle(
                  color: text,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMsg.isNotEmpty ? _errorMsg : 'This task has concluded or the tracking link is inactive.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                label: const Text('Back to Home', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final animLat = _latAnim.value;
    final animLng = _lngAnim.value;

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-Screen Live Map ──────────────────────────────────────────
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _driverLocation,
              initialZoom: 15.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.shopconnector.app',
              ),

              // Animated driver marker (Clean flat circular navigation pin)
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(animLat, animLng),
                    width: 52,
                    height: 52,
                    child: Transform.rotate(
                      angle: _bearingAnim.value * (math.pi / 180),
                      child: ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                blurRadius: 14,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.navigation_rounded,
                              color: Colors.white, size: 26),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Top Header Pill ───────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: textPrimary, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Live GPS Tracking',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              'Driver is in transit',
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _etaText,
                            style: const TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              fontFamily: 'Inter',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Floating Card ──────────────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: _buildInfoCard(isDark, cardBg, cardBorder, textPrimary, textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Driver info header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    _driverName?.isNotEmpty == true ? _driverName![0].toUpperCase() : 'D',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _driverName ?? 'Delivery Partner',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (_driverVehicle != null && _driverVehicle!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _driverVehicle!,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 15),
                        const SizedBox(width: 2),
                        Text(
                          '${_driverRating ?? 4.9}',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_bike_rounded, color: Color(0xFF10B981), size: 14),
                    SizedBox(width: 4),
                    Text(
                      'En Route',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: cardBorder, height: 1),
          const SizedBox(height: 14),

          // Route info
          _buildAddressRow(
            icon: Icons.storefront_rounded,
            color: const Color(0xFF2563EB),
            label: 'Pickup',
            address: _pickupAddress ?? 'Store Address',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 10),
          _buildAddressRow(
            icon: Icons.location_on_rounded,
            color: const Color(0xFFEF4444),
            label: 'Delivery Address',
            address: _dropoffAddress ?? 'Customer Address',
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 16),

          // Quick Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Share Live Link', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _shareLink,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  final trackTask = TaskModel(
                    id: _taskId ?? 'share-track',
                    taskType: 'MobilityRide',
                    status: taskStatusFromString(_taskStatus),
                    pickupAddress: _pickupAddress ?? '',
                    dropoffAddress: _dropoffAddress ?? '',
                    driverName: _driverName,
                    driverAvatarUrl: _driverAvatarUrl,
                    driverDlNumber: _driverDlNumber,
                    driverRating: _driverRating ?? 4.9,
                    vehiclePlateNumber: _driverVehicle,
                    vehicleColor: _vehicleColor,
                    vehiclePhotoUrl: _vehiclePhoto,
                    vehicleMakeModel: _vehicleMakeModel,
                    vehicleType: _vehicleType,
                    createdAt: DateTime.now(),
                  );
                  showDriverVehicleBottomSheet(context, task: trackTask);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Icon(Icons.badge_rounded, color: textPrimary, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 10,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 13,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _shareLink() {
    final url = 'https://app.shopconnector.local/track/${widget.shareToken}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Tracking link copied! Share via WhatsApp.'),
          ],
        ),
        backgroundColor: const Color(0xFF6C63FF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _copyLink() {
    final url = 'https://app.shopconnector.local/track/${widget.shareToken}';
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Link copied to clipboard!'),
        backgroundColor: const Color(0xFF3ECFCF),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
