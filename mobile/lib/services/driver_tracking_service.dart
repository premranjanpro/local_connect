import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'offline_sync_service.dart';

/// ═══════════════════════════════════════════════════════════════════════
///  DriverTrackingService — Dual-mode GPS heartbeat manager
///
///  IDLE mode  (driver online, no active ride):
///    → GPS ping every 60 seconds
///    → Sent as mode: "IDLE"
///
///  RIDE mode  (active ride in progress):
///    → GPS ping every 15 seconds
///    → Sent as mode: "RIDE"
///
///  GPS unavailable (permission denied, signal lost, etc.):
///    → Heartbeat still sent with last known position + isGpsAvailable: false
///    → Server knows driver is alive
///    → No gap in heartbeat chain
/// ═══════════════════════════════════════════════════════════════════════

enum TrackingMode { idle, ride }

class DriverTrackingService {
  static final DriverTrackingService _instance = DriverTrackingService._();
  factory DriverTrackingService() => _instance;
  DriverTrackingService._();

  TrackingMode _mode = TrackingMode.idle;
  String? _token;
  String? _activeRideId;
  bool _running = false;

  Position? _lastKnownPosition;
  Timer? _heartbeatTimer;
  StreamSubscription<Position>? _gpsSub;

  // Position broadcast for UI
  final _posStream = StreamController<Position?>.broadcast();
  Stream<Position?> get positionStream => _posStream.stream;
  Position? get lastPosition => _lastKnownPosition;
  TrackingMode get mode => _mode;

  // ── Start / Stop ────────────────────────────────────────────────────────

  Future<void> start(String token, {String? rideId}) async {
    _token = token;
    _activeRideId = rideId;
    _running = true;

    // Request permissions
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    // Start continuous GPS listener (used for real-time position)
    _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(
      (pos) {
        _lastKnownPosition = pos;
        _posStream.add(pos);
        // Buffer in offline store
        if (_activeRideId != null) {
          OfflineEventStore.saveGpsPing(
            taskId: _activeRideId!,
            lat: pos.latitude, lng: pos.longitude,
            bearing: pos.heading, speed: pos.speed,
          );
        }
      },
      onError: (_) {}, // GPS error — heartbeat still fires via timer
    );

    _scheduleHeartbeat();
    debugPrint('[Tracking] Started in ${_mode.name} mode');
  }

  void setRideMode(String rideId) {
    _activeRideId = rideId;
    _mode = TrackingMode.ride;
    _reschedule();
    debugPrint('[Tracking] → RIDE mode (15s pings), rideId: $rideId');
  }

  void setIdleMode() {
    _mode = TrackingMode.idle;
    _activeRideId = null;
    _reschedule();
    debugPrint('[Tracking] → IDLE mode (60s pings)');
  }

  void stop() {
    _running = false;
    _heartbeatTimer?.cancel();
    _gpsSub?.cancel();
    _posStream.close();
    debugPrint('[Tracking] Stopped');
  }

  // ── Internal ─────────────────────────────────────────────────────────────

  Duration get _interval => _mode == TrackingMode.ride
      ? const Duration(seconds: 15)
      : const Duration(seconds: 60);

  void _scheduleHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_interval, (_) => _sendHeartbeat());
    // Fire once immediately
    _sendHeartbeat();
  }

  void _reschedule() {
    if (_running) _scheduleHeartbeat();
  }

  Future<void> _sendHeartbeat() async {
    if (_token == null) return;

    final pos = _lastKnownPosition;
    final gpsAvailable = pos != null;

    final body = {
      'mode': _mode == TrackingMode.ride ? 'RIDE' : 'IDLE',
      'isGpsAvailable': gpsAvailable,
      'lat': pos?.latitude,
      'lng': pos?.longitude,
      'bearing': pos?.heading,
      'speed': pos?.speed,
      'accuracy': pos?.accuracy,
      'rideId': _activeRideId,
    };

    try {
      await http.post(
        Uri.parse('${ApiService.baseUrl}/driver/heartbeat'),
        headers: ApiService.getHeaders(_token!),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 8));

      debugPrint('[Heartbeat] ✅ ${_mode.name} | GPS: $gpsAvailable | '
          '${pos != null ? "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}" : "last-known"}');
    } catch (e) {
      debugPrint('[Heartbeat] ❌ Failed: $e — will retry in ${_interval.inSeconds}s');
    }
  }
}
