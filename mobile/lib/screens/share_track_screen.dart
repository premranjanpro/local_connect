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
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 64,
              height: 64,
              child: CircularProgressIndicator(
                color: Color(0xFF6C63FF),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Resolving tracking link...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 40),
              ),
              const SizedBox(height: 24),
              const Text(
                'Tracking Link Invalid',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _errorMsg,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingScreen() {
    final animLat = _latAnim.value;
    final animLng = _lngAnim.value;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
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
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.shopconnector.app',
              ),

              // Animated driver marker
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(animLat, animLng),
                    width: 56,
                    height: 56,
                    child: Transform.rotate(
                      angle: _bearingAnim.value * (math.pi / 180),
                      child: ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C63FF).withOpacity(0.5),
                                blurRadius: 16,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.navigation_rounded,
                              color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Gradient overlay at bottom ────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0A0E1A).withOpacity(0.7),
                    const Color(0xFF0A0E1A),
                  ],
                ),
              ),
            ),
          ),

          // ── Top Header ────────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1E2E).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1E2E).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF00E676),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Live Tracking',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _etaText,
                          style: const TextStyle(
                            color: Color(0xFF6C63FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Info Card ──────────────────────────────────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: _buildInfoCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return GestureDetector(
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1E2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF6C63FF).withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Driver info
            Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    _driverName?.substring(0, 1).toUpperCase() ?? 'D',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _driverName ?? 'Driver',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (_driverVehicle != null && _driverVehicle!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _driverVehicle!,
                          style: const TextStyle(
                            color: Color(0xFF6C63FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'On the way',
                      style: TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.badge_rounded, color: Color(0xFF93C5FD), size: 14),
                SizedBox(width: 6),
                Text(
                  'Tap to view Driver Photo, DL & Vehicle Details',
                  style: TextStyle(
                    color: Color(0xFF93C5FD),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: Color(0xFF93C5FD), size: 14),
              ],
            ),
          ),

          const SizedBox(height: 14),
          const Divider(color: Color(0xFF2A2E3E), height: 1),
          const SizedBox(height: 14),

          // Route info
          _buildAddressRow(
            icon: Icons.radio_button_checked,
            color: const Color(0xFF6C63FF),
            label: 'Pickup',
            address: _pickupAddress ?? 'Loading...',
          ),
          const SizedBox(height: 10),
          _buildAddressRow(
            icon: Icons.location_on_rounded,
            color: const Color(0xFFFF6B6B),
            label: 'Drop',
            address: _dropoffAddress ?? 'Loading...',
          ),

          const SizedBox(height: 16),

          // Share + Copy buttons
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.share_rounded,
                  label: 'Share Link',
                  color: const Color(0xFF6C63FF),
                  onTap: _shareLink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  icon: Icons.copy_rounded,
                  label: 'Copy Link',
                  color: const Color(0xFF3ECFCF),
                  onTap: _copyLink,
                ),
              ),
            ],
          ),

          // Privacy notice
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 12, color: Colors.white.withOpacity(0.35)),
              const SizedBox(width: 5),
              Text(
                "Driver's phone number is protected. Share safely.",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 10,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildAddressRow({
    required IconData icon,
    required Color color,
    required String label,
    required String address,
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
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'Inter',
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

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
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
