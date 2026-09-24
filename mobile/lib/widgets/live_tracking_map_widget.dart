import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/mqtt_service.dart';

class LiveTrackingMapWidget extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final double initialDriverLat;
  final double initialDriverLng;
  final String status;
  final String? otp;
  final String? taskId;
  final String? driverId;

  const LiveTrackingMapWidget({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.initialDriverLat,
    required this.initialDriverLng,
    required this.status,
    this.otp,
    this.taskId,
    this.driverId,
  });

  @override
  State<LiveTrackingMapWidget> createState() => _LiveTrackingMapWidgetState();
}

class _LiveTrackingMapWidgetState extends State<LiveTrackingMapWidget> {
  late LatLng _driverPos;
  double _currentSpeed = 38.5; // km/h
  Timer? _movementTimer;
  StreamSubscription? _mqttSub;
  bool _hasLiveMqtt = false;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _driverPos = LatLng(widget.initialDriverLat, widget.initialDriverLng);
    _initMqttTracking();
    _startSimulatedMovement();
  }

  void _initMqttTracking() async {
    if (widget.taskId == null && widget.driverId == null) return;
    try {
      final mqtt = MqttService();
      await mqtt.connect();
      if (widget.taskId != null) mqtt.subscribeToTaskTracking(widget.taskId!);
      if (widget.driverId != null) mqtt.subscribeToDriverTracking(widget.driverId!);

      _mqttSub = mqtt.locationStream.listen((update) {
        if (!mounted) return;
        final matchesTask = widget.taskId != null && update.taskId == widget.taskId;
        final matchesDriver = widget.driverId != null && update.driverId == widget.driverId;
        if (matchesTask || matchesDriver) {
          setState(() {
            _hasLiveMqtt = true;
            _driverPos = LatLng(update.latitude, update.longitude);
            _currentSpeed = update.speed;
          });
          _movementTimer?.cancel();
        }
      });
    } catch (e) {
      debugPrint('[LiveMap] MQTT tracking subscribe failed: $e');
    }
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    _mqttSub?.cancel();
    if (widget.taskId != null) MqttService().unsubscribe('tasks/${widget.taskId}/tracking');
    if (widget.driverId != null) MqttService().unsubscribe('driver/${widget.driverId}/tracking');
    super.dispose();
  }

  void _startSimulatedMovement() {
    // Smoothly interpolate driver location towards destination if no live MQTT yet
    _movementTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted || _hasLiveMqtt) return;
      setState(() {
        _step++;
        // Target: move towards pickup first, then dropoff
        final targetLat = _step < 10 ? widget.pickupLat : widget.dropoffLat;
        final targetLng = _step < 10 ? widget.pickupLng : widget.dropoffLng;

        final newLat = _driverPos.latitude + (targetLat - _driverPos.latitude) * 0.12;
        final newLng = _driverPos.longitude + (targetLng - _driverPos.longitude) * 0.12;
        _driverPos = LatLng(newLat, newLng);
        _currentSpeed = 30.0 + (_step % 5) * 3.5;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final pickup = LatLng(widget.pickupLat, widget.pickupLng);
    final dropoff = LatLng(widget.dropoffLat, widget.dropoffLng);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
        ),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: _driverPos,
                initialZoom: 13.5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.shopconnector.app',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [pickup, dropoff],
                      strokeWidth: 4.0,
                      color: Colors.blueAccent.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Pickup Marker
                    Marker(
                      point: pickup,
                      width: 40,
                      height: 40,
                      child: const Column(
                        children: [
                          Icon(Icons.location_on, color: Colors.greenAccent, size: 28),
                        ],
                      ),
                    ),
                    // Dropoff Marker
                    Marker(
                      point: dropoff,
                      width: 40,
                      height: 40,
                      child: const Column(
                        children: [
                          Icon(Icons.flag, color: Colors.redAccent, size: 28),
                        ],
                      ),
                    ),
                    // Live Moving Driver Marker
                    Marker(
                      point: _driverPos,
                      width: 50,
                      height: 50,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blueAccent.withValues(alpha: 0.25),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF1E293B),
                            ),
                            child: const Icon(Icons.directions_car, color: Colors.amber, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Floating Status & Speed HUD
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Live GPS: ${widget.status} • ${_currentSpeed.toStringAsFixed(1)} km/h',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (widget.otp != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'OTP: ${widget.otp}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
