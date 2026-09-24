import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttLocationUpdate {
  final String driverId;
  final String? taskId;
  final double latitude;
  final double longitude;
  final double speed;
  final double heading;
  final double accuracy;
  final DateTime timestamp;

  MqttLocationUpdate({
    required this.driverId,
    this.taskId,
    required this.latitude,
    required this.longitude,
    required this.speed,
    required this.heading,
    required this.accuracy,
    required this.timestamp,
  });

  factory MqttLocationUpdate.fromJson(Map<String, dynamic> json) {
    return MqttLocationUpdate(
      driverId: json['driverId']?.toString() ?? '',
      taskId: json['taskId']?.toString(),
      latitude: (json['latitude'] ?? json['lat'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? json['lng'] ?? 0.0).toDouble(),
      speed: (json['speed'] ?? 0.0).toDouble(),
      heading: (json['heading'] ?? 0.0).toDouble(),
      accuracy: (json['accuracy'] ?? 5.0).toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  bool _isConnected = false;
  final Set<String> _subscribedTopics = {};

  final StreamController<MqttLocationUpdate> _locationController =
      StreamController<MqttLocationUpdate>.broadcast();

  Stream<MqttLocationUpdate> get locationStream => _locationController.stream;
  bool get isConnected => _isConnected && _client?.connectionStatus?.state == MqttConnectionState.connected;

  static String get defaultBrokerHost {
    if (kIsWeb) return 'localhost';
    try {
      if (Platform.isAndroid) return '10.0.2.2'; // Standard Android emulator loopback to host
    } catch (_) {}
    return '127.0.0.1';
  }

  Future<bool> connect({String? host, int port = 1883, String? clientId}) async {
    if (_client != null && _isConnected) return true;

    final targetHost = host ?? defaultBrokerHost;
    final cId = clientId ?? 'LocalConnect_Mobile_${Random().nextInt(999999)}';

    debugPrint('[MQTT] Connecting to $targetHost:$port as $cId...');

    _client = MqttServerClient.withPort(targetHost, cId, port);
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;
    _client!.resubscribeOnAutoReconnect = true;

    _client!.onConnected = () {
      _isConnected = true;
      debugPrint('[MQTT] Connected to Mosquitto Broker ($targetHost:$port)');
      // Re-subscribe to any previously active topics
      for (final topic in _subscribedTopics) {
        _client?.subscribe(topic, MqttQos.atLeastOnce);
      }
    };

    _client!.onDisconnected = () {
      _isConnected = false;
      debugPrint('[MQTT] Disconnected from Mosquitto Broker.');
    };

    try {
      final status = await _client!.connect();
      if (status?.state == MqttConnectionState.connected) {
        _isConnected = true;
        _listenToUpdates();
        return true;
      } else {
        debugPrint('[MQTT] Connection failed with status: ${status?.state}');
        _isConnected = false;
        return false;
      }
    } catch (e) {
      debugPrint('[MQTT] Connection exception: $e');
      _isConnected = false;
      return false;
    }
  }

  void _listenToUpdates() {
    _client?.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        final recMess = msg.payload as MqttPublishMessage;
        final payloadString = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        try {
          final data = jsonDecode(payloadString);
          if (data is Map<String, dynamic>) {
            final update = MqttLocationUpdate.fromJson(data);
            _locationController.add(update);
            debugPrint('[MQTT] Received live telemetry for driver ${update.driverId}: lat=${update.latitude}, lng=${update.longitude}');
          }
        } catch (e) {
          debugPrint('[MQTT] Failed to parse message on ${msg.topic}: $e');
        }
      }
    });
  }

  void subscribe(String topic) {
    _subscribedTopics.add(topic);
    if (_isConnected && _client != null) {
      _client!.subscribe(topic, MqttQos.atLeastOnce);
      debugPrint('[MQTT] Subscribed to $topic');
    }
  }

  void unsubscribe(String topic) {
    _subscribedTopics.remove(topic);
    if (_isConnected && _client != null) {
      _client!.unsubscribe(topic);
      debugPrint('[MQTT] Unsubscribed from $topic');
    }
  }

  void subscribeToTaskTracking(String taskId) {
    subscribe('tasks/$taskId/tracking');
  }

  void subscribeToDriverTracking(String driverId) {
    subscribe('driver/$driverId/tracking');
  }

  bool publishDriverLocation({
    required String driverId,
    String? taskId,
    required String deviceId,
    required double latitude,
    required double longitude,
    double speed = 0.0,
    double heading = 0.0,
    double accuracy = 4.0,
    int batteryPct = 100,
    bool isCharging = false,
  }) {
    if (_client == null || !_isConnected) {
      debugPrint('[MQTT] Publish skipped: Client not connected.');
      return false;
    }

    final payload = {
      'driverId': driverId,
      if (taskId != null) 'taskId': taskId,
      'deviceId': deviceId,
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'heading': heading,
      'accuracy': accuracy,
      'batteryPct': batteryPct,
      'isCharging': isCharging,
      'timestamp': DateTime.UtcNow.toIso8601String(),
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));

    final topic = 'driver/$driverId/location';
    try {
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      debugPrint('[MQTT] Broadcasted live GPS ping for driver $driverId ($latitude, $longitude)');
      return true;
    } catch (e) {
      debugPrint('[MQTT] Publish error: $e');
      return false;
    }
  }

  void disconnect() {
    _subscribedTopics.clear();
    _client?.disconnect();
    _client = null;
    _isConnected = false;
    debugPrint('[MQTT] Client disconnected and reset.');
  }
}

extension DateTimeUtc on DateTime {
  static DateTime get UtcNow => DateTime.now().toUtc();
}
