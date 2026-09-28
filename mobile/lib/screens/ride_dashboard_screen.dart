import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/offline_sync_service.dart';

// ══════════════════════════════════════════════════════════════════════════
//  RideDashboardScreen — Driver's multi-task ride cockpit
//
//  DESIGN PHILOSOPHY: Minimal required taps for driver
//  ─────────────────────────────────────────────────────
//  REQUIRED (2 taps total per ride):
//    [▶ Start Ride]  →  [⏹ End Ride]
//
//  OPTIONAL (driver's convenience):
//    [📞 Call]            — direct phone call to any recipient
//    [🔔 Get Ready Alert] — manual "I'm coming to you next" push
//    [✅ Mark Picked Up]  — optional per-task pickup mark
//    [✅ Mark Dropped]    — optional per-task delivery mark
//    [📍 Update GPS]      — manually trigger geofence check
//
//  AUTOMATIC (no driver action):
//    • Geofence entry → recipient gets "Driver arriving in X min"
//    • Ride end → all tasks auto-completed + all recipients notified
//    • KM + duration tracked from GPS
// ══════════════════════════════════════════════════════════════════════════

class RideDashboardScreen extends StatefulWidget {
  final String rideId;
  final String token;

  const RideDashboardScreen({
    super.key,
    required this.rideId,
    required this.token,
  });

  @override
  State<RideDashboardScreen> createState() => _RideDashboardScreenState();
}

class _RideDashboardScreenState extends State<RideDashboardScreen>
    with TickerProviderStateMixin {

  Map<String, dynamic>? _ride;
  List<dynamic> _tasks = [];
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  bool _isOnline = true;

  // GPS
  final _gpsTracker = DriverGpsTracker();
  final _syncService = OfflineSyncService();
  StreamSubscription? _gpsSub;
  double? _driverLat, _driverLng;
  double _totalKm = 0;
  DateTime? _startedAt;

  // Map
  final MapController _mapCtrl = MapController();

  // Timer for km counter
  Timer? _kmTimer;

  // Animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _syncService.init(widget.token, taskId: widget.rideId);
    _syncService.onlineStream.listen((online) => setState(() => _isOnline = online));
    _loadRide();
    _startGps();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _gpsSub?.cancel();
    _kmTimer?.cancel();
    _gpsTracker.stopTracking();
    super.dispose();
  }

  Future<void> _startGps() async {
    final ok = await _gpsTracker.requestPermissions();
    if (!ok) return;
    await _gpsTracker.startTracking(widget.rideId);
    _gpsSub = _gpsTracker.positionStream.listen((pos) async {
      setState(() { _driverLat = pos.latitude; _driverLng = pos.longitude; });
      await _sendLocationPing(pos.latitude, pos.longitude, pos.heading, pos.speed);
    });
  }

  Future<void> _sendLocationPing(double lat, double lng, double? bearing, double? speed) async {
    if (!_isOnline) return;
    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/rides/${widget.rideId}/location-ping'),
        headers: ApiService.getHeaders(widget.token),
        body: jsonEncode({'lat': lat, 'lng': lng, 'bearing': bearing, 'speed': speed}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> _loadRide() async {
    try {
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/rides/${widget.rideId}'),
        headers: ApiService.getHeaders(widget.token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _ride = data;
          _tasks = data['tasks'] as List<dynamic>? ?? [];
          _loading = false;
          if (data['startedAt'] != null) {
            _startedAt = DateTime.tryParse(data['startedAt']);
          }
        });
        _startKmTimer();
      } else {
        setState(() { _loading = false; _error = 'Failed to load ride'; });
      }
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _startKmTimer() {
    _kmTimer?.cancel();
    _kmTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final log = await OfflineEventStore.getTaskKmLog(widget.rideId);
      if (log != null && mounted) {
        setState(() => _totalKm = (log['total_km'] as num).toDouble());
      }
    });
  }

  Future<void> _apiAction(Future<http.Response> Function() call,
      {String? successMsg}) async {
    setState(() { _actionLoading = true; _error = null; });
    try {
      final res = await call();
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(body['message'] ?? successMsg ?? 'Done!'),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        await _loadRide();
      } else {
        setState(() => _error = body['message'] ?? 'Error ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _startRide() => _apiAction(() => http.post(
    Uri.parse('${ApiService.baseUrl}/rides/${widget.rideId}/start'),
    headers: ApiService.getHeaders(widget.token),
    body: jsonEncode({
      'driverLat': _driverLat ?? 0.0,
      'driverLng': _driverLng ?? 0.0,
    }),
  ));

  Future<void> _endRide() async {
    final confirmed = await _confirmDialog(
      'End Ride?',
      'This will complete all deliveries in this ride. Any unmarked tasks will be auto-completed.',
    );
    if (!confirmed) return;

    _apiAction(() => http.post(
      Uri.parse('${ApiService.baseUrl}/rides/${widget.rideId}/end'),
      headers: ApiService.getHeaders(widget.token),
      body: jsonEncode({
        'driverLat': _driverLat ?? 0.0,
        'driverLng': _driverLng ?? 0.0,
        'totalKm': _totalKm,
      }),
    ));
  }

  Future<void> _sendManualAlert(Map<String, dynamic> rideTask, {String? stopId}) async {
    final taskId = rideTask['taskId'];
    final remaining = rideTask['manualAlertsRemaining'] as int? ?? 0;

    if (remaining <= 0) {
      _showError('No manual alerts remaining for this recipient.');
      return;
    }

    final message = await _messageDialog(
      hint: 'I\'m on my way, get ready!',
      defaultText: '🚗 Driver is coming to you next! Be ready.',
    );
    if (message == null) return;

    _apiAction(() => http.post(
      Uri.parse('${ApiService.baseUrl}/rides/${widget.rideId}/tasks/$taskId/manual-alert'),
      headers: ApiService.getHeaders(widget.token),
      body: jsonEncode({'message': message, 'stopId': stopId}),
    ), successMsg: 'Alert sent!');
  }

  Future<void> _callCustomer(String? phone) async {
    if (phone == null || phone.isEmpty) {
      _showError('No phone number available.');
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showError('Cannot open phone app.');
    }
  }

  Future<void> _markPickedUp(String taskId) => _apiAction(() => http.post(
    Uri.parse('${ApiService.baseUrl}/rides/${widget.rideId}/tasks/$taskId/picked-up'),
    headers: ApiService.getHeaders(widget.token),
    body: jsonEncode({'driverLat': _driverLat ?? 0.0, 'driverLng': _driverLng ?? 0.0}),
  ));

  Future<void> _markDropped(String taskId) => _apiAction(() => http.post(
    Uri.parse('${ApiService.baseUrl}/rides/${widget.rideId}/tasks/$taskId/dropped'),
    headers: ApiService.getHeaders(widget.token),
    body: jsonEncode({'driverLat': _driverLat ?? 0.0, 'driverLng': _driverLng ?? 0.0}),
  ));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(
      backgroundColor: Color(0xFF090D1A),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
    );

    final rideStatus = _ride?['status']?.toString() ?? 'PENDING';
    final progress = (_ride?['progressPercent'] as num?)?.toInt() ?? 0;
    final isActive = rideStatus == 'ACTIVE';
    final isDone = rideStatus == 'COMPLETED';

    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      body: Column(
        children: [
          // ── 40% Map ────────────────────────────────────────────────────
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.40,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _firstStopLatLng ?? const LatLng(26.9124, 75.7873),
                    initialZoom: 12,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.shopconnector.app',
                    ),
                    MarkerLayer(markers: [
                      ..._buildAllStopMarkers(),
                      if (_driverLat != null && _driverLng != null)
                        _buildDriverMarker(),
                    ]),
                  ],
                ),

                // Status + offline pill
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 0, right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!_isOnline) _pill('📴 Offline', Colors.orange),
                      const SizedBox(width: 6),
                      _pill(
                        isActive ? '🚗 Ride Active' : isDone ? '✅ Completed' : '⏳ Not Started',
                        isActive ? const Color(0xFF6C63FF) : isDone ? const Color(0xFF00E676) : Colors.white38,
                      ),
                    ],
                  ),
                ),

                // Back
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 12,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1E2E).withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Dashboard Panel ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ride stats row
                  _buildRideStats(progress, isActive, isDone),
                  const SizedBox(height: 14),

                  // Main action buttons
                  _buildMainActions(isActive, isDone),
                  const SizedBox(height: 16),

                  if (_error != null) _errorBanner(),
                  if (_actionLoading)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2),
                    )),

                  // Task list — heart of the dashboard
                  Text(
                    '${_tasks.length} ${_tasks.length == 1 ? 'Task' : 'Tasks'} in this Ride',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 10),
                  ..._tasks.asMap().entries.map((e) => _buildTaskCard(e.key, e.value, isActive)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideStats(int progress, bool isActive, bool isDone) {
    final duration = isActive && _startedAt != null
        ? DateTime.now().difference(_startedAt!)
        : Duration(minutes: (_ride?['totalMinutes'] as num?)?.toInt() ?? 0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: Text(
              _ride?['rideName'] ?? 'Ride #${widget.rideId.substring(0, 8)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            )),
            Text('$progress%', style: const TextStyle(
              color: Color(0xFF6C63FF), fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress / 100,
              backgroundColor: const Color(0xFF2A2E3E),
              color: progress == 100 ? const Color(0xFF00E676) : const Color(0xFF6C63FF),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _miniStat('📍 KM', '${_totalKm.toStringAsFixed(1)} km', const Color(0xFF6C63FF)),
            _miniStat('⏱ Time', '${duration.inMinutes} min', const Color(0xFF3ECFCF)),
            _miniStat('📦 Done', _ride?['progress'] ?? '0/${_tasks.length}', const Color(0xFF00E676)),
          ]),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(child: Column(children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      const SizedBox(height: 2),
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    ]));
  }

  Widget _buildMainActions(bool isActive, bool isDone) {
    if (isDone) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF00E676).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
        ),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('🎉', style: TextStyle(fontSize: 22)),
          SizedBox(width: 10),
          Text('Ride Completed!', style: TextStyle(
            color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
      );
    }

    return Row(children: [
      if (!isActive)
        Expanded(child: _bigButton(
          icon: '▶',
          label: 'Start Ride',
          color: const Color(0xFF6C63FF),
          onTap: _startRide,
        ))
      else
        Expanded(child: _bigButton(
          icon: '⏹',
          label: 'End Ride',
          color: const Color(0xFFFF6B6B),
          onTap: _endRide,
        )),
    ]);
  }

  // ── Individual Task Card ────────────────────────────────────────────────

  Widget _buildTaskCard(int idx, Map<String, dynamic> rt, bool isActive) {
    final task = rt['task'] as Map<String, dynamic>?;
    final rtStatus = rt['status']?.toString() ?? 'PENDING';
    final statusColor = _taskStatusColor(rtStatus);
    final customerPhone = task?['customerPhone']?.toString();
    final alertsRemaining = (rt['manualAlertsRemaining'] as num?)?.toInt() ?? 0;
    final taskId = rt['taskId']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: rtStatus == 'DROPPED' || rtStatus == 'SKIPPED'
              ? const Color(0xFF00E676).withOpacity(0.3)
              : statusColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Sequence badge
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text(
                    '${rt['plannedSequence']}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  )),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    task?['customerName'] ?? task?['businessName'] ?? 'Customer',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    task?['pickupAddress'] ?? '—',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ])),
                _statusChip(rtStatus, statusColor),
              ],
            ),
          ),

          // ── Route row ─────────────────────────────────────────────────
          if (task != null) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              const Icon(Icons.fiber_manual_record, size: 8, color: Color(0xFF6C63FF)),
              const SizedBox(width: 5),
              Expanded(child: Text(task['pickupAddress'] ?? '—',
                style: const TextStyle(color: Colors.white60, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ),
          if (task != null) Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 10),
            child: Row(children: [
              const Icon(Icons.location_pin, size: 10, color: Color(0xFFFF6B6B)),
              const SizedBox(width: 3),
              Expanded(child: Text(task['dropoffAddress'] ?? '—',
                style: const TextStyle(color: Colors.white60, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('₹${task['fareAmount'] ?? 0}',
                  style: const TextStyle(color: Color(0xFF6C63FF), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
            ]),
          ),

          // ── Stop pills ────────────────────────────────────────────────
          if (task?['stops'] != null && (task!['stops'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10),
              child: Wrap(
                spacing: 5,
                runSpacing: 4,
                children: (task['stops'] as List).map((s) {
                  final sStatus = s['status']?.toString() ?? 'PENDING';
                  final sColor = _stopStatusColor(sStatus);
                  return GestureDetector(
                    onTap: () => _showStopActions(context, s, rt, isActive),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: sColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: sColor.withOpacity(0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(s['geofenceIcon'] ?? '—', style: const TextStyle(fontSize: 10)),
                        const SizedBox(width: 3),
                        Text(
                          '${s['stopType'] == 'PICKUP' ? '↑' : '↓'}${s['stopSequence']} '
                          '${s['recipientLabel'] ?? _shortAddr(s['address']?.toString())}',
                          style: TextStyle(color: sColor, fontSize: 9, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),

          // ── Action buttons row ─────────────────────────────────────────
          if (isActive && rtStatus != 'DROPPED' && rtStatus != 'SKIPPED')
            Container(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: Row(children: [
                // Call button
                _iconButton(
                  icon: Icons.call_rounded,
                  label: 'Call',
                  color: const Color(0xFF00E676),
                  onTap: () => _callCustomer(customerPhone),
                ),
                const SizedBox(width: 8),
                // Manual Alert button
                _iconButton(
                  icon: Icons.notifications_active_rounded,
                  label: 'Alert ($alertsRemaining)',
                  color: alertsRemaining > 0 ? const Color(0xFFFF9F43) : Colors.white24,
                  onTap: alertsRemaining > 0 ? () => _sendManualAlert(rt) : null,
                ),
                const SizedBox(width: 8),
                // Pickup mark
                if (rtStatus == 'PENDING')
                  Expanded(child: _smallButton(
                    '↑ Picked Up', const Color(0xFF6C63FF),
                    () => _markPickedUp(taskId),
                  )),
                // Drop mark
                if (rtStatus == 'PICKED_UP')
                  Expanded(child: _smallButton(
                    '↓ Delivered', const Color(0xFF00E676),
                    () => _markDropped(taskId),
                  )),
              ]),
            ),
        ],
      ),
    );
  }

  // ── Stop action bottom sheet ──────────────────────────────────────────

  void _showStopActions(BuildContext ctx, Map<String, dynamic> stop,
      Map<String, dynamic> rt, bool isActive) {
    final stopId = stop['id']?.toString();
    final recipientPhone = stop['recipientPhone']?.toString();
    final label = stop['recipientLabel']?.toString() ?? _shortAddr(stop['address']?.toString());

    showModalBottomSheet(
      context: ctx,
      backgroundColor: const Color(0xFF1A1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(stop['stopType'] == 'PICKUP' ? '↑' : '↓',
                style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(stop['address'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _stopStatusColor(stop['status']?.toString() ?? 'PENDING').withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(stop['status']?.toString() ?? '—',
                  style: TextStyle(
                    color: _stopStatusColor(stop['status']?.toString() ?? 'PENDING'),
                    fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 8),

            // Call stop recipient
            if (recipientPhone != null)
              _sheetButton(Icons.call_rounded, 'Call ${label}',
                const Color(0xFF00E676), () {
                  Navigator.pop(ctx);
                  _callCustomer(recipientPhone);
                }),
            const SizedBox(height: 8),

            // Manual alert to this specific stop
            if (isActive)
              _sheetButton(Icons.notifications_active_rounded,
                'Send "Get Ready" to $label',
                const Color(0xFFFF9F43), () {
                  Navigator.pop(ctx);
                  _sendManualAlert(rt, stopId: stopId);
                }),
            const SizedBox(height: 8),

            // Copy OTP
            if (stop['isOtpRequired'] == true)
              _sheetButton(Icons.copy_rounded, 'Copy OTP',
                const Color(0xFF6C63FF), () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: '(OTP shown to driver only)'));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP copied')));
                }),
            const SizedBox(height: 8),

            _sheetButton(Icons.close_rounded, 'Close', Colors.white38,
              () => Navigator.pop(ctx)),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  // ── Map helpers ──────────────────────────────────────────────────────────

  List<Marker> _buildAllStopMarkers() {
    final markers = <Marker>[];
    var globalSeq = 1;
    for (final rt in _tasks) {
      final task = rt['task'] as Map<String, dynamic>?;
      final stops = task?['stops'] as List<dynamic>? ?? [];
      for (final stop in stops) {
        final lat = (stop['latitude'] as num?)?.toDouble();
        final lng = (stop['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        final sStatus = stop['status']?.toString() ?? 'PENDING';
        final color = _stopStatusColor(sStatus);
        final seq = globalSeq++;
        markers.add(Marker(
          point: LatLng(lat, lng),
          width: 32, height: 42,
          child: Column(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
              ),
              child: Center(child: Text('$seq',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
            ),
            Container(width: 2, height: 10, color: color),
          ]),
        ));
      }
    }
    return markers;
  }

  Marker _buildDriverMarker() {
    return Marker(
      point: LatLng(_driverLat!, _driverLng!),
      width: 44, height: 44,
      child: ScaleTransition(
        scale: _pulseAnim,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.5),
              blurRadius: 14, spreadRadius: 3,
            )],
          ),
          child: const Icon(Icons.delivery_dining_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  LatLng? get _firstStopLatLng {
    for (final rt in _tasks) {
      final stops = (rt['task']?['stops'] as List<dynamic>?) ?? [];
      for (final s in stops) {
        final lat = (s['latitude'] as num?)?.toDouble();
        final lng = (s['longitude'] as num?)?.toDouble();
        if (lat != null && lng != null) return LatLng(lat, lng);
      }
    }
    return null;
  }

  // ── Widget helpers ───────────────────────────────────────────────────────

  Widget _bigButton({required String icon, required String label,
      required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 12, spreadRadius: 1)],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
      ),
    );
  }

  Widget _iconButton({required IconData icon, required String label,
      required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _smallButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _sheetButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8)],
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _statusChip(String status, Color color) {
    final labels = {'PENDING': 'Pending', 'PICKED_UP': 'Picked Up', 'DROPPED': '✅ Done', 'SKIPPED': 'Skipped'};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(labels[status] ?? status,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _errorBanner() => Container(
    padding: const EdgeInsets.all(10),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: Colors.red[900]!.withOpacity(0.25),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
  );

  // ── Utils ─────────────────────────────────────────────────────────────────

  Color _taskStatusColor(String s) => switch (s) {
    'DROPPED' => const Color(0xFF00E676),
    'PICKED_UP' => const Color(0xFF3ECFCF),
    'SKIPPED' => Colors.white38,
    _ => const Color(0xFF6C63FF),
  };

  Color _stopStatusColor(String s) => switch (s) {
    'COMPLETED' => const Color(0xFF00E676),
    'ARRIVED' => const Color(0xFFFF9F43),
    'DRIVER_APPROACHING' => const Color(0xFF3ECFCF),
    _ => const Color(0xFF6C63FF),
  };

  String _shortAddr(String? addr) {
    if (addr == null) return '—';
    final parts = addr.split(',');
    return parts.first.trim().length > 18 ? '${parts.first.trim().substring(0, 18)}…' : parts.first.trim();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red[800],
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<bool> _confirmDialog(String title, String body) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E2E),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(body, style: const TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(color: Color(0xFFFF6B6B)))),
        ],
      ),
    ) ?? false;
  }

  Future<String?> _messageDialog({required String hint, String? defaultText}) async {
    final ctrl = TextEditingController(text: defaultText);
    return await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E2E),
        title: const Text('Custom Alert Message', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white30),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text),
            child: const Text('Send 🔔', style: TextStyle(color: Color(0xFFFF9F43)))),
        ],
      ),
    );
  }
}
