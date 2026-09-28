import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/offline_sync_service.dart';
import '../services/order_lifecycle_api.dart';

// ══════════════════════════════════════════════════════════════════════════
//  MultiStopOrderScreen
//
//  Used for:
//   • School runs (10 student pickups → 1 school drop)
//   • Bulk deliveries (1 shop pickup → 10 customer drops)
//   • Custom multi-stop tasks
//
//  Features:
//   • 40% map with all stop markers color-coded (PENDING/APPROACHING/ARRIVED/COMPLETED)
//   • Per-stop action panel: Arrive → Complete (with OTP if required)
//   • Live km + duration counter from offline GPS tracking
//   • Offline-first — all actions buffered locally, synced on reconnect
//   • Progress: "5/10 stops completed"
// ══════════════════════════════════════════════════════════════════════════

class MultiStopOrderScreen extends StatefulWidget {
  final String taskId;
  final String token;
  final String userRole;

  const MultiStopOrderScreen({
    super.key,
    required this.taskId,
    required this.token,
    required this.userRole,
  });

  @override
  State<MultiStopOrderScreen> createState() => _MultiStopOrderScreenState();
}

class _MultiStopOrderScreenState extends State<MultiStopOrderScreen>
    with TickerProviderStateMixin {

  Map<String, dynamic>? _task;
  List<dynamic> _stops = [];
  bool _loading = true;
  String? _error;

  // Offline + GPS
  final _syncService = OfflineSyncService();
  final _gpsTracker = DriverGpsTracker();
  StreamSubscription? _onlineSub;
  bool _isOnline = true;
  double _totalKm = 0;
  int _totalMinutes = 0;
  int _selectedStopIdx = 0;

  final TextEditingController _otpCtrl = TextEditingController();
  bool _actionLoading = false;

  // Animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _syncService.init(widget.token, taskId: widget.taskId);
    _onlineSub = _syncService.onlineStream.listen((online) {
      setState(() => _isOnline = online);
      if (online) _refreshKm();
    });

    _loadTask();

    if (widget.userRole == 'Driver') {
      _gpsTracker.requestPermissions().then((_) {
        _gpsTracker.startTracking(widget.taskId);
        _gpsTracker.positionStream.listen((pos) {
          _refreshKm();
        });
      });
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _otpCtrl.dispose();
    _onlineSub?.cancel();
    if (widget.userRole == 'Driver') _gpsTracker.stopTracking();
    super.dispose();
  }

  Future<void> _loadTask() async {
    try {
      final data = await _fetchTask();
      setState(() {
        _task = data;
        _stops = data['stops'] as List<dynamic>? ?? [];
        _loading = false;
        // Auto-select first non-completed stop
        _selectedStopIdx = _stops.indexWhere(
            (s) => s['status'] != 'COMPLETED');
        if (_selectedStopIdx < 0) _selectedStopIdx = 0;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<Map<String, dynamic>> _fetchTask() async {
    // Use multi-stop endpoint
    final res = await OrderLifecycleApi.getDeliveryLog(widget.token, widget.taskId);
    return res;
  }

  Future<void> _refreshKm() async {
    final log = await OfflineEventStore.getTaskKmLog(widget.taskId);
    if (log != null && mounted) {
      setState(() {
        _totalKm = (log['total_km'] as num).toDouble();
        _totalMinutes = (log['total_minutes'] as int?) ?? 0;
      });
    }
  }

  Future<void> _arriveAtStop(Map<String, dynamic> stop) async {
    setState(() { _actionLoading = true; _error = null; });
    try {
      final pos = _gpsTracker.lastPosition;
      final lat = pos?.latitude ?? 26.9124;
      final lng = pos?.longitude ?? 75.7873;

      // Record locally first (offline-safe)
      await _syncService.recordEvent(
        type: 'STOP_ARRIVE',
        taskId: widget.taskId,
        stopId: stop['id'].toString(),
        newStatus: 'ARRIVED',
        driverLat: lat,
        driverLng: lng,
      );

      if (_isOnline) {
        // Also call server directly
        final res = await http_post(widget.taskId, stop['id'].toString(), lat, lng, null);
        ScaffoldMessenger.of(context).showSnackBar(_snackbar(
          res['message'] ?? 'Arrived at stop #${stop['stopSequence']}',
          _geofenceColor(res['geoStatus']?.toString()),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(_snackbar(
          '📴 Offline — event saved. Will sync when internet returns.',
          Colors.orange,
        ));
      }

      await _loadTask();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  Future<void> _completeStop(Map<String, dynamic> stop) async {
    final isOtpRequired = stop['isOtpRequired'] == true;
    final otp = _otpCtrl.text.trim();

    if (isOtpRequired && otp.isEmpty) {
      setState(() => _error = 'Please enter the OTP for stop #${stop['stopSequence']}');
      return;
    }

    setState(() { _actionLoading = true; _error = null; });

    try {
      final pos = _gpsTracker.lastPosition;
      final lat = pos?.latitude ?? 26.9124;
      final lng = pos?.longitude ?? 75.7873;

      // Record locally first
      await _syncService.recordEvent(
        type: 'STOP_COMPLETE',
        taskId: widget.taskId,
        stopId: stop['id'].toString(),
        newStatus: 'COMPLETED',
        driverLat: lat,
        driverLng: lng,
        otp: isOtpRequired ? otp : null,
      );

      if (_isOnline) {
        final res = await http_complete(widget.taskId, stop['id'].toString(), lat, lng, otp.isEmpty ? null : otp);
        ScaffoldMessenger.of(context).showSnackBar(_snackbar(
          res['message'] ?? 'Stop completed!',
          const Color(0xFF00E676),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(_snackbar(
          '📴 Offline — completion saved. Syncing when back online.',
          Colors.orange,
        ));
      }

      _otpCtrl.clear();
      await _loadTask();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _actionLoading = false);
    }
  }

  // Stubs calling API (replace with actual http calls)
  Future<Map<String, dynamic>> http_post(String taskId, String stopId, double lat, double lng, String? otp) async {
    return OrderLifecycleApi.arrivePickup(widget.token, taskId, lat, lng);
  }

  Future<Map<String, dynamic>> http_complete(String taskId, String stopId, double lat, double lng, String? otp) async {
    return OrderLifecycleApi.confirmPickup(widget.token, taskId, lat, lng, otp: otp);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF090D1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    final completed = _stops.where((s) => s['status'] == 'COMPLETED').length;
    final total = _stops.length;
    final progress = total > 0 ? completed / total : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      body: Column(
        children: [
          // ── 40% Map ─────────────────────────────────────────────────────
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.40,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _stops.isNotEmpty
                        ? LatLng((_stops[0]['latitude'] as num).toDouble(),
                                 (_stops[0]['longitude'] as num).toDouble())
                        : const LatLng(26.9124, 75.7873),
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.shopconnector.app',
                    ),
                    MarkerLayer(markers: _buildStopMarkers()),
                  ],
                ),

                // Offline badge
                if (!_isOnline)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 0, right: 0,
                    child: Center(child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange[900],
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 8)],
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text('Offline Mode — events buffered', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    )),
                  ),

                // Back button
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

          // ── Bottom Panel ─────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress bar
                  _buildProgressBar(completed, total, progress),
                  const SizedBox(height: 14),

                  // KM + Duration stats
                  _buildKmStats(),
                  const SizedBox(height: 14),

                  // Stop list
                  const Text('All Stops', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 10),
                  ..._stops.asMap().entries.map((e) => _buildStopTile(e.key, e.value)),

                  // Action panel for selected stop
                  if (_selectedStopIdx >= 0 && _selectedStopIdx < _stops.length &&
                      widget.userRole == 'Driver') ...[
                    const SizedBox(height: 16),
                    _buildActionPanel(_stops[_selectedStopIdx]),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[900]!.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Marker> _buildStopMarkers() {
    return _stops.asMap().entries.map((e) {
      final stop = e.value;
      final color = _stopColor(stop['status']?.toString() ?? 'PENDING');
      final lat = (stop['latitude'] as num?)?.toDouble() ?? 0;
      final lng = (stop['longitude'] as num?)?.toDouble() ?? 0;

      return Marker(
        point: LatLng(lat, lng),
        width: 36, height: 48,
        child: Column(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)],
              ),
              child: Center(child: Text(
                '${stop['stopSequence']}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              )),
            ),
            Container(width: 2, height: 12, color: color),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildProgressBar(int done, int total, double progress) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('$done/$total Stops Completed',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            const Spacer(),
            Text('${(progress * 100).toInt()}%',
              style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF2A2E3E),
              color: progress == 1.0 ? const Color(0xFF00E676) : const Color(0xFF6C63FF),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKmStats() {
    return Row(children: [
      Expanded(child: _statCard('📍 Distance', '${_totalKm.toStringAsFixed(1)} km', const Color(0xFF6C63FF))),
      const SizedBox(width: 10),
      Expanded(child: _statCard('⏱ Duration', '${_totalMinutes} min', const Color(0xFF3ECFCF))),
      const SizedBox(width: 10),
      Expanded(child: _statCard(
        _isOnline ? '🌐 Online' : '📴 Offline',
        _isOnline ? 'Synced' : 'Buffering',
        _isOnline ? const Color(0xFF00E676) : Colors.orange,
      )),
    ]);
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }

  Widget _buildStopTile(int idx, Map<String, dynamic> stop) {
    final status = stop['status']?.toString() ?? 'PENDING';
    final color = _stopColor(status);
    final isSelected = idx == _selectedStopIdx;

    return GestureDetector(
      onTap: () => setState(() { _selectedStopIdx = idx; _otpCtrl.clear(); }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : const Color(0xFF1A1E2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.5) : Colors.white12,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Center(child: Text(
                '${stop['stopSequence']}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: stop['stopType'] == 'PICKUP'
                          ? const Color(0xFF6C63FF).withOpacity(0.2)
                          : const Color(0xFFFF6B6B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stop['stopType']?.toString() ?? '',
                      style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.bold,
                        color: stop['stopType'] == 'PICKUP'
                            ? const Color(0xFF6C63FF)
                            : const Color(0xFFFF6B6B),
                      ),
                    ),
                  ),
                  if (stop['recipientLabel'] != null) ...[
                    const SizedBox(width: 6),
                    Text(stop['recipientLabel'], style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(stop['address'] ?? '—',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _statusBadge(status, color),
              if (stop['geofenceIcon'] != null && stop['geofenceIcon'] != '—')
                Text(stop['geofenceIcon'], style: const TextStyle(fontSize: 12)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPanel(Map<String, dynamic> stop) {
    final status = stop['status']?.toString() ?? 'PENDING';
    final isOtpRequired = stop['isOtpRequired'] == true;
    final color = _stopColor(status);

    if (status == 'COMPLETED') {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF00E676).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
        ),
        child: Row(children: [
          const Text('✅', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text('Stop #${stop['stopSequence']} completed at '
            '${_fmtTime(stop['completedAt']?.toString())}',
            style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w600)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Stop #${stop['stopSequence']} — ${stop['stopType']}',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(stop['address'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 12),

          if (status == 'PENDING' || status == 'DRIVER_APPROACHING')
            _actionButton('📍 Mark Arrived at Stop', color, () => _arriveAtStop(stop)),

          if (status == 'ARRIVED') ...[
            if (isOtpRequired) ...[
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 6),
                decoration: InputDecoration(
                  hintText: 'Enter OTP',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true, fillColor: const Color(0xFF1A1E2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: color)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: color, width: 2)),
                  counterStyle: const TextStyle(color: Colors.white30),
                ),
              ),
              const SizedBox(height: 8),
            ],
            _actionButton(
              stop['stopType'] == 'PICKUP' ? '✅ Pickup Done' : '✅ Delivered',
              const Color(0xFF00E676),
              () => _completeStop(stop),
            ),
          ],

          if (_actionLoading)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF), strokeWidth: 2)),
            ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label, textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  Widget _statusBadge(String status, Color color) {
    final labels = {
      'PENDING': 'Pending',
      'DRIVER_APPROACHING': 'Approaching',
      'ARRIVED': 'Arrived',
      'COMPLETED': 'Done',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(labels[status] ?? status,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Color _stopColor(String status) => switch (status) {
    'COMPLETED' => const Color(0xFF00E676),
    'ARRIVED' => const Color(0xFFFF9F43),
    'DRIVER_APPROACHING' => const Color(0xFF3ECFCF),
    _ => const Color(0xFF6C63FF),
  };

  Color _geofenceColor(String? status) => switch (status) {
    'ALERT' => Colors.red,
    'WARNING' => Colors.orange,
    _ => const Color(0xFF00E676),
  };

  String _fmtTime(String? isoStr) {
    if (isoStr == null) return '—';
    try {
      final dt = DateTime.parse(isoStr).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return '—'; }
  }

  SnackBar _snackbar(String msg, Color color) => SnackBar(
    content: Text(msg),
    backgroundColor: color,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
