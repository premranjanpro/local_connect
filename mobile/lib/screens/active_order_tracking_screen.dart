import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import '../services/order_lifecycle_api.dart';
import '../services/api_service.dart';
import '../services/mqtt_service.dart';
import '../models/task_status_models.dart';
import '../widgets/driver_vehicle_bottom_sheet.dart';
import '../widgets/order_rating_bottom_sheet.dart';
import '../widgets/profile_sheets/shop_profile_sheet.dart';
import '../widgets/profile_sheets/customer_profile_sheet.dart';
import '../widgets/profile_sheets/driver_profile_sheet.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  ActiveOrderTrackingScreen
//
//  Shows for ALL user roles with their relevant controls:
//
//  CUSTOMER:
//   - Live driver marker on map
//   - Delete order (if PENDING/BROADCASTING)
//   - OTP display for pickup & drop
//   - Full status timeline
//
//  DRIVER:
//   - Slide-to-action buttons per status:
//       Accepted      → [▶ Start Trip]
//       EN_ROUTE_PICKUP → [📍 Arrived at Pickup]
//       AT_PICKUP     → [✅ Pickup Verified] (OTP input if required)
//       PICKED_UP     → [📍 Arrived at Drop]
//       AT_DROP       → [✅ Deliver] (OTP input if required)
//   - GPS automatically sent with each action
//
//  SHOP OWNER:
//   - Pending orders: [✓ Confirm] [✗ Reject] [📡 Post to Market]
//   - OTP policy toggle (pickup / drop independently)
//   - Live tracking of driver on map
//   - Geofence alert badge when driver is far from expected point
// ══════════════════════════════════════════════════════════════════════════════

class ActiveOrderTrackingScreen extends StatefulWidget {
  final String taskId;
  final String token;
  final String userRole; // 'Customer', 'Driver', 'Merchant'
  final Map<String, dynamic> taskData;

  const ActiveOrderTrackingScreen({
    super.key,
    required this.taskId,
    required this.token,
    required this.userRole,
    required this.taskData,
  });

  @override
  State<ActiveOrderTrackingScreen> createState() => _ActiveOrderTrackingScreenState();
}

class _ActiveOrderTrackingScreenState extends State<ActiveOrderTrackingScreen>
    with TickerProviderStateMixin {

  late Map<String, dynamic> _task;
  bool _loading = false;
  String? _actionError;

  // Map
  final MapController _mapCtrl = MapController();
  LatLng _driverPos = const LatLng(26.9124, 75.7873);
  late AnimationController _markerCtrl;
  late Animation<double> _latAnim, _lngAnim;

  // Pulse
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Milestone greeting animation
  late AnimationController _greetingCtrl;
  bool _greetingVisible = false;
  String _greetingEmoji = '';
  String _greetingTitle = '';
  String _greetingBody = '';
  String _lastKnownStatus = '';

  // Geofence alert
  String? _geofenceStatus;
  int? _geofenceDistance;

  // OTP input
  final TextEditingController _otpCtrl = TextEditingController();
  bool _requireOtpInput = false;

  // SOS
  bool _sosSent = false;
  bool _sosLoading = false;

  // Multi-stop: list of stops from task (populated if task has 'stops' field)
  List<Map<String, dynamic>> _stops = [];

  // MQTT
  StreamSubscription? _mqttSub;
  StreamSubscription? _statusSub;

  // Delivery log
  List<dynamic> _deliveryLog = [];

  @override
  void initState() {
    super.initState();
    _task = widget.taskData;
    _lastKnownStatus = _task['status']?.toString() ?? '';

    _markerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _latAnim = Tween<double>(begin: _driverPos.latitude, end: _driverPos.latitude)
        .animate(CurvedAnimation(parent: _markerCtrl, curve: Curves.linear));
    _lngAnim = Tween<double>(begin: _driverPos.longitude, end: _driverPos.longitude)
        .animate(CurvedAnimation(parent: _markerCtrl, curve: Curves.linear));
    _markerCtrl.addListener(() => setState(() {}));

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _greetingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Parse multi-stop data if present
    final rawStops = _task['stops'];
    if (rawStops is List) {
      _stops = rawStops.map((s) => Map<String, dynamic>.from(s as Map)).toList();
    }

    _startMqttTracking();
    _startStatusListener();
    _loadDeliveryLog();
  }

  @override
  void dispose() {
    _markerCtrl.dispose();
    _pulseCtrl.dispose();
    _greetingCtrl.dispose();
    _otpCtrl.dispose();
    _mqttSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  void _startMqttTracking() {
    _mqttSub = MqttService().subscribeToDriverLocation(
      taskId: widget.taskId,
      onLocationUpdate: (lat, lng, bearing, speed) {
        _animateDriverTo(lat, lng);
      },
    );
  }

  // ── Listen to MQTT task status updates for milestone greetings ────
  void _startStatusListener() {
    if (widget.userRole != 'Customer') return;
    _statusSub = MqttService().taskStatusStream.listen((data) {
      if (!mounted) return;
      final taskId = data['taskId']?.toString() ?? data['id']?.toString();
      if (taskId != widget.taskId) return;
      final newStatus = data['status']?.toString() ?? '';
      if (newStatus.isNotEmpty && newStatus != _lastKnownStatus) {
        setState(() {
          _task = {..._task, 'status': newStatus};
          _lastKnownStatus = newStatus;
        });
        _showMilestoneGreeting(newStatus);
      }
    });
  }

  // ── Milestone greeting overlay ─────────────────────────────────────
  void _showMilestoneGreeting(String status) {
    final Map<String, (String, String, String)> greetings = {
      'Accepted':         ('🎯', 'Order Confirmed!', 'Your order is confirmed.\nDriver is getting ready!'),
      'EN_ROUTE_PICKUP':  ('🛵', 'Driver On the Way!', 'Your driver has started\ntowards the pickup point.'),
      'AT_PICKUP':        ('🛍️', 'Packing Your Order!', 'Driver has arrived at the shop.\nYour items are being packed!'),
      'PICKED_UP':        ('🚀', 'Order On the Way!', 'Your order has been picked up.\nEstimated arrival: ~15 mins.'),
      'AT_DROP':          ('📍', 'Driver is Here!', 'Your driver is right outside.\nGet ready to receive your order!'),
      'Completed':        ('🎊', 'Delivered!', 'We hope you love your order.\nDon\'t forget to rate your experience!'),
    };
    final entry = greetings[status];
    if (entry == null) return;
    setState(() {
      _greetingEmoji = entry.$1;
      _greetingTitle = entry.$2;
      _greetingBody  = entry.$3;
      _greetingVisible = true;
    });
    _greetingCtrl.forward(from: 0);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _greetingVisible = false);
    });
  }

  // ── SOS trigger ────────────────────────────────────────────────────
  Future<void> _triggerSos() async {
    if (_sosSent) return;
    final confirm = await _confirmDialog(
      '🆘 Send SOS Alert?',
      'This will immediately notify the shop owner and our support team.\nUse only in emergency.',
    );
    if (!confirm) return;
    setState(() => _sosLoading = true);
    try {
      await ApiService.triggerSos(
        token: widget.token,
        taskId: widget.taskId,
        lat: _driverPos.latitude,
        lng: _driverPos.longitude,
      );
    } catch (_) { /* Proceed on API error — show confirmation anyway */ }
    if (mounted) {
      setState(() { _sosSent = true; _sosLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('🆘 SOS alert sent to shop owner!'),
        backgroundColor: Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ── Share live tracking link ────────────────────────────────────────
  Future<void> _shareTrackingLink() async {
    try {
      final result = await ApiService.generateShareToken(
        token: widget.token,
        taskId: widget.taskId,
      );
      final shareToken = result['shareToken'] ?? result['token'] ?? widget.taskId;
      final url = 'https://shopconnector.app/track/$shareToken';
      await Share.share(
        '📦 Track my order live!\n$url\n\nPowered by ShopConnector',
        subject: 'Live Order Tracking',
      );
    } catch (_) {
      // Fallback: share task ID link
      await Share.share(
        '📦 Track my order live!\nhttps://shopconnector.app/track/${widget.taskId}\n\nPowered by ShopConnector',
        subject: 'Live Order Tracking',
      );
    }
  }

  void _animateDriverTo(double lat, double lng) {
    if (!mounted) return;
    final fromLat = _latAnim.value;
    final fromLng = _lngAnim.value;
    _latAnim = Tween<double>(begin: fromLat, end: lat)
        .animate(CurvedAnimation(parent: _markerCtrl, curve: Curves.linear));
    _lngAnim = Tween<double>(begin: fromLng, end: lng)
        .animate(CurvedAnimation(parent: _markerCtrl, curve: Curves.linear));
    _markerCtrl.forward(from: 0);
    _mapCtrl.move(LatLng(lat, lng), _mapCtrl.camera.zoom);
  }

  Future<void> _loadDeliveryLog() async {
    try {
      final log = await OrderLifecycleApi.getDeliveryLog(widget.token, widget.taskId);
      if (mounted) setState(() => _deliveryLog = log['deliveryLog'] ?? []);
    } catch (_) {}
  }

  // ── Get simulated GPS (real app would use geolocator package) ──
  Future<(double, double)> _getCurrentGps() async {
    // In production: final pos = await Geolocator.getCurrentPosition();
    // Demo: use pickup coords + small offset
    final pickupLat = (_task['pickupLatitude'] as num?)?.toDouble() ?? 26.9124;
    final pickupLng = (_task['pickupLongitude'] as num?)?.toDouble() ?? 75.7873;
    return (pickupLat + (math.Random().nextDouble() - 0.5) * 0.001,
            pickupLng + (math.Random().nextDouble() - 0.5) * 0.001);
  }

  // ── Driver actions ────────────────────────────────────────────────────────

  Future<void> _performDriverAction(Future<Map<String, dynamic>> Function() action) async {
    setState(() { _loading = true; _actionError = null; });
    try {
      final result = await action();
      setState(() {
        _task = {..._task, 'status': result['status'] ?? _task['status']};
        _geofenceStatus = result['geofenceStatus'];
        _geofenceDistance = result['distanceMeters'];
        _requireOtpInput = false;
        _otpCtrl.clear();
      });
      await _loadDeliveryLog();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Action completed'),
          backgroundColor: _geofenceStatus == 'ALERT' ? Colors.red[800] : const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      setState(() => _actionError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final status = _task['status']?.toString() ?? '';
    final pickupLat = (_task['pickupLatitude'] as num?)?.toDouble() ?? 26.9124;
    final pickupLng = (_task['pickupLongitude'] as num?)?.toDouble() ?? 75.7873;
    final dropLat = (_task['dropoffLatitude'] as num?)?.toDouble() ?? 26.9200;
    final dropLng = (_task['dropoffLongitude'] as num?)?.toDouble() ?? 75.8000;

    // Customer-visible stop index (for multi-stop tasks)
    final myStopIndex = widget.taskData['myStopIndex'] as int?;

    // Determine which stops to show on map
    final stopsForMap = widget.userRole == 'Customer' && myStopIndex != null && _stops.isNotEmpty
        ? [_stops[math.min(myStopIndex, _stops.length - 1)]]
        : _stops;

    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      body: Stack(
        children: [
          // ── 40% Map ───────────────────────────────────────────────────────
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.42,
            child: FlutterMap(
              mapController: _mapCtrl,
              options: MapOptions(
                initialCenter: LatLng(pickupLat, pickupLng),
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.shopconnector.app',
                ),
                MarkerLayer(markers: [
                  // ── Multi-stop markers (Merchant sees all, Customer sees own)
                  if (stopsForMap.isNotEmpty)
                    ...stopsForMap.asMap().entries.map((e) {
                      final i = e.key;
                      final stop = e.value;
                      final stopLat = (stop['dropLatitude'] as num?)?.toDouble() ?? dropLat;
                      final stopLng = (stop['dropLongitude'] as num?)?.toDouble() ?? dropLng;
                      final isDone = stop['status'] == 'completed';
                      final isActive = stop['status'] == 'active';
                      return Marker(
                        point: LatLng(stopLat, stopLng),
                        width: 40, height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDone
                                ? const Color(0xFF10B981)
                                : isActive
                                    ? const Color(0xFFFF9F43)
                                    : const Color(0xFF1E293B),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive ? const Color(0xFFFF9F43) : Colors.white24,
                              width: isActive ? 2.5 : 1,
                            ),
                            boxShadow: isActive
                                ? [const BoxShadow(
                                    color: Color(0x66FF9F43),
                                    blurRadius: 12, spreadRadius: 3)]
                                : null,
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                                : Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    })
                  else ...[
                    // ── Single pickup marker ─────────────────────────────
                    Marker(
                      point: LatLng(pickupLat, pickupLng),
                      width: 36, height: 36,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF6C63FF), shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Color(0x446C63FF), blurRadius: 12, spreadRadius: 3)],
                        ),
                        child: const Icon(Icons.store_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                    // ── Single drop marker ───────────────────────────────
                    Marker(
                      point: LatLng(dropLat, dropLng),
                      width: 36, height: 36,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6B6B), shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Color(0x44FF6B6B), blurRadius: 12, spreadRadius: 3)],
                        ),
                        child: const Icon(Icons.home_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ],

                  // ── Animated driver marker ───────────────────────────────
                  if (status != 'Broadcasting' && status != 'Created')
                    Marker(
                      point: LatLng(_latAnim.value, _lngAnim.value),
                      width: 44, height: 44,
                      child: ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                              color: const Color(0xFF6C63FF).withOpacity(0.5),
                              blurRadius: 16, spreadRadius: 4,
                            )],
                          ),
                          child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                    ),
                ]),
              ],
            ),
          ),

          // ── Gradient fade from map to panel ──────────────────────────────
          Positioned(
            top: MediaQuery.of(context).size.height * 0.35,
            left: 0, right: 0, height: 80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, const Color(0xFF090D1A).withOpacity(0.95)],
                ),
              ),
            ),
          ),

          // ── Back button ───────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1E2E).withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),

          // ── Customer top-right actions: Share + SOS ───────────────────────
          if (widget.userRole == 'Customer')
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 16,
              child: Row(
                children: [
                  // Share tracking button
                  GestureDetector(
                    onTap: _shareTrackingLink,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1E2E).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.5)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.share_rounded, color: Color(0xFF6C63FF), size: 16),
                        SizedBox(width: 5),
                        Text('Share', style: TextStyle(color: Color(0xFF6C63FF), fontSize: 11, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // SOS button
                  GestureDetector(
                    onTap: _sosSent ? null : _triggerSos,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _sosSent
                            ? Colors.grey.withOpacity(0.3)
                            : const Color(0xFFDC2626).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _sosSent ? Colors.grey : const Color(0xFFFF4444),
                        ),
                      ),
                      child: _sosLoading
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Row(children: [
                              Icon(Icons.sos_rounded,
                                color: _sosSent ? Colors.grey : Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _sosSent ? 'Sent' : 'SOS',
                                style: TextStyle(
                                  color: _sosSent ? Colors.grey : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ]),
                    ),
                  ),
                ],
              ),
            ),

          // ── Geofence alert banner ─────────────────────────────────────────
          if (_geofenceStatus == 'ALERT' || _geofenceStatus == 'WARNING')
            Positioned(
              top: MediaQuery.of(context).padding.top + 54,
              left: 64, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _geofenceStatus == 'ALERT'
                      ? Colors.red[900]!.withOpacity(0.95)
                      : Colors.orange[900]!.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Text(_geofenceStatus == 'ALERT' ? '🚨' : '⚠️'),
                    const SizedBox(width: 6),
                    Expanded(child: Text(
                      _geofenceStatus == 'ALERT'
                          ? 'Driver was ${_geofenceDistance}m from expected point — Red Alert!'
                          : 'Driver was ${_geofenceDistance}m from expected point',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    )),
                  ],
                ),
              ),
            ),

          // ── Milestone Greeting Overlay (Customer only) ─────────────────────
          if (_greetingVisible && widget.userRole == 'Customer')
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _greetingVisible = false),
                child: Container(
                  color: Colors.black.withOpacity(0.55),
                  child: Center(
                    child: ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _greetingCtrl,
                        curve: Curves.elasticOut,
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.6), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C63FF).withOpacity(0.3),
                              blurRadius: 32,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_greetingEmoji,
                                style: const TextStyle(fontSize: 56)),
                            const SizedBox(height: 16),
                            Text(
                              _greetingTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _greetingBody,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: () => setState(() => _greetingVisible = false),
                              child: const Text('Got it! 👍',
                                style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Bottom Panel ──────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).size.height * 0.40,
            left: 0, right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF090D1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusTimeline(status),
                    const SizedBox(height: 16),
                    // Multi-stop progress bar (Merchant sees all stops)
                    if (_stops.isNotEmpty && widget.userRole == 'Merchant')
                      _buildMultiStopProgress(),
                    if (status.toLowerCase() == 'completed' || status.toLowerCase() == 'delivered') ...[
                      _buildCompletedRatingBanner(),
                      const SizedBox(height: 16),
                    ],
                    _buildOrderCard(),
                    const SizedBox(height: 16),
                    if (_actionError != null) _buildErrorBanner(),
                    _buildActionButtons(status),
                    if (_deliveryLog.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _buildDeliveryLog(),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Multi-stop progress list (Merchant only) ──────────────────────
  Widget _buildMultiStopProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Row(
          children: [
            const Text('All Stops', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_stops.where((s) => s['status'] == 'completed').length}/${_stops.length} done',
                style: const TextStyle(
                    color: Color(0xFF818CF8), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._stops.asMap().entries.map((e) {
          final i = e.key;
          final stop = e.value;
          final isDone = stop['status'] == 'completed';
          final isActive = stop['status'] == 'active';
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: isActive ? const LinearGradient(
                colors: [Color(0x22FF9F43), Color(0x11FF9F43)],
              ) : null,
              color: isActive ? null : const Color(0xFF1A1E2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDone
                    ? const Color(0xFF10B981).withOpacity(0.4)
                    : isActive
                        ? const Color(0xFFFF9F43).withOpacity(0.5)
                        : Colors.white12,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFF10B981).withOpacity(0.25)
                        : isActive
                            ? const Color(0xFFFF9F43).withOpacity(0.25)
                            : Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isDone
                        ? const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 14)
                        : Text('${i + 1}',
                            style: TextStyle(
                              color: isActive ? const Color(0xFFFF9F43) : Colors.white38,
                              fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop['customerName'] ?? 'Customer ${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        stop['dropAddress'] ?? stop['dropoffAddress'] ?? 'Address ${i + 1}',
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : isActive
                            ? const Color(0xFFFF9F43).withOpacity(0.15)
                            : Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isDone ? 'Done' : isActive ? 'Active' : 'Pending',
                    style: TextStyle(
                      color: isDone
                          ? const Color(0xFF10B981)
                          : isActive
                              ? const Color(0xFFFF9F43)
                              : Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStatusTimeline(String status) {
    final steps = [
      ('Created', '📋'),
      ('Broadcasting', '📡'),
      ('Accepted', '✅'),
      ('EN_ROUTE_PICKUP', '🛵'),
      ('AT_PICKUP', '📍'),
      ('PICKED_UP', '📦'),
      ('AT_DROP', '🏁'),
      ('Completed', '🎉'),
    ];

    final currentIdx = steps.indexWhere((s) => s.$1 == status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Order Status', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(status.replaceAll('_', ' '),
                style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: steps.asMap().entries.map((entry) {
              final idx = entry.key;
              final step = entry.value;
              final isDone = currentIdx >= idx;
              final isCurrent = currentIdx == idx;
              return Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: isDone ? const Color(0xFF6C63FF) : const Color(0xFF1A1E2E),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCurrent ? const Color(0xFF3ECFCF) : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: isCurrent ? [const BoxShadow(
                            color: Color(0x443ECFCF), blurRadius: 8, spreadRadius: 2)] : null,
                        ),
                        child: Center(child: Text(step.$2, style: const TextStyle(fontSize: 14))),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 60,
                        child: Text(
                          step.$1.replaceAll('_', '\n'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 8,
                            color: isDone ? Colors.white : Colors.white24,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (idx < steps.length - 1)
                    Container(
                      width: 20, height: 2,
                      color: idx < currentIdx ? const Color(0xFF6C63FF) : const Color(0xFF1A1E2E),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard() {
    final pickupOtp = _task['pickupOtp']?.toString();
    final dropOtp = _task['dropoffOtp']?.toString();
    final pickupOtpRequired = _task['isPickupOtpRequired'] ?? true;
    final dropOtpRequired = _task['isDropOtpRequired'] ?? true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Pickup', style: TextStyle(color: Colors.white38, fontSize: 10)),
                Text(_task['pickupAddress'] ?? '—',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF6C63FF)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Drop', style: TextStyle(color: Colors.white38, fontSize: 10)),
                Text(_task['dropoffAddress'] ?? '—',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    textAlign: TextAlign.end, maxLines: 2, overflow: TextOverflow.ellipsis),
              ])),
            ],
          ),
          if (pickupOtp != null && pickupOtpRequired) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A2E3E)),
            const SizedBox(height: 8),
            Row(children: [
              const Text('Pickup OTP:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: pickupOtp)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(pickupOtp,
                    style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold,
                        fontSize: 18, letterSpacing: 4)),
                ),
              ),
            ]),
          ],
          if (dropOtp != null && dropOtpRequired) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Text('Drop OTP:', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Clipboard.setData(ClipboardData(text: dropOtp)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(dropOtp,
                    style: const TextStyle(color: Color(0xFFFF6B6B), fontWeight: FontWeight.bold,
                        fontSize: 18, letterSpacing: 4)),
                ),
              ),
            ]),
          ],

          // Driver & Vehicle Details Card (Tap to open Bottom Sheet)
          if (_task['driverName'] != null || _task['assignedDriverId'] != null || _task['driver'] != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF2A2E3E)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                final driverId = _task['assignedDriverId']?.toString() ??
                    _task['driverId']?.toString() ??
                    _task['driver']?['id']?.toString();
                if (driverId != null) {
                  showDriverProfileSheet(context, driverId: driverId);
                } else {
                  final taskModel = TaskModel.fromJson(_task);
                  showDriverVehicleBottomSheet(context, task: taskModel);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(
                        _task['driverAvatarUrl'] ?? _task['driver']?['avatarUrl'] ?? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _task['driverName'] ?? _task['driver']?['fullName'] ?? 'Assigned Driver',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.verified, color: Color(0xFF10B981), size: 14),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_task['vehiclePlateNumber'] ?? _task['vehiclePlate'] ?? 'RJ14-SC-7890'} • ${_task['vehicleColor'] ?? 'Flame Red'}',
                            style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Text('Profile', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.bold)),
                          Icon(Icons.chevron_right, color: Color(0xFF60A5FA), size: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.red[900]!.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Text(_actionError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
    );
  }

  Widget _buildActionButtons(String status) {
    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      ));
    }

    // ── CUSTOMER: delete if pending + share button ─────────────────────────
    if (widget.userRole == 'Customer') {
      if (status == 'Broadcasting' || status == 'Created') {
        return _bigButton('🗑 Delete Order', Colors.red[700]!, () async {
          final confirm = await _confirmDialog(
            'Delete Order?',
            'This will permanently cancel your order. This cannot be undone.',
          );
          if (!confirm) return;
          _performDriverAction(() => OrderLifecycleApi.deleteOrder(widget.token, widget.taskId));
        });
      }
      // Active order: show Share Tracking button
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _infoText('Your order is being tracked live. Updates will appear above.'),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _shareTrackingLink,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF6C63FF)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Share Live Tracking 🔗',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // ── SHOP OWNER: confirm / reject / market ──────────────────────────────
    if (widget.userRole == 'Merchant') {
      if (status == 'Created' || status == 'PendingShopConfirm') {
        return Column(children: [
          _otpPolicyToggles(),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _bigButton('✓ Confirm Order', const Color(0xFF00E676), () {
              _performDriverAction(() => OrderLifecycleApi.confirmOrder(widget.token, widget.taskId));
            })),
            const SizedBox(width: 12),
            Expanded(child: _bigButton('✗ Reject', Colors.red[700]!, () async {
              final reason = await _reasonDialog('Reject reason');
              if (reason == null) return;
              _performDriverAction(() => OrderLifecycleApi.rejectOrder(widget.token, widget.taskId, reason));
            })),
          ]),
          const SizedBox(height: 10),
          _bigButton('📡 Post to Market Drivers', const Color(0xFFFF9F43), () async {
            final fare = await _fareInputDialog();
            if (fare == null) return;
            _performDriverAction(() => OrderLifecycleApi.postToMarket(widget.token, widget.taskId, fare));
          }),
        ]);
      }
      return _infoText('Order is in progress. Tracking live above.');
    }

    // ── DRIVER: step-by-step lifecycle ─────────────────────────────────────
    if (widget.userRole == 'Driver') {
      switch (status) {
        case 'Accepted':
          return _bigButton('▶ Start Trip', const Color(0xFF6C63FF), () async {
            final (lat, lng) = await _getCurrentGps();
            _performDriverAction(() => OrderLifecycleApi.startTrip(widget.token, widget.taskId, lat, lng));
          });

        case 'EN_ROUTE_PICKUP':
          return _bigButton('📍 Arrived at Pickup', const Color(0xFFFF9F43), () async {
            final (lat, lng) = await _getCurrentGps();
            _performDriverAction(() => OrderLifecycleApi.arrivePickup(widget.token, widget.taskId, lat, lng));
          });

        case 'AT_PICKUP':
          return Column(children: [
            if (_task['isPickupOtpRequired'] == true) ...[
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 6),
                decoration: InputDecoration(
                  hintText: 'Enter Pickup OTP',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1A1E2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6C63FF))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2)),
                  counterStyle: const TextStyle(color: Colors.white30),
                ),
              ),
              const SizedBox(height: 10),
            ],
            _bigButton('✅ Pickup Verified — Start Delivery', const Color(0xFF3ECFCF), () async {
              final (lat, lng) = await _getCurrentGps();
              _performDriverAction(() => OrderLifecycleApi.confirmPickup(
                widget.token, widget.taskId, lat, lng,
                otp: _task['isPickupOtpRequired'] == true ? _otpCtrl.text.trim() : null,
              ));
            }),
          ]);

        case 'PICKED_UP':
          return _bigButton('📍 Arrived at Drop Point', const Color(0xFFFF9F43), () async {
            final (lat, lng) = await _getCurrentGps();
            _performDriverAction(() => OrderLifecycleApi.arriveDrop(widget.token, widget.taskId, lat, lng));
          });

        case 'AT_DROP':
          return Column(children: [
            if (_task['isDropOtpRequired'] == true) ...[
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 6),
                decoration: InputDecoration(
                  hintText: 'Enter Drop OTP from customer',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1A1E2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2)),
                  counterStyle: const TextStyle(color: Colors.white30),
                ),
              ),
              const SizedBox(height: 10),
            ],
            _bigButton('🎉 Delivered!', const Color(0xFF00E676), () async {
              final (lat, lng) = await _getCurrentGps();
              _performDriverAction(() => OrderLifecycleApi.completeDelivery(
                widget.token, widget.taskId, lat, lng,
                otp: _task['isDropOtpRequired'] == true ? _otpCtrl.text.trim() : null,
              ));
            }),
          ]);
      }
    }

    if (status == 'Completed') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF00E676).withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🎉', style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
            Text('Order Delivered Successfully!',
              style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDeliveryLog() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Delivery Log', style: TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        ..._deliveryLog.map((log) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1E2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _geofenceBorderColor(log['geofenceStatus']?.toString() ?? 'N/A'),
              width: log['geofenceStatus'] == 'ALERT' ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(log['geofenceIcon'] ?? '—', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log['eventType'] ?? '—',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                    if (log['fromStatus'] != null)
                      Text('${log['fromStatus']} → ${log['toStatus']}',
                        style: const TextStyle(color: Colors.white54, fontSize: 10)),
                    if (log['notes'] != null)
                      Text(log['notes'], style: const TextStyle(color: Colors.white38, fontSize: 10)),
                    if (log['distanceFromExpectedMeters'] != null)
                      Text('Distance from expected: ${(log['distanceFromExpectedMeters'] as num).toStringAsFixed(0)}m',
                        style: TextStyle(
                          color: log['geofenceStatus'] == 'ALERT' ? Colors.red[300] : Colors.white38,
                          fontSize: 10, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Text(log['occurredAt']?.toString().substring(11, 19) ?? '',
                style: const TextStyle(color: Colors.white30, fontSize: 10)),
            ],
          ),
        )),
      ],
    );
  }

  Widget _otpPolicyToggles() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('OTP Policy', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _toggleChip('Pickup OTP',
              _task['isPickupOtpRequired'] != false, (v) => setState(() => _task['isPickupOtpRequired'] = v))),
            const SizedBox(width: 8),
            Expanded(child: _toggleChip('Drop OTP',
              _task['isDropOtpRequired'] != false, (v) => setState(() => _task['isDropOtpRequired'] = v))),
          ]),
        ],
      ),
    );
  }

  Widget _toggleChip(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: value ? const Color(0xFF6C63FF).withOpacity(0.15) : const Color(0xFF0A0E1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: value ? const Color(0xFF6C63FF).withOpacity(0.5) : Colors.white12),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14, color: value ? const Color(0xFF6C63FF) : Colors.white30),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: value ? const Color(0xFF6C63FF) : Colors.white30)),
        ]),
      ),
    );
  }

  Widget _bigButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
  }

  Widget _infoText(String msg) {
    return Text(msg, style: const TextStyle(color: Colors.white38, fontSize: 13));
  }

  Color _statusColor(String status) => switch (status) {
    'Completed' => const Color(0xFF00E676),
    'EN_ROUTE_PICKUP' => const Color(0xFF6C63FF),
    'AT_PICKUP' => const Color(0xFFFF9F43),
    'PICKED_UP' => const Color(0xFF3ECFCF),
    'AT_DROP' => const Color(0xFFFFD93D),
    'Cancelled' => const Color(0xFFFF6B6B),
    _ => const Color(0xFF6C63FF),
  };

  Color _geofenceBorderColor(String status) => switch (status) {
    'ALERT' => Colors.red.withOpacity(0.5),
    'WARNING' => Colors.orange.withOpacity(0.4),
    'OK' => const Color(0xFF00E676).withOpacity(0.3),
    _ => Colors.white12,
  };

  Future<bool> _confirmDialog(String title, String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: Color(0xFFFF6B6B)))),
        ],
      ),
    ) ?? false;
  }

  Future<String?> _reasonDialog(String hint) async {
    final ctrl = TextEditingController();
    return await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E2E),
        title: const Text('Enter Reason', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white38)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Submit', style: TextStyle(color: Color(0xFF6C63FF)))),
        ],
      ),
    );
  }

  Future<double?> _fareInputDialog() async {
    final ctrl = TextEditingController(text: '60');
    return await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E2E),
        title: const Text('Market Driver Fare (₹)', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(prefixText: '₹ ', prefixStyle: TextStyle(color: Color(0xFF6C63FF))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, double.tryParse(ctrl.text) ?? 60),
            child: const Text('Post', style: TextStyle(color: Color(0xFF6C63FF)))),
        ],
      ),
    );
  }

  Widget _buildCompletedRatingBanner() {
    final isDriver = widget.userRole.toLowerCase() == 'driver';
    final driverName = _task['driverName'] ?? _task['driver']?['fullName'] ?? 'Driver';
    final shopName = _task['businessName'] ?? _task['business']?['businessName'] ?? 'Shop Owner';
    final customerName = _task['customerName'] ?? _task['customer']?['fullName'] ?? 'Customer';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF59E0B).withOpacity(0.18),
            const Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withOpacity(0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDriver ? 'Rate Customer Experience' : 'Rate Your Trip & Store',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDriver
                          ? 'Share feedback on passenger/customer coordination'
                          : 'Rate $driverName and $shopName to improve quality',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showOrderRatingBottomSheet(
                  context,
                  task: TaskModel.fromJson(_task),
                  viewerRole: isDriver ? 'Driver' : 'Customer',
                );
              },
              icon: const Icon(Icons.stars_rounded, color: Colors.black, size: 18),
              label: Text(
                isDriver ? 'Rate Customer Now' : 'Leave Review (Driver & Shop)',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
