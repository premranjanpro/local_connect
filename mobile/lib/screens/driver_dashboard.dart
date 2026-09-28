import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_store.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/mqtt_service.dart';
import '../models/task_status_models.dart';
import '../widgets/task_detail_cards.dart';
import '../widgets/order_rating_bottom_sheet.dart';
import 'calling_screen.dart';
import 'notification_center_screen.dart';
import 'task_booking_details_screen.dart';
import '../widgets/app_menu_drawer.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Duty & GPS
  String _dutyStatus = 'OffDuty';
  bool _mqttActive = false;
  Timer? _gpsTimer;
  double _lat = 26.9124;
  double _lng = 75.7873;

  // Vehicles
  List<dynamic> _vehicles = [];
  String? _activeVehicleId;
  bool _isLoading = false;

  // Radius
  double _acceptKm = 1.0;
  double _deliveryKm = 10.0;

  // Tasks
  List<TaskModel> _tasks = [];
  List<TaskModel> _pendingDispatch = [];
  bool _loadingTasks = false;
  TaskStatus? _filterStatus;
  DashboardStats _stats = const DashboardStats();

  // OTP verify
  TaskModel? _activeTask;
  final _otpCtrl = TextEditingController();

  // Intercity Banner
  final _fromCityCtrl = TextEditingController(text: 'Jaipur');
  final _toCityCtrl = TextEditingController(text: 'Delhi');
  final _priceCtrl = TextEditingController(text: '1500');
  final _seatsCtrl = TextEditingController(text: '3');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAll();
    NotificationService.onTaskUpdated = (d) {
      if (mounted) {
        _loadAll();
        _showSnack('🔔 New dispatch received!', const Color(0xFFF59E0B));
      }
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gpsTimer?.cancel();
    _fromCityCtrl.dispose();
    _toCityCtrl.dispose();
    _priceCtrl.dispose();
    _seatsCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _loadAll() {
    _loadVehicles();
    _loadTasks();
  }

  Future<void> _loadVehicles() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    setState(() => _isLoading = true);
    try {
      final v = await ApiService.getVehicles(auth.token!);
      final active = v.firstWhere((x) => x['isActive'] == true, orElse: () => null);
      setState(() {
        _vehicles = v;
        _activeVehicleId = active != null ? active['id'] : null;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _loadingTasks = true);
    // Mocked task list for demonstration
    final mocks = _buildMockTasks();
    setState(() {
      _tasks = mocks;
      _pendingDispatch = mocks.where((t) => t.status == TaskStatus.pending).toList();
      _stats = DashboardStats.fromTasks(mocks);
      _loadingTasks = false;
      // Set active task if one is ongoing/assigned
      _activeTask = mocks.firstWhere(
          (t) => t.status == TaskStatus.assign || t.status == TaskStatus.ongoing,
          orElse: () => mocks.first);
    });
  }

  List<TaskModel> _buildMockTasks() {
    return [
      TaskModel.fromJson({
        'id': 'drv-001-dispatch',
        'taskType': 'GroceryDelivery',
        'status': 'pending',
        'pickupAddress': 'Gupta Kirana Store, Vaishali Nagar',
        'dropoffAddress': 'Flat 402, Royal Palms',
        'estimatedFare': 80,
        'distanceKm': 2.4,
        'paymentMode': 'Cash',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
      }),
      TaskModel.fromJson({
        'id': 'drv-002-assigned',
        'taskType': 'MobilityRide',
        'status': 'assigned',
        'pickupAddress': 'Sindhi Camp Bus Stand',
        'dropoffAddress': 'Malviya Nagar Metro',
        'estimatedFare': 120,
        'distanceKm': 4.2,
        'customerName': 'Rahul Verma',
        'pickupOtp': '7341',
        'paymentMode': 'Cash',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
      }),
      TaskModel.fromJson({
        'id': 'drv-003-ongoing',
        'taskType': 'GroceryDelivery',
        'status': 'ongoing',
        'pickupAddress': 'Fresh Mart, Tonk Road',
        'dropoffAddress': 'Sector 8, Vidhyadhar Nagar',
        'estimatedFare': 65,
        'distanceKm': 3.1,
        'customerName': 'Priya Sharma',
        'dropoffOtp': '5892',
        'paymentMode': 'Online',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
      }),
      TaskModel.fromJson({
        'id': 'drv-004-completed',
        'taskType': 'GroceryDelivery',
        'status': 'completed',
        'pickupAddress': 'Star Grocery, Mansarovar',
        'dropoffAddress': 'Indra Colony, Agra Road',
        'estimatedFare': 55,
        'distanceKm': 1.8,
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'completedAt': DateTime.now().subtract(const Duration(hours: 1, minutes: 40)).toIso8601String(),
      }),
      TaskModel.fromJson({
        'id': 'drv-005-completed',
        'taskType': 'MobilityRide',
        'status': 'completed',
        'pickupAddress': 'Jaipur Airport Gate 1',
        'dropoffAddress': 'Hotel Rajputana Palace',
        'estimatedFare': 280,
        'distanceKm': 8.5,
        'createdAt': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
        'completedAt': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      }),
      TaskModel.fromJson({
        'id': 'drv-006-cancelled',
        'taskType': 'GroceryDelivery',
        'status': 'cancelled',
        'pickupAddress': 'Raja Ram Kirana, Gopalpura',
        'dropoffAddress': 'Blue Hills Society',
        'estimatedFare': 45,
        'distanceKm': 1.2,
        'createdAt': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      }),
    ];
  }

  // ─── GPS & Duty ───────────────────────────────────────────────────

  void _startGps() async {
    _gpsTimer?.cancel();
    final mqtt = MqttService();
    await mqtt.connect();
    if (mounted) setState(() => _mqttActive = true);
    _gpsTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.isAuthenticated || _dutyStatus == 'OffDuty') {
        _stopGps();
        return;
      }
      _lat += 0.0002;
      _lng += 0.00015;
      mqtt.publishDriverLocation(
          driverId: auth.userId ?? '',
          deviceId: auth.deviceId,
          latitude: _lat,
          longitude: _lng,
          speed: 35.0,
          heading: 90.0);
      try {
        await ApiService.recordGpsPing(
            token: auth.token!,
            deviceId: auth.deviceId,
            latitude: _lat,
            longitude: _lng);
      } catch (_) {}
    });
  }

  void _stopGps() {
    _gpsTimer?.cancel();
    _gpsTimer = null;
    if (mounted) setState(() => _mqttActive = false);
  }

  Future<void> _toggleDuty(String status) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res =
          await ApiService.updateDutyStatus(auth.token!, status, auth.deviceId);
      setState(() => _dutyStatus = res['dutyStatus'] ?? status);
      if (_dutyStatus != 'OffDuty') {
        _startGps();
      } else {
        _stopGps();
      }
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _selectVehicle(String id) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await ApiService.selectActiveVehicle(auth.token!, id);
      await _loadVehicles();
      _showSnack('Vehicle activated!', const Color(0xFF10B981));
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _updateRadius() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await ApiService.updateRadius(auth.token!, _acceptKm, _deliveryKm);
      _showSnack('Radius updated!', const Color(0xFF3B82F6));
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _verifyOtp(bool isPickup) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (_activeTask == null) return;
    try {
      if (isPickup) {
        await ApiService.verifyPickupOtp(
            auth.token!, _activeTask!.id, _otpCtrl.text.trim(), auth.deviceId);
        _showSnack('Pickup verified! En route to drop.', const Color(0xFF8B5CF6));
      } else {
        await ApiService.verifyDropoffOtp(
            auth.token!, _activeTask!.id, _otpCtrl.text.trim(), auth.deviceId);
        _showSnack('Drop OTP verified! Task completed! 🎉',
            const Color(0xFF10B981));
      }
      _otpCtrl.clear();
      _loadTasks();
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _createBanner() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final price = double.tryParse(_priceCtrl.text) ?? 1500;
      final seats = int.tryParse(_seatsCtrl.text) ?? 3;
      await ApiService.createIntercityBanner(
          auth.token!,
          _fromCityCtrl.text.trim(),
          _toCityCtrl.text.trim(),
          DateTime.now().add(const Duration(hours: 12)),
          seats,
          price);
      _showSnack(
          'Banner posted: ${_fromCityCtrl.text} → ${_toCityCtrl.text} @ ₹$price',
          const Color(0xFFF97316));
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  void _showSnack(String msg, Color bg) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
    }
  }

  void _showAddVehicleModal() {
    final makeCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final photoCtrl = TextEditingController();
    String selectedType = 'Bike';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add Vehicle to My Garage',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Register your vehicle with details & photo',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: makeCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Make (e.g. Hero, Honda)',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          prefixIcon: const Icon(Icons.branding_watermark_outlined, color: Colors.grey, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: modelCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Model (e.g. Splendor, Activa)',
                          hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          prefixIcon: const Icon(Icons.motorcycle_rounded, color: Colors.grey, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: plateCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Number Plate (e.g. RJ-14-EA-4512)',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    prefixIcon: const Icon(Icons.badge_outlined, color: Colors.grey, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedType,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: [
                        'Bike',
                        'Scooter',
                        'Car',
                        'Auto',
                        'Van',
                        'Bicycle',
                      ].map((t) => DropdownMenuItem(value: t, child: Text('Type: $t'))).toList(),
                      onChanged: (val) {
                        if (val != null) setMState(() => selectedType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: photoCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Vehicle Photo URL (optional)',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    prefixIcon: const Icon(Icons.camera_alt_outlined, color: Colors.grey, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (plateCtrl.text.trim().isEmpty) {
                        _showSnack('Vehicle plate number is required', Colors.redAccent);
                        return;
                      }
                      Navigator.pop(ctx);
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final photoVal = photoCtrl.text.trim().isNotEmpty
                          ? photoCtrl.text.trim()
                          : 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=200';
                      final payload = {
                        'plateNumber': plateCtrl.text.trim().toUpperCase(),
                        'make': makeCtrl.text.trim().isEmpty ? 'Hero' : makeCtrl.text.trim(),
                        'model': modelCtrl.text.trim().isEmpty ? selectedType : modelCtrl.text.trim(),
                        'vehicleType': selectedType,
                        'photoUrl': photoVal,
                      };
                      try {
                        await ApiService.addVehicle(auth.token!, payload);
                        _showSnack('Vehicle added to garage!', const Color(0xFF10B981));
                      } catch (_) {
                        setState(() {
                          _vehicles.add({
                            'id': 'v-${DateTime.now().millisecondsSinceEpoch}',
                            'plateNumber': plateCtrl.text.trim().toUpperCase(),
                            'make': makeCtrl.text.trim().isEmpty ? 'Hero' : makeCtrl.text.trim(),
                            'model': modelCtrl.text.trim().isEmpty ? selectedType : modelCtrl.text.trim(),
                            'vehicleType': selectedType,
                            'photoUrl': photoVal,
                            'isActive': _vehicles.isEmpty,
                          });
                          if (_vehicles.length == 1) {
                            _activeVehicleId = _vehicles.first['id'];
                          }
                        });
                        _showSnack('Vehicle registered locally!', const Color(0xFF10B981));
                      }
                      _loadVehicles();
                    },
                    icon: const Icon(Icons.two_wheeler_rounded, size: 18),
                    label: const Text('Save Vehicle to Garage', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── Build ───────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF060B18),
      drawer: const AppMenuDrawer(activeItem: 'Dashboard'),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [_buildSliverHeader(auth)],
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboardTab(),
                  _buildTasksTab(),
                  _buildActiveTaskTab(),
                  _buildVehicleTab(),
                  _buildBannerTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sliver Header ───────────────────────────────────────────────
  Widget _buildSliverHeader(AuthProvider auth) {
    final todayEarn = _stats.totalEarnings;
    return SliverAppBar(
      expandedHeight: 230,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF060B18),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      actions: [
        Consumer<NotificationStore>(
          builder: (_, store, __) => Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: Colors.white, size: 24),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationCenterScreen()),
                ),
              ),
              if (store.unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      store.unreadCount > 9 ? '9+' : '${store.unreadCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Driver Dashboard',
                              style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13)),
                          Text(auth.fullName ?? 'Delivery Boy',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          // Duty status pill
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _dutyStatus != 'OffDuty'
                                  ? const Color(0xFF10B981).withValues(alpha: 0.25)
                                  : Colors.grey.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _dutyStatus != 'OffDuty'
                                      ? const Color(0xFF10B981)
                                      : Colors.grey),
                            ),
                            child: Row(children: [
                              Icon(Icons.circle,
                                  size: 8,
                                  color: _dutyStatus != 'OffDuty'
                                      ? const Color(0xFF34D399)
                                      : Colors.grey),
                              const SizedBox(width: 5),
                              Text(_dutyStatus.toUpperCase(),
                                  style: TextStyle(
                                      color: _dutyStatus != 'OffDuty'
                                          ? const Color(0xFF34D399)
                                          : Colors.grey,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            ]),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: [
                                const Text('EARNINGS',
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold)),
                                Text('₹${todayEarn.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        color: Color(0xFFFCD34D),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                const Text('Today',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 9)),
                              ],
                            ),
                          ),
                          // MQTT dot
                          const SizedBox(height: 6),
                          Row(children: [
                            Icon(Icons.radar_rounded,
                                size: 12,
                                color: _mqttActive
                                    ? const Color(0xFF34D399)
                                    : Colors.grey),
                            const SizedBox(width: 4),
                            Text(
                                _mqttActive
                                    ? 'GPS LIVE'
                                    : 'GPS OFF',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: _mqttActive
                                        ? const Color(0xFF34D399)
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold)),
                          ]),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildStatsRow(),
                ],
              ),
            ),
          ),
        ),
      ),
      title: const Text('Driver Console',
          style: TextStyle(color: Colors.white, fontSize: 16)),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statItem(_pendingDispatch.length.toString(), 'New',
            const Color(0xFFF59E0B), Icons.notifications_active_rounded),
        const SizedBox(width: 8),
        _statItem(_stats.assigned.toString(), 'Assigned',
            const Color(0xFF3B82F6), Icons.assignment_ind_rounded),
        const SizedBox(width: 8),
        _statItem(_stats.ongoing.toString(), 'Active',
            const Color(0xFF8B5CF6), Icons.local_shipping_rounded),
        const SizedBox(width: 8),
        _statItem(_stats.completed.toString(), 'Done',
            const Color(0xFF10B981), Icons.check_circle_rounded),
        const SizedBox(width: 8),
        _statItem(_stats.cancelled.toString(), 'Skip',
            const Color(0xFFEF4444), Icons.cancel_rounded),
      ],
    );
  }

  Widget _statItem(String val, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(height: 2),
            Text(val,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 8)),
          ],
        ),
      ),
    );
  }

  // ─── TabBar ──────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF0F172A),
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFFF59E0B),
        indicatorWeight: 3,
        isScrollable: true,
        labelColor: const Color(0xFFFCD34D),
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(
            fontWeight: FontWeight.bold, fontSize: 11),
        tabs: [
          Tab(
            icon: _pendingDispatch.isNotEmpty
                ? Stack(children: [
                    const Icon(Icons.notifications_active_rounded, size: 18),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ])
                : const Icon(Icons.home_rounded, size: 18),
            text: 'Overview',
          ),
          const Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'All Tasks'),
          const Tab(icon: Icon(Icons.local_shipping_rounded, size: 18), text: 'Active'),
          const Tab(icon: Icon(Icons.two_wheeler_rounded, size: 18), text: 'Vehicles'),
          const Tab(icon: Icon(Icons.campaign_rounded, size: 18), text: 'Intercity'),
        ],
      ),
    );
  }

  // ─── TAB 1: Overview / Dashboard ─────────────────────────────────
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Duty toggle card
          _dutyCard(),
          const SizedBox(height: 16),
          // Radius card
          _radiusCard(),
          const SizedBox(height: 16),
          // Pending dispatches (if any)
          if (_pendingDispatch.isNotEmpty) ...[
            Row(children: [
              const Icon(Icons.notifications_active_rounded,
                  color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 8),
              Text('${_pendingDispatch.length} Pending Dispatch',
                  style: const TextStyle(
                      color: Color(0xFFFCD34D),
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ]),
            const SizedBox(height: 10),
            ..._pendingDispatch.map((t) => TaskCard12DriverDispatch(
                  task: t,
                  onAccept: () async {
                    final auth =
                        Provider.of<AuthProvider>(context, listen: false);
                    try {
                      await ApiService.acceptTask(
                          auth.token!, t.id, auth.deviceId);
                      _showSnack('Task accepted!', const Color(0xFF10B981));
                      _loadTasks();
                    } catch (e) {
                      _showSnack(e.toString(), Colors.redAccent);
                    }
                  },
                  onReject: () {
                    _showSnack('Task rejected', Colors.grey);
                    _loadTasks();
                  },
                )),
            const SizedBox(height: 16),
          ],
          // VoIP quick connect
          _voipCard(),
        ],
      ),
    );
  }

  Widget _dutyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: _dutyStatus != 'OffDuty'
                ? const Color(0xFF10B981).withValues(alpha: 0.4)
                : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Duty Status',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Free', 'GoingToPickup', 'InTransit', 'OffDuty']
                .map((s) {
              final isSelected = _dutyStatus == s;
              final color = s == 'OffDuty'
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF10B981);
              return GestureDetector(
                onTap: () => _toggleDuty(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withValues(alpha: 0.2)
                        : const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: isSelected ? color : Colors.transparent),
                  ),
                  child: Text(s,
                      style: TextStyle(
                          color: isSelected ? color : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _mqttActive
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: _mqttActive
                      ? const Color(0xFF10B981)
                      : Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.radar_rounded,
                    size: 15,
                    color: _mqttActive
                        ? const Color(0xFF34D399)
                        : Colors.grey),
                const SizedBox(width: 8),
                Text(
                    _mqttActive
                        ? 'MQTT GPS: Live (Mosquitto 1883 • 4s ping)'
                        : 'MQTT GPS: Off Duty',
                    style: TextStyle(
                        fontSize: 12,
                        color: _mqttActive
                            ? const Color(0xFF34D399)
                            : Colors.grey,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _radiusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Operating Radius',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Pickup Acceptance:',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            Text('${_acceptKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                    color: Color(0xFFFCD34D), fontWeight: FontWeight.bold)),
          ]),
          SliderTheme(
            data: SliderTheme.of(context)
                .copyWith(activeTrackColor: const Color(0xFFF59E0B)),
            child: Slider(
              value: _acceptKm,
              min: 0.5,
              max: 10.0,
              divisions: 19,
              activeColor: const Color(0xFFF59E0B),
              onChanged: (v) => setState(() => _acceptKm = v),
              onChangeEnd: (_) => _updateRadius(),
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Max Delivery:',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
            Text('${_deliveryKm.toStringAsFixed(1)} km',
                style: const TextStyle(
                    color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
          ]),
          Slider(
            value: _deliveryKm,
            min: 1.0,
            max: 50.0,
            divisions: 49,
            activeColor: const Color(0xFF3B82F6),
            onChanged: (v) => setState(() => _deliveryKm = v),
            onChangeEnd: (_) => _updateRadius(),
          ),
        ],
      ),
    );
  }

  Widget _voipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.phone_in_talk_rounded,
                color: Color(0xFF34D399), size: 20),
            SizedBox(width: 8),
            Text('VoIP Quick Dial',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CallingScreen(
                                partnerUserId:
                                    'c1111111-1111-1111-1111-111111111111',
                                partnerName: 'Rahul (Customer)',
                                partnerRole: 'Customer',
                              ))),
                  icon: const Icon(Icons.person_rounded, size: 16),
                  label: const Text('Call Customer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CallingScreen(
                                partnerUserId:
                                    '7a74b169-0512-4a3b-9f7d-6020832ceaf0',
                                partnerName: 'Gupta Store',
                                partnerRole: 'Shop Owner',
                              ))),
                  icon: const Icon(Icons.storefront_rounded, size: 16),
                  label: const Text('Call Shop'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: All Tasks with Filter ────────────────────────────────
  Widget _buildTasksTab() {
    final filtered = _filterStatus == null
        ? _tasks
        : _tasks.where((t) => t.status == _filterStatus).toList();

    return RefreshIndicator(
      onRefresh: _loadTasks,
      color: const Color(0xFFF59E0B),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(null, 'All', _filterStatus == null),
                  ...TaskStatus.values.map((s) =>
                      _filterChip(s, s.label, _filterStatus == s)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_loadingTasks)
              const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFF59E0B)))
            else if (filtered.isEmpty)
              _emptyState(
                  'No ${_filterStatus?.label.toLowerCase() ?? ''} tasks',
                  Icons.inbox_rounded)
            else
              ...filtered.map((t) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildTaskCard(t,
                          viewerRole: 'Driver',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TaskBookingDetailsScreen(
                                  taskId: t.id,
                                  userRole: 'Driver',
                                  initialTask: t,
                                ),
                              ),
                            );
                          },
                          onAccept: () async {
                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            try {
                              await ApiService.acceptTask(auth.token!, t.id, auth.deviceId);
                              _showSnack('Task accepted!', const Color(0xFF10B981));
                              _loadTasks();
                            } catch (e) {
                              _showSnack(e.toString(), Colors.redAccent);
                            }
                          },
                          onReject: () {
                            _showSnack('Task rejected', Colors.grey);
                          }),
                      if (t.status == TaskStatus.completed)
                        Container(
                          margin: const EdgeInsets.only(top: -6, bottom: 14),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.star_half_rounded, color: Color(0xFFF59E0B), size: 16),
                                  SizedBox(width: 8),
                                  Text('Rate Customer', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () => showOrderRatingBottomSheet(context, task: t, viewerRole: 'Driver'),
                                icon: const Icon(Icons.star_rounded, size: 14),
                                label: const Text('Rate Customer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF59E0B),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(TaskStatus? status, String label, bool selected) {
    final color = status?.color ?? Colors.grey;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = status),
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: selected ? color : Colors.white12, width: 1.2),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : Colors.grey,
                fontSize: 11,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  // ─── TAB 3: Active Task / OTP Verify ─────────────────────────────
  Widget _buildActiveTaskTab() {
    if (_activeTask == null) {
      return _emptyState('No active task right now', Icons.check_circle_rounded);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_activeTask!.status == TaskStatus.assign ||
              _activeTask!.status == TaskStatus.ongoing)
            TaskCard15OtpVerify(
              task: _activeTask!,
              otpCtrl: _otpCtrl,
              onVerifyPickup: () => _verifyOtp(true),
              onVerifyDrop: () => _verifyOtp(false),
            ),
          const SizedBox(height: 16),
          // Task details
          TaskCard4NeonGlow(task: _activeTask!, onTap: null),
          const SizedBox(height: 16),
          // Call customer
          Row(children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CallingScreen(
                              partnerUserId:
                                  _activeTask!.raw['customerId'] ?? '',
                              partnerName:
                                  _activeTask!.customerName ?? 'Customer',
                              partnerRole: 'Customer',
                              taskId: _activeTask!.id,
                            ))),
                icon: const Icon(Icons.call_rounded, size: 16),
                label: const Text('Call Customer'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ─── TAB 4: Vehicles ──────────────────────────────────────────────
  Widget _buildVehicleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(Icons.two_wheeler_rounded, 'My Garage (${_vehicles.length})',
                  const Color(0xFFF59E0B)),
              ElevatedButton.icon(
                onPressed: _showAddVehicleModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Vehicle', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('You can own & register multiple vehicles. Choose 1 to take ONLINE.',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
                child: CircularProgressIndicator(color: Color(0xFFF59E0B)))
          else if (_vehicles.isEmpty)
            _emptyState('No vehicles added yet. Tap Add Vehicle above.', Icons.two_wheeler_rounded)
          else
            ..._vehicles.map((v) {
              final isActive = v['id'] == _activeVehicleId;
              final photo = v['photoUrl'];
              final hasPhoto = photo != null && photo.toString().startsWith('http');
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                      : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isActive
                          ? const Color(0xFFF59E0B)
                          : Colors.white12),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: isActive
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.2)
                            : const Color(0xFF334155),
                        child: hasPhoto
                            ? Image.network(
                                photo.toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  v['vehicleType'] == 'Bike'
                                      ? Icons.two_wheeler_rounded
                                      : Icons.directions_car_rounded,
                                  color: isActive
                                      ? const Color(0xFFFCD34D)
                                      : Colors.white70,
                                  size: 24,
                                ),
                              )
                            : Icon(
                                v['vehicleType'] == 'Bike'
                                    ? Icons.two_wheeler_rounded
                                    : Icons.directions_car_rounded,
                                color: isActive
                                    ? const Color(0xFFFCD34D)
                                    : Colors.white70,
                                size: 24,
                              ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${v['make']} ${v['model']}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF334155),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(v['plateNumber'] ?? '',
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 6),
                              Text(v['vehicleType'] ?? 'Vehicle',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                        ),
                        child: const Text('ONLINE',
                            style: TextStyle(
                                color: Color(0xFFFCD34D),
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                      )
                    else
                      TextButton.icon(
                        onPressed: () => _selectVehicle(v['id']),
                        icon: const Icon(Icons.flash_on_rounded, size: 14),
                        label: const Text('Go Online',
                            style: TextStyle(
                                color: Color(0xFF38BDF8),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 24),

          // Connected Shops Section (Multi-shop connection feature)
          _sectionHeader(Icons.store_mall_directory_rounded, 'Connected Shops & Partners',
              const Color(0xFF38BDF8)),
          const SizedBox(height: 4),
          const Text('You can receive delivery requests from multiple neighborhood shops',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: Color(0xFF38BDF8), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('My Kirana Store (Main Market)',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          SizedBox(height: 2),
                          Text('Primary Affiliated Merchant • Status: Active Team',
                              style: TextStyle(
                                  color: Color(0xFF34D399), fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Linked',
                          style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Colors.white10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.local_shipping_outlined,
                          color: Color(0xFFF59E0B), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Vaishali Fresh Dairy & School Mobility',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          SizedBox(height: 2),
                          Text('Secondary Partner • Morning Run & School Transport',
                              style: TextStyle(
                                  color: Color(0xFFFCD34D), fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Linked',
                          style: TextStyle(
                              color: Color(0xFFFCD34D),
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── TAB 5: Intercity Banner Creator ──────────────────────────────
  Widget _buildBannerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(Icons.campaign_rounded, 'Broadcast Intercity Route',
              const Color(0xFFF97316)),
          const SizedBox(height: 4),
          const Text(
              'Announce your route and pick up customers along the way',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: _inputField(_fromCityCtrl, 'From City',
                        Icons.trip_origin_rounded, const Color(0xFF10B981)),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: Colors.grey, size: 18),
                  ),
                  Expanded(
                    child: _inputField(_toCityCtrl, 'To City',
                        Icons.place_rounded, const Color(0xFFEF4444)),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _inputField(_priceCtrl, 'Price / Seat (₹)',
                        Icons.currency_rupee_rounded, const Color(0xFFF59E0B)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _inputField(_seatsCtrl, 'Seats',
                        Icons.event_seat_rounded, const Color(0xFF8B5CF6)),
                  ),
                ]),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _createBanner,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Broadcast to Customers',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared Helpers ───────────────────────────────────────────────
  Widget _inputField(TextEditingController ctrl, String label,
      IconData icon, Color iconColor) {
    return TextField(
      controller: ctrl,
      keyboardType: label.contains('₹') || label.contains('Seat')
          ? TextInputType.number
          : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        prefixIcon: Icon(icon, color: iconColor, size: 18),
        filled: true,
        fillColor: const Color(0xFF0F172A),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: iconColor, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
    ]);
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade700),
            const SizedBox(height: 12),
            Text(msg,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
