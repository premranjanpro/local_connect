import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'api_service.dart';

// ══════════════════════════════════════════════════════════════════════════
//  OfflineEventStore — SQLite-backed local event & GPS buffer
//
//  When driver has no internet:
//    1. GPS pings → stored in local_gps_pings table
//    2. Status changes, OTP verifications → stored in local_events table
//    3. Pending notifications → stored in pending_notifications table
//
//  When internet returns:
//    → OfflineSyncService flushes everything in order
//    → Server reconstructs state machine chronologically
//    → Customer gets notifications with ACTUAL event times
// ══════════════════════════════════════════════════════════════════════════

class OfflineEventStore {
  static Database? _db;

  static Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'shopconnector_offline.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE local_events (
        id TEXT PRIMARY KEY,
        task_id TEXT,
        stop_id TEXT,
        type TEXT NOT NULL,
        new_status TEXT,
        driver_lat REAL,
        driver_lng REAL,
        otp TEXT,
        device_id TEXT,
        occurred_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE local_gps_pings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        bearing REAL,
        speed REAL,
        accuracy REAL,
        occurred_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_notifications (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        event_occurred_at TEXT NOT NULL,
        task_id TEXT,
        channel TEXT DEFAULT 'FCM',
        data_json TEXT,
        shown INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE task_km_log (
        task_id TEXT PRIMARY KEY,
        total_km REAL DEFAULT 0,
        total_minutes INTEGER DEFAULT 0,
        last_lat REAL,
        last_lng REAL,
        started_at TEXT,
        last_updated TEXT
      )
    ''');
  }

  // ── Events ──────────────────────────────────────────────────────────────

  static Future<void> saveEvent({
    required String type,
    required String occurredAt,
    String? taskId,
    String? stopId,
    String? newStatus,
    double? driverLat,
    double? driverLng,
    String? otp,
    String? deviceId,
  }) async {
    final db = await database;
    await db.insert('local_events', {
      'id': _uuid(),
      'task_id': taskId,
      'stop_id': stopId,
      'type': type,
      'new_status': newStatus,
      'driver_lat': driverLat,
      'driver_lng': driverLng,
      'otp': otp,
      'device_id': deviceId,
      'occurred_at': occurredAt,
      'synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    debugPrint('[OfflineStore] Saved event $type at $occurredAt');
  }

  static Future<List<Map<String, dynamic>>> getUnsynced() async {
    final db = await database;
    return db.query('local_events', where: 'synced = 0', orderBy: 'occurred_at ASC');
  }

  static Future<void> markEventSynced(String id) async {
    final db = await database;
    await db.update('local_events', {'synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // ── GPS Pings ────────────────────────────────────────────────────────────

  static Future<void> saveGpsPing({
    required String taskId,
    required double lat,
    required double lng,
    double? bearing,
    double? speed,
    double? accuracy,
  }) async {
    final db = await database;
    await db.insert('local_gps_pings', {
      'task_id': taskId,
      'lat': lat,
      'lng': lng,
      'bearing': bearing,
      'speed': speed,
      'accuracy': accuracy,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'synced': 0,
    });
    // Update rolling km
    await _updateTaskKm(taskId, lat, lng);
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedGpsPings(String taskId) async {
    final db = await database;
    return db.query('local_gps_pings',
        where: 'task_id = ? AND synced = 0', whereArgs: [taskId], orderBy: 'occurred_at ASC');
  }

  static Future<void> markGpsPingsSynced(String taskId) async {
    final db = await database;
    await db.update('local_gps_pings', {'synced': 1},
        where: 'task_id = ? AND synced = 0', whereArgs: [taskId]);
  }

  // ── Task KM/Duration tracking ─────────────────────────────────────────────

  static Future<void> startTaskKmLog(String taskId, double lat, double lng) async {
    final db = await database;
    await db.insert('task_km_log', {
      'task_id': taskId,
      'total_km': 0,
      'total_minutes': 0,
      'last_lat': lat,
      'last_lng': lng,
      'started_at': DateTime.now().toUtc().toIso8601String(),
      'last_updated': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<Map<String, dynamic>?> getTaskKmLog(String taskId) async {
    final db = await database;
    final rows = await db.query('task_km_log', where: 'task_id = ?', whereArgs: [taskId]);
    return rows.isNotEmpty ? rows.first : null;
  }

  static Future<void> _updateTaskKm(String taskId, double lat, double lng) async {
    final db = await database;
    final existing = await getTaskKmLog(taskId);
    if (existing == null) return;

    final lastLat = existing['last_lat'] as double?;
    final lastLng = existing['last_lng'] as double?;
    if (lastLat == null || lastLng == null) return;

    final distKm = _haversineKm(lastLat, lastLng, lat, lng);
    final totalKm = (existing['total_km'] as num).toDouble() + distKm;

    final startedAt = DateTime.tryParse(existing['started_at'] as String? ?? '') ?? DateTime.now();
    final totalMinutes = DateTime.now().difference(startedAt).inMinutes;

    await db.update('task_km_log', {
      'total_km': totalKm,
      'total_minutes': totalMinutes,
      'last_lat': lat,
      'last_lng': lng,
      'last_updated': DateTime.now().toUtc().toIso8601String(),
    }, where: 'task_id = ?', whereArgs: [taskId]);
  }

  // ── Pending notifications (show when driver reconnects) ──────────────────

  static Future<void> savePendingNotification({
    required String title,
    required String body,
    required String eventOccurredAt,
    String? taskId,
    String channel = 'FCM',
    Map<String, String>? data,
  }) async {
    final db = await database;
    await db.insert('pending_notifications', {
      'id': _uuid(),
      'title': title,
      'body': body,
      'event_occurred_at': eventOccurredAt,
      'task_id': taskId,
      'channel': channel,
      'data_json': data != null ? jsonEncode(data) : null,
      'shown': 0,
    });
  }

  static Future<List<Map<String, dynamic>>> getUnshownNotifications() async {
    final db = await database;
    return db.query('pending_notifications', where: 'shown = 0', orderBy: 'event_occurred_at ASC');
  }

  static Future<void> markNotificationShown(String id) async {
    final db = await database;
    await db.update('pending_notifications', {'shown': 1}, where: 'id = ?', whereArgs: [id]);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2)
        + math.cos(_toRad(lat1)) * math.cos(_toRad(lat2))
        * math.sin(dLng / 2) * math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * (math.pi / 180);

  static int _uuidCounter = 0;
  static String _uuid() =>
      '${DateTime.now().millisecondsSinceEpoch}-${++_uuidCounter}';
}

// ══════════════════════════════════════════════════════════════════════════
//  OfflineSyncService — monitors connectivity, syncs on reconnect
// ══════════════════════════════════════════════════════════════════════════

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._();

  bool _isOnline = true;
  bool _isSyncing = false;
  String? _currentTaskId;
  String? _token;
  DateTime? _offlineSince;

  final _connectivity = Connectivity();
  StreamSubscription? _connectivitySub;
  final _onlineController = StreamController<bool>.broadcast();

  Stream<bool> get onlineStream => _onlineController.stream;
  bool get isOnline => _isOnline;

  void init(String token, {String? taskId}) {
    _token = token;
    _currentTaskId = taskId;
    _connectivitySub?.cancel();
    _connectivitySub = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    _connectivity.checkConnectivity().then((results) {
      _isOnline = !results.contains(ConnectivityResult.none);
      if (!_isOnline) _offlineSince = DateTime.now();
    });
  }

  void setActiveTask(String taskId) {
    _currentTaskId = taskId;
  }

  void dispose() {
    _connectivitySub?.cancel();
    _onlineController.close();
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final nowOnline = !results.contains(ConnectivityResult.none);

    if (!_isOnline && nowOnline) {
      debugPrint('[OfflineSync] 🌐 Internet restored — syncing buffered data');
      _isOnline = true;
      _onlineController.add(true);
      _flushBufferedData();
    } else if (_isOnline && !nowOnline) {
      debugPrint('[OfflineSync] 📴 Internet lost — buffering mode activated');
      _isOnline = false;
      _offlineSince = DateTime.now();
      _onlineController.add(false);
    }
  }

  /// Save an event locally if offline, or send to server immediately if online
  Future<void> recordEvent({
    required String type,
    String? taskId,
    String? stopId,
    String? newStatus,
    double? driverLat,
    double? driverLng,
    String? otp,
    String? deviceId,
  }) async {
    final occurredAt = DateTime.now().toUtc().toIso8601String();
    final tid = taskId ?? _currentTaskId;

    // Always save locally first (source of truth)
    await OfflineEventStore.saveEvent(
      type: type,
      occurredAt: occurredAt,
      taskId: tid,
      stopId: stopId,
      newStatus: newStatus,
      driverLat: driverLat,
      driverLng: driverLng,
      otp: otp,
      deviceId: deviceId,
    );

    if (_isOnline) {
      // Try to flush immediately
      await _flushBufferedData();
    }
  }

  /// Record GPS ping (always local-first)
  Future<void> recordGpsPing({
    required String taskId,
    required double lat,
    required double lng,
    double? bearing,
    double? speed,
  }) async {
    await OfflineEventStore.saveGpsPing(
      taskId: taskId, lat: lat, lng: lng,
      bearing: bearing, speed: speed,
    );
  }

  Future<void> _flushBufferedData() async {
    if (_isSyncing || _token == null) return;
    _isSyncing = true;

    try {
      final events = await OfflineEventStore.getUnsynced();
      if (events.isEmpty) return;

      final taskId = _currentTaskId ?? events.firstOrNull?['task_id']?.toString();
      if (taskId == null) return;

      // Build GPS pings list
      final gpsPings = await OfflineEventStore.getUnsyncedGpsPings(taskId);

      // Build event list for server
      final allEvents = [
        ...events.map((e) => {
          'type': e['type'],
          'occurredAt': e['occurred_at'],
          'driverLat': e['driver_lat'] ?? 0.0,
          'driverLng': e['driver_lng'] ?? 0.0,
          'taskId': e['task_id'],
          'stopId': e['stop_id'],
          'newStatus': e['new_status'],
          'otp': e['otp'],
          'deviceId': e['device_id'],
        }),
        ...gpsPings.map((g) => {
          'type': 'GPS_PING',
          'occurredAt': g['occurred_at'],
          'driverLat': g['lat'],
          'driverLng': g['lng'],
          'taskId': g['task_id'],
        }),
      ];

      allEvents.sort((a, b) =>
          (a['occurredAt'] as String).compareTo(b['occurredAt'] as String));

      // Send to server
      final res = await http.post(
        Uri.parse('${ApiService.baseUrl}/tasks/offline-sync'),
        headers: ApiService.getHeaders(_token!),
        body: jsonEncode({
          'taskId': taskId,
          'offlineSince': _offlineSince?.toUtc().toIso8601String(),
          'events': allEvents,
        }),
      ).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final result = jsonDecode(res.body);
        debugPrint('[OfflineSync] ✅ Synced ${result['eventsProcessed']} events, '
            '${result['gpsPointsSynced']} GPS pings, ${result['offlineKm']}km offline');

        // Mark all as synced
        for (final e in events) {
          await OfflineEventStore.markEventSynced(e['id'].toString());
        }
        await OfflineEventStore.markGpsPingsSynced(taskId);
        _offlineSince = null;
      }
    } catch (e) {
      debugPrint('[OfflineSync] ❌ Sync failed: $e — will retry on next reconnect');
    } finally {
      _isSyncing = false;
    }
  }

  /// Manually trigger sync (e.g., pull-to-refresh)
  Future<Map<String, dynamic>?> forceSyncNow() async {
    if (_token == null) return null;
    await _flushBufferedData();
    final kmLog = _currentTaskId != null
        ? await OfflineEventStore.getTaskKmLog(_currentTaskId!)
        : null;
    return kmLog;
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  DriverGpsTracker — live GPS stream with offline buffering
// ══════════════════════════════════════════════════════════════════════════

class DriverGpsTracker {
  static final DriverGpsTracker _instance = DriverGpsTracker._();
  factory DriverGpsTracker() => _instance;
  DriverGpsTracker._();

  StreamSubscription<Position>? _gpsSub;
  String? _activeTaskId;
  Position? _lastPosition;

  final _positionController = StreamController<Position>.broadcast();
  Stream<Position> get positionStream => _positionController.stream;

  final _syncService = OfflineSyncService();

  Future<bool> requestPermissions() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  Future<void> startTracking(String taskId) async {
    _activeTaskId = taskId;
    await OfflineEventStore.startTaskKmLog(taskId, 0, 0);

    _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10 meters
      ),
    ).listen(_onPosition, onError: (e) {
      debugPrint('[GpsTracker] Error: $e');
    });

    debugPrint('[GpsTracker] Started tracking for task $taskId');
  }

  void _onPosition(Position pos) {
    _lastPosition = pos;
    _positionController.add(pos);

    if (_activeTaskId != null) {
      _syncService.recordGpsPing(
        taskId: _activeTaskId!,
        lat: pos.latitude,
        lng: pos.longitude,
        bearing: pos.heading,
        speed: pos.speed,
      );
    }
  }

  void stopTracking() {
    _gpsSub?.cancel();
    _gpsSub = null;
    _activeTaskId = null;
    debugPrint('[GpsTracker] Stopped tracking');
  }

  Position? get lastPosition => _lastPosition;

  Future<void> dispose() async {
    stopTracking();
    await _positionController.close();
  }
}
