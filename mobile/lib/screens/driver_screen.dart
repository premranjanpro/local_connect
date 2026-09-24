import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'calling_screen.dart';

class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  String _dutyStatus = 'OffDuty';
  double _acceptanceRadiusKm = 1.0;
  double _deliveryRadiusKm = 10.0;
  List<dynamic> _vehicles = [];
  String? _activeVehicleId;
  bool _isLoading = false;

  // Intercity Banner controllers
  final _fromCityController = TextEditingController(text: 'Jaipur');
  final _toCityController = TextEditingController(text: 'Delhi');
  final _priceController = TextEditingController(text: '1500');
  final _seatsController = TextEditingController(text: '3');

  @override
  void initState() {
    super.initState();
    _loadDriverData();

    NotificationService.onTaskUpdated = (taskData) {
      if (mounted) {
        _loadDriverData();
        _showSnack('🔔 New dispatch broadcast received!', Colors.amber);
      }
    };
  }

  @override
  void dispose() {
    _fromCityController.dispose();
    _toCityController.dispose();
    _priceController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    setState(() => _isLoading = true);
    try {
      final vehicles = await ApiService.getVehicles(auth.token!);
      final active = vehicles.firstWhere((v) => v['isActive'] == true, orElse: () => null);

      setState(() {
        _vehicles = vehicles;
        _activeVehicleId = active != null ? active['id'] : null;
        if (_activeVehicleId != null && _dutyStatus == 'OffDuty') {
          _dutyStatus = 'Free';
        }
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDutyStatus(String newStatus) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await ApiService.updateDutyStatus(auth.token!, newStatus, auth.deviceId);
      setState(() => _dutyStatus = res['dutyStatus'] ?? newStatus);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Duty status set to $_dutyStatus'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _updateRadius() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await ApiService.updateRadius(auth.token!, _acceptanceRadiusKm, _deliveryRadiusKm);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operating radii saved!'), backgroundColor: Colors.blueAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _selectActiveVehicle(String vehicleId) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await ApiService.selectActiveVehicle(auth.token!, vehicleId);
      await _loadDriverData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vehicle activated! Only 1 vehicle online at a time.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _createBanner() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final price = double.tryParse(_priceController.text) ?? 1500;
      final seats = int.tryParse(_seatsController.text) ?? 3;
      final departureTime = DateTime.now().add(const Duration(hours: 12));

      await ApiService.createIntercityBanner(
        auth.token!,
        _fromCityController.text.trim(),
        _toCityController.text.trim(),
        departureTime,
        seats,
        price,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Route banner posted: ${_fromCityController.text} ➔ ${_toCityController.text} @ ₹$price'),
            backgroundColor: Colors.amber.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.two_wheeler, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              'Driver Console (${auth.fullName ?? "Driver"})',
              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _dutyStatus == 'Free' ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _dutyStatus == 'Free' ? Colors.green : Colors.redAccent),
            ),
            child: Text(
              _dutyStatus.toUpperCase(),
              style: TextStyle(
                color: _dutyStatus == 'Free' ? Colors.greenAccent : Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Duty Status Toggle Row
                  Card(
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Duty & Availability Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['Free', 'GoingToPickup', 'InTransit', 'OffDuty'].map((status) {
                              final isSelected = _dutyStatus == status;
                              return ChoiceChip(
                                label: Text(status),
                                selected: isSelected,
                                selectedColor: Colors.amber,
                                backgroundColor: const Color(0xFF334155),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (_) => _toggleDutyStatus(status),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Multi-Vehicle Picker Card
                  Card(
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('My Vehicles (1 Active Allowed)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('${_vehicles.length} Registered', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_vehicles.isEmpty)
                            const Text('No vehicles added. Use API to add a vehicle.', style: TextStyle(color: Colors.grey, fontSize: 13))
                          else
                            ..._vehicles.map((v) {
                              final isActive = v['id'] == _activeVehicleId;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isActive ? Colors.amber.withValues(alpha: 0.15) : const Color(0xFF334155),
                                  border: Border.all(color: isActive ? Colors.amber : Colors.transparent),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      v['vehicleType'] == 'Bike' ? Icons.two_wheeler : Icons.directions_car,
                                      color: isActive ? Colors.amber : Colors.white70,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${v['make']} ${v['model']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          Text(v['plateNumber'], style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    if (isActive)
                                      const Chip(
                                        label: Text('ONLINE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                                        backgroundColor: Colors.amber,
                                      )
                                    else
                                      TextButton(
                                        onPressed: () => _selectActiveVehicle(v['id']),
                                        child: const Text('Go Online', style: TextStyle(color: Colors.blueAccent)),
                                      ),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Operating Radius Configurator
                  Card(
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Operating Radius Setup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 6),
                          Text('Customize pickup acceptance and delivery distance thresholds.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Acceptance Radius:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              Text('${_acceptanceRadiusKm.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Slider(
                            value: _acceptanceRadiusKm,
                            min: 0.5,
                            max: 10.0,
                            divisions: 19,
                            activeColor: Colors.amber,
                            onChanged: (val) => setState(() => _acceptanceRadiusKm = val),
                            onChangeEnd: (_) => _updateRadius(),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Max Delivery Radius:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              Text('${_deliveryRadiusKm.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Slider(
                            value: _deliveryRadiusKm,
                            min: 1.0,
                            max: 50.0,
                            divisions: 49,
                            activeColor: Colors.blueAccent,
                            onChanged: (val) => setState(() => _deliveryRadiusKm = val),
                            onChangeEnd: (_) => _updateRadius(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 4. Direct VoIP Connect Card
                  Card(
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.phone_in_talk, color: Colors.greenAccent),
                              SizedBox(width: 8),
                              Text('Direct VoIP Quick Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Encrypted VoIP calling with customer or neighborhood vendor.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const CallingScreen(
                                          partnerUserId: 'c1111111-1111-1111-1111-111111111111',
                                          partnerName: 'Rahul Verma (Customer)',
                                          partnerRole: 'Customer',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.person, size: 16),
                                  label: const Text('Call Customer'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent.shade700, foregroundColor: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const CallingScreen(
                                          partnerUserId: '7a74b169-0512-4a3b-9f7d-6020832ceaf0',
                                          partnerName: 'Gupta Super Store',
                                          partnerRole: 'Shop Owner',
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.storefront, size: 16),
                                  label: const Text('Call Shop'),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, foregroundColor: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 5. Intercity Route Banner Creator
                  Card(
                    color: const Color(0xFF1E293B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.campaign, color: Colors.orangeAccent),
                              SizedBox(width: 8),
                              Text('Broadcast Intercity Route Banner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Broadcast your route to customers across the network.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _fromCityController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(labelText: 'From City', labelStyle: TextStyle(color: Colors.grey)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _toCityController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(labelText: 'To City', labelStyle: TextStyle(color: Colors.grey)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(labelText: 'Price (₹)', labelStyle: TextStyle(color: Colors.grey)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _seatsController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(labelText: 'Seats', labelStyle: TextStyle(color: Colors.grey)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: _createBanner,
                            icon: const Icon(Icons.send_rounded, size: 16),
                            label: const Text('Broadcast Banner to Customers'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          )
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
