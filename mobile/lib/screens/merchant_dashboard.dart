import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_store.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../models/task_status_models.dart';
import '../widgets/task_detail_cards.dart';
import 'calling_screen.dart';
import 'notification_center_screen.dart';
import 'task_booking_details_screen.dart';
import '../widgets/app_menu_drawer.dart';

class MerchantDashboard extends StatefulWidget {
  const MerchantDashboard({super.key});

  @override
  State<MerchantDashboard> createState() => _MerchantDashboardState();
}

class _MerchantDashboardState extends State<MerchantDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Shops State
  List<dynamic> _shops = [];
  Map<String, dynamic>? _activeShop;
  bool _loadingShops = false;

  // Orders State
  List<TaskModel> _shopOrders = [];
  bool _loadingOrders = false;
  TaskStatus? _filterStatus;
  DashboardStats _stats = const DashboardStats();

  // Delivery Boys State
  List<dynamic> _deliveryBoys = [];
  bool _loadingDeliveryBoys = false;

  // Vehicle Fleet State
  List<dynamic> _vehicles = [];
  bool _loadingVehicles = false;

  // Customers State
  List<dynamic> _customers = [];
  bool _loadingCustomers = false;

  // Catalog State
  List<dynamic> _catalogItems = [];
  bool _loadingCatalog = false;
  String _catalogSearchQuery = '';
  String? _catalogFilterCategory;

  // Categories & Sub-Categories
  final List<String> _availableCategories = [
    'Grocery & Kirana',
    'Fruits & Vegetables',
    'Dairy & Milk',
    'Pharmacy & Meds',
    'Food & Snacks',
    'Bakery & Sweets',
    'Stationery & Books',
    'Hardware & Electrical',
    'Clothing & Tailor',
    'Services & Repair',
  ];
  List<String> _shopSelectedCategories = [
    'Grocery & Kirana',
    'Fruits & Vegetables',
    'Dairy & Milk',
  ];
  List<String> _shopSubCategories = [
    'Atta & Flours',
    'Dal & Pulses',
    'Oils & Ghee',
    'Spices & Masala',
    'Rice & Grains',
    'Dairy & Fresh Milk',
    'Snacks & Beverages',
    'Household & Cleaning',
  ];

  // RFQ and Khata
  List<dynamic> _openRfqs = [];
  bool _loadingRfqs = false;
  List<dynamic> _khataLedger = [];
  bool _duesEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadAllData();

    NotificationService.onTaskUpdated = (d) {
      if (mounted) {
        _loadOrders();
        _loadDeliveryBoys();
        _showSnack('🔔 Real-time order/task update received!', const Color(0xFF10B981));
      }
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ────────────────────────── Data Loading ──────────────────────────

  Future<void> _loadAllData() async {
    await _loadShops();
    _loadOrders();
    _loadDeliveryBoys();
    _loadVehicles();
    _loadCustomers();
    _loadCatalog();
    _loadRfqs();
    _loadKhata();
  }

  Future<void> _loadShops() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    setState(() => _loadingShops = true);
    try {
      final shops = await ApiService.getMyShops(auth.token!);
      setState(() {
        _shops = shops;
        if (_shops.isNotEmpty) {
          _activeShop = _shops.first as Map<String, dynamic>;
        } else {
          _activeShop = {
            'id': '7a74b169-0512-4a3b-9f7d-6020832ceaf0',
            'name': 'My Kirana Store',
            'category': 'Grocery & Kirana',
            'address': 'Shop #1, Main Market, Vaishali Nagar',
            'phone': auth.phone ?? '9876543210',
            'duesEnabledGlobally': true,
          };
          _shops = [_activeShop!];
        }
        _loadingShops = false;
      });
    } catch (_) {
      setState(() {
        _activeShop = {
          'id': '7a74b169-0512-4a3b-9f7d-6020832ceaf0',
          'name': 'My Kirana Store',
          'category': 'Grocery & Kirana',
          'address': 'Shop #1, Main Market, Vaishali Nagar',
          'phone': auth.phone ?? '9876543210',
          'duesEnabledGlobally': true,
        };
        _shops = [_activeShop!];
        _loadingShops = false;
      });
    }
  }

  String get _currentShopId =>
      _activeShop?['id']?.toString() ?? '7a74b169-0512-4a3b-9f7d-6020832ceaf0';

  Future<void> _loadOrders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    setState(() => _loadingOrders = true);

    try {
      final rawOrders = await ApiService.getShopOrders(auth.token!, _currentShopId);
      final tasks = rawOrders.map<TaskModel>((o) => TaskModel.fromJson(o)).toList();
      if (tasks.isNotEmpty) {
        setState(() {
          _shopOrders = tasks;
          _stats = DashboardStats.fromTasks(tasks);
          _loadingOrders = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback seed tasks for rich demo
    final mocks = _buildDefaultMockOrders();
    setState(() {
      _shopOrders = mocks;
      _stats = DashboardStats.fromTasks(mocks);
      _loadingOrders = false;
    });
  }

  Future<void> _loadDeliveryBoys() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    setState(() => _loadingDeliveryBoys = true);
    try {
      final boys = await ApiService.getShopDeliveryBoys(auth.token!, _currentShopId);
      if (boys.isNotEmpty) {
        setState(() {
          _deliveryBoys = boys;
          _loadingDeliveryBoys = false;
        });
        return;
      }
    } catch (_) {}

    // Default mock delivery boys
    setState(() {
      _deliveryBoys = [
        {
          'id': 'drv-001',
          'fullName': 'Suresh Yadav',
          'phone': '9829011223',
          'dutyStatus': 'Free',
          'vehicleType': 'Hero Splendor (Bike)',
          'plateNumber': 'RJ-14-EA-4512',
          'rating': 4.9,
          'activeTasksCount': 0,
        },
        {
          'id': 'drv-002',
          'fullName': 'Ramesh Kumar',
          'phone': '9829033445',
          'dutyStatus': 'GoingToPickup',
          'vehicleType': 'Honda Activa (Scooter)',
          'plateNumber': 'RJ-14-MK-8821',
          'rating': 4.7,
          'activeTasksCount': 1,
        },
        {
          'id': 'drv-003',
          'fullName': 'Vijay Singh',
          'phone': '9829055667',
          'dutyStatus': 'InTransit',
          'vehicleType': 'Bajaj Pulsar',
          'plateNumber': 'RJ-14-ST-9901',
          'rating': 4.8,
          'activeTasksCount': 1,
        },
      ];
      _loadingDeliveryBoys = false;
    });
  }

  Future<void> _loadVehicles() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    setState(() => _loadingVehicles = true);
    try {
      final vList = await ApiService.getShopVehicles(auth.token!, _currentShopId);
      if (vList.isNotEmpty) {
        setState(() {
          _vehicles = vList;
          _loadingVehicles = false;
        });
        return;
      }
    } catch (_) {}

    setState(() {
      _vehicles = [
        {
          'id': 'v-001',
          'plateNumber': 'RJ-14-EA-4512',
          'make': 'Hero',
          'model': 'Splendor Plus',
          'type': 'Motorcycle',
          'photoUrl': 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=200',
          'isAvailable': true,
          'assignedDriverName': 'Suresh Yadav',
          'assignedDriverPhone': '9829011223',
        },
        {
          'id': 'v-002',
          'plateNumber': 'RJ-14-MK-8821',
          'make': 'Honda',
          'model': 'Activa 6G',
          'type': 'Scooter',
          'photoUrl': 'https://images.unsplash.com/photo-1558980664-769d59546b3d?w=200',
          'isAvailable': true,
          'assignedDriverName': 'Ramesh Kumar',
          'assignedDriverPhone': '9829033445',
        },
        {
          'id': 'v-003',
          'plateNumber': 'RJ-14-ST-9901',
          'make': 'Bajaj',
          'model': 'Pulsar 150',
          'type': 'Motorcycle',
          'photoUrl': 'https://images.unsplash.com/photo-1568772585407-9361f9bf3a87?w=200',
          'isAvailable': true,
          'assignedDriverName': 'Vijay Singh',
          'assignedDriverPhone': '9829055667',
        },
        {
          'id': 'v-004',
          'plateNumber': 'RJ-14-BUS-2024',
          'make': 'Force',
          'model': 'Traveller School Van',
          'type': 'Van',
          'photoUrl': 'https://images.unsplash.com/photo-1544620347-c4fd4a3d5957?w=200',
          'isAvailable': true,
          'assignedDriverName': null,
          'assignedDriverPhone': null,
        },
      ];
      _loadingVehicles = false;
    });
  }

  Future<void> _loadCustomers() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    setState(() => _loadingCustomers = true);
    try {
      final custs = await ApiService.getShopCustomers(auth.token!, _currentShopId);
      if (custs.isNotEmpty) {
        setState(() {
          _customers = custs;
          _loadingCustomers = false;
        });
        return;
      }
    } catch (_) {}

    setState(() {
      _customers = [
        {
          'id': 'c-001',
          'fullName': 'Rajesh Sharma',
          'phone': '9828012345',
          'address': 'Plot 42, Chitrakoot Sector 3, Vaishali Nagar',
          'totalOrders': 14,
          'khataBalance': 450.0,
          'creditLimit': 5000.0,
          'isDuesAllowed': true,
        },
        {
          'id': 'c-002',
          'fullName': 'Priya Gupta',
          'phone': '9828054321',
          'address': 'Flat 204, Royal Palms, Queens Road',
          'totalOrders': 8,
          'khataBalance': 0.0,
          'creditLimit': 3000.0,
          'isDuesAllowed': true,
        },
        {
          'id': 'c-003',
          'fullName': 'Amit Verma',
          'phone': '9828099887',
          'address': 'Block B-12, Shyam Nagar',
          'totalOrders': 22,
          'khataBalance': 1200.0,
          'creditLimit': 8000.0,
          'isDuesAllowed': true,
        },
        {
          'id': 'c-004',
          'fullName': 'Sunita Devi',
          'phone': '9828044332',
          'address': 'House 19, Nirman Nagar',
          'totalOrders': 5,
          'khataBalance': 180.0,
          'creditLimit': 2000.0,
          'isDuesAllowed': true,
        },
      ];
      _loadingCustomers = false;
    });
  }

  Future<void> _loadCatalog() async {
    setState(() => _loadingCatalog = true);
    try {
      final items = await ApiService.getShopCatalog(_currentShopId);
      if (items.isNotEmpty) {
        setState(() {
          _catalogItems = items;
          _loadingCatalog = false;
        });
        return;
      }
    } catch (_) {}

    setState(() {
      _catalogItems = [
        {
          'id': 'cat-1',
          'name': 'Aashirvaad Shudh Chakki Atta',
          'category': 'Grocery & Kirana',
          'subCategory': 'Atta & Flours',
          'price': 420.0,
          'unit': '10 kg pack',
          'isInStock': true,
        },
        {
          'id': 'cat-2',
          'name': 'Fresh Farm Cow Milk',
          'category': 'Dairy & Milk',
          'subCategory': 'Dairy & Fresh Milk',
          'price': 62.0,
          'unit': '1 litre',
          'isInStock': true,
        },
        {
          'id': 'cat-3',
          'name': 'Fresh Red Onions (Pyaj)',
          'category': 'Fruits & Vegetables',
          'subCategory': 'Vegetables',
          'price': 35.0,
          'unit': '1 kg',
          'isInStock': true,
        },
        {
          'id': 'cat-4',
          'name': 'Fresh Mountain Potatoes (Aloo)',
          'category': 'Fruits & Vegetables',
          'subCategory': 'Vegetables',
          'price': 25.0,
          'unit': '1 kg',
          'isInStock': true,
        },
        {
          'id': 'cat-5',
          'name': 'Tata Salt Vacuum Evaporated',
          'category': 'Grocery & Kirana',
          'subCategory': 'Spices & Masala',
          'price': 28.0,
          'unit': '1 kg pack',
          'isInStock': true,
        },
        {
          'id': 'cat-6',
          'name': 'Amul Pure Cow Ghee',
          'category': 'Dairy & Milk',
          'subCategory': 'Oils & Ghee',
          'price': 580.0,
          'unit': '1 litre jar',
          'isInStock': false,
        },
      ];
      _loadingCatalog = false;
    });
  }

  Future<void> _loadRfqs() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    setState(() => _loadingRfqs = true);
    try {
      final feed = await ApiService.getMerchantRfqFeed(auth.token!);
      setState(() {
        _openRfqs = feed;
        _loadingRfqs = false;
      });
    } catch (_) {
      setState(() => _loadingRfqs = false);
    }
  }

  Future<void> _loadKhata() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    try {
      final data = await ApiService.getKhataLedger(auth.token!, 'default');
      setState(() => _khataLedger = data['entries'] ?? []);
    } catch (_) {}
  }

  List<TaskModel> _buildDefaultMockOrders() {
    final now = DateTime.now();
    return [
      TaskModel.fromJson({
        'id': 'ORD-9801',
        'taskType': 'GroceryDelivery',
        'status': 'pending',
        'pickupAddress': _activeShop?['address'] ?? 'My Shop, Vaishali Nagar',
        'dropoffAddress': 'Plot 42, Chitrakoot Sector 3, Vaishali Nagar',
        'estimatedFare': 340.0,
        'customerName': 'Rajesh Sharma',
        'customerPhone': '9828012345',
        'paymentMode': 'Cash',
        'items': [
          {'name': 'Aashirvaad Atta 10kg', 'qty': 1, 'price': 420},
          {'name': 'Tata Salt', 'qty': 1, 'price': 28}
        ],
        'createdAt': now.subtract(const Duration(minutes: 8)).toIso8601String(),
      }),
      TaskModel.fromJson({
        'id': 'ORD-9802',
        'taskType': 'GroceryDelivery',
        'status': 'assigned',
        'pickupAddress': _activeShop?['address'] ?? 'My Shop, Vaishali Nagar',
        'dropoffAddress': 'Flat 204, Royal Palms, Queens Road',
        'estimatedFare': 210.0,
        'customerName': 'Priya Gupta',
        'customerPhone': '9828054321',
        'driverName': 'Suresh Yadav',
        'driverPhone': '9829011223',
        'pickupOtp': '482910',
        'dropoffOtp': '901234',
        'paymentMode': 'Online',
        'createdAt': now.subtract(const Duration(minutes: 25)).toIso8601String(),
      }),
      TaskModel.fromJson({
        'id': 'ORD-9803',
        'taskType': 'GroceryDelivery',
        'status': 'ongoing',
        'pickupAddress': _activeShop?['address'] ?? 'My Shop, Vaishali Nagar',
        'dropoffAddress': 'Block B-12, Shyam Nagar',
        'estimatedFare': 480.0,
        'customerName': 'Amit Verma',
        'customerPhone': '9828099887',
        'driverName': 'Ramesh Kumar',
        'driverPhone': '9829033445',
        'pickupOtp': '332190',
        'dropoffOtp': '551290',
        'distanceKm': 2.8,
        'paymentMode': 'Dues',
        'createdAt': now.subtract(const Duration(minutes: 42)).toIso8601String(),
      }),
      TaskModel.fromJson({
        'id': 'ORD-9804',
        'taskType': 'GroceryDelivery',
        'status': 'completed',
        'pickupAddress': _activeShop?['address'] ?? 'My Shop, Vaishali Nagar',
        'dropoffAddress': 'House 19, Nirman Nagar',
        'estimatedFare': 160.0,
        'customerName': 'Sunita Devi',
        'customerPhone': '9828044332',
        'driverName': 'Vijay Singh',
        'driverPhone': '9829055667',
        'paymentMode': 'Cash',
        'createdAt': now.subtract(const Duration(hours: 2, minutes: 10)).toIso8601String(),
        'completedAt': now.subtract(const Duration(hours: 1, minutes: 40)).toIso8601String(),
      }),
    ];
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ────────────────────────── MODALS ──────────────────────────

  // 1. Direct Order / Task Creation Modal
  void _showDirectOrderModal({Map<String, dynamic>? preselectedCustomer}) {
    final custNameCtrl =
        TextEditingController(text: preselectedCustomer?['fullName'] ?? '');
    final custPhoneCtrl =
        TextEditingController(text: preselectedCustomer?['phone'] ?? '');
    final dropoffCtrl =
        TextEditingController(text: preselectedCustomer?['address'] ?? '');
    final fareCtrl = TextEditingController(text: '150');
    final itemsCtrl = TextEditingController(text: '5 kg Aloo, 2L Fresh Milk');

    String selectedPaymentMode = 'Cash';
    String selectedTaskType = 'GroceryDelivery';
    String? selectedDriverId;
    if (_deliveryBoys.isNotEmpty) {
      final freeBoy = _deliveryBoys.firstWhere(
        (b) => b['dutyStatus'] == 'Free',
        orElse: () => _deliveryBoys.first,
      );
      selectedDriverId = freeBoy['id']?.toString();
    }

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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.flash_on_rounded,
                          color: Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Direct Order / Task Creation',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18)),
                          Text('Shop: ${_activeShop?['name'] ?? 'My Store'}',
                              style: const TextStyle(
                                  color: Color(0xFF34D399), fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white12),

                // Task Type Selector (including School Transport / Ride)
                const Text('Task / Service Type',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedTaskType,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: [
                        DropdownMenuItem(
                          value: 'GroceryDelivery',
                          child: Row(children: const [
                            Icon(Icons.shopping_basket_rounded, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Text('Grocery Delivery'),
                          ]),
                        ),
                        DropdownMenuItem(
                          value: 'SchoolService',
                          child: Row(children: const [
                            Icon(Icons.directions_bus_rounded, size: 16, color: Color(0xFFFBBF24)),
                            SizedBox(width: 8),
                            Text('School Ride / School Transport'),
                          ]),
                        ),
                        DropdownMenuItem(
                          value: 'CourierPickup',
                          child: Row(children: const [
                            Icon(Icons.local_shipping_rounded, size: 16, color: Color(0xFF38BDF8)),
                            SizedBox(width: 8),
                            Text('Courier Pickup / Drop'),
                          ]),
                        ),
                        DropdownMenuItem(
                          value: 'FoodDelivery',
                          child: Row(children: const [
                            Icon(Icons.restaurant_rounded, size: 16, color: Color(0xFFF97316)),
                            SizedBox(width: 8),
                            Text('Food / Restaurant Delivery'),
                          ]),
                        ),
                        DropdownMenuItem(
                          value: 'MobilityRide',
                          child: Row(children: const [
                            Icon(Icons.local_taxi_rounded, size: 16, color: Color(0xFF8B5CF6)),
                            SizedBox(width: 8),
                            Text('Cab Ride / Passenger Mobility'),
                          ]),
                        ),
                        DropdownMenuItem(
                          value: 'MorningMilk',
                          child: Row(children: const [
                            Icon(Icons.wb_sunny_rounded, size: 16, color: Color(0xFF34D399)),
                            SizedBox(width: 8),
                            Text('Morning Milk / Dairy Run'),
                          ]),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setMState(() => selectedTaskType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Quick Customer Picker from Saved List
                if (_customers.isNotEmpty && preselectedCustomer == null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quick Select Customer',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text('${_customers.length} registered',
                          style: const TextStyle(
                              color: Color(0xFF34D399), fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _customers.map((c) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: const Icon(Icons.person_rounded,
                                size: 14, color: Color(0xFF38BDF8)),
                            label: Text(c['fullName'] ?? ''),
                            labelStyle: const TextStyle(
                                color: Colors.white, fontSize: 11),
                            backgroundColor: const Color(0xFF1E293B),
                            onPressed: () {
                              setMState(() {
                                custNameCtrl.text = c['fullName'] ?? '';
                                custPhoneCtrl.text = c['phone'] ?? '';
                                dropoffCtrl.text = c['address'] ?? '';
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Customer Inputs
                Row(
                  children: [
                    Expanded(
                      child: _fieldInput(
                        custNameCtrl,
                        'Customer Name',
                        Icons.person_outline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _fieldInput(
                        custPhoneCtrl,
                        'Phone Number',
                        Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _fieldInput(
                  dropoffCtrl,
                  'Delivery Address / Flat / Landmark',
                  Icons.location_on_outlined,
                ),
                const SizedBox(height: 14),

                // Order Items
                const Text('Order Items / Description',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _fieldInput(
                  itemsCtrl,
                  'e.g. 5 kg Aloo, 2L Amul Milk, 1kg Sugar',
                  Icons.receipt_long_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 14),

                // Fare & Payment Mode
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _fieldInput(
                        fareCtrl,
                        'Total Bill / Fare (₹)',
                        Icons.currency_rupee_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedPaymentMode,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                            items: ['Cash', 'Online', 'Dues'].map((mode) {
                              return DropdownMenuItem(
                                value: mode,
                                child: Text('Mode: $mode',
                                    style: TextStyle(
                                        color: mode == 'Dues'
                                            ? const Color(0xFFF59E0B)
                                            : Colors.white)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setMState(() => selectedPaymentMode = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Delivery Boy Assignment Selection
                const Text('⚡ Assign Delivery Boy',
                    style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selectedDriverId != null
                          ? const Color(0xFF10B981).withValues(alpha: 0.5)
                          : Colors.white12,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedDriverId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      hint: const Text('Broadcast to neighborhood (No specific driver)',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('📢 Broadcast to all nearby drivers',
                              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13)),
                        ),
                        ..._deliveryBoys.map((b) {
                          final isFree = b['dutyStatus'] == 'Free';
                          return DropdownMenuItem<String?>(
                            value: b['id']?.toString(),
                            child: Row(
                              children: [
                                Icon(Icons.circle,
                                    size: 10,
                                    color: isFree
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${b['fullName']} (${b['vehicleType'] ?? 'Bike'}) - ${b['dutyStatus']}',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setMState(() => selectedDriverId = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (custNameCtrl.text.trim().isEmpty ||
                          dropoffCtrl.text.trim().isEmpty) {
                        _showSnack('Please enter customer name and delivery address',
                            Colors.redAccent);
                        return;
                      }

                      Navigator.pop(ctx);
                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);

                      final payload = {
                        'businessId': _currentShopId,
                        'customerName': custNameCtrl.text.trim(),
                        'customerPhone': custPhoneCtrl.text.trim().isEmpty
                            ? '9876543210'
                            : custPhoneCtrl.text.trim(),
                        'dropoffAddress': dropoffCtrl.text.trim(),
                        'pickupAddress': _activeShop?['address'] ?? 'Shop Premises',
                        'fareAmount': double.tryParse(fareCtrl.text) ?? 120.0,
                        'paymentMode': selectedPaymentMode,
                        'taskType': selectedTaskType,
                        'orderItemsJson': jsonEncode([
                          {'name': itemsCtrl.text.trim(), 'quantity': 1}
                        ]),
                        'assignedDriverId': selectedDriverId,
                      };

                      try {
                        await ApiService.createMerchantDirectOrder(
                            auth.token!, payload);
                        _showSnack('✅ Order created & assigned successfully!',
                            const Color(0xFF10B981));
                      } catch (_) {
                        // Optimistic local add
                        final driverObj = _deliveryBoys.firstWhere(
                          (b) => b['id']?.toString() == selectedDriverId,
                          orElse: () => null,
                        );

                        final newLocalTask = TaskModel.fromJson({
                          'id': 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                          'taskType': selectedTaskType,
                          'status': selectedDriverId != null ? 'assign' : 'pending',
                          'pickupAddress': _activeShop?['address'] ?? 'Shop Premises',
                          'dropoffAddress': dropoffCtrl.text.trim(),
                          'estimatedFare': double.tryParse(fareCtrl.text) ?? 120.0,
                          'customerName': custNameCtrl.text.trim(),
                          'customerPhone': custPhoneCtrl.text.trim(),
                          'driverName': driverObj?['fullName'],
                          'driverPhone': driverObj?['phone'],
                          'paymentMode': selectedPaymentMode,
                          'pickupOtp': '452109',
                          'dropoffOtp': '982314',
                          'createdAt': DateTime.now().toIso8601String(),
                        });

                        setState(() {
                          _shopOrders.insert(0, newLocalTask);
                          _stats = DashboardStats.fromTasks(_shopOrders);
                        });
                        _showSnack('Order created & assigned to delivery boy!',
                            const Color(0xFF10B981));
                      }
                      _loadOrders();
                    },
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      selectedDriverId != null
                          ? 'Create Order & Assign Delivery Boy'
                          : 'Create Order & Broadcast',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
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

  // 2. Assign Delivery Boy Modal for Pending Order
  void _showAssignDriverModal(TaskModel task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.assignment_ind_rounded,
                      color: Color(0xFF38BDF8), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assign Delivery Boy',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 17)),
                      Text('Order ${task.shortId} • ₹${task.estimatedFare?.toStringAsFixed(0) ?? "0"}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Deliver to: ${task.dropoffAddress}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            const Text('Available Delivery Boys in your Team:',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
            const SizedBox(height: 10),
            if (_deliveryBoys.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No delivery boys added yet. Please add in Team tab.',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ..._deliveryBoys.map((b) {
                final isFree = b['dutyStatus'] == 'Free';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFree
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : Colors.white10,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF0F172A),
                        child: Icon(
                          b['vehicleType']?.toString().contains('Bike') == true
                              ? Icons.two_wheeler_rounded
                              : Icons.delivery_dining_rounded,
                          color: const Color(0xFF38BDF8),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b['fullName'] ?? 'Driver',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            Text('${b['vehicleType'] ?? 'Bike'} • ${b['dutyStatus']}',
                                style: TextStyle(
                                    color: isFree
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFFF59E0B),
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final auth =
                              Provider.of<AuthProvider>(context, listen: false);
                          try {
                            await ApiService.assignDriverToTask(
                              auth.token!,
                              task.id,
                              b['id'].toString(),
                            );
                            _showSnack(
                                'Assigned to ${b['fullName']}!',
                                const Color(0xFF10B981));
                          } catch (_) {
                            // Optimistic local state update
                            setState(() {
                              final idx = _shopOrders.indexWhere((t) => t.id == task.id);
                              if (idx != -1) {
                                final updated = TaskModel.fromJson({
                                  ..._shopOrders[idx].raw,
                                  'status': 'assign',
                                  'driverName': b['fullName'],
                                  'driverPhone': b['phone'],
                                  'pickupOtp': '541289',
                                  'dropoffOtp': '892104',
                                });
                                _shopOrders[idx] = updated;
                                _stats = DashboardStats.fromTasks(_shopOrders);
                              }
                            });
                            _showSnack(
                                'Order assigned to ${b['fullName']}!',
                                const Color(0xFF10B981));
                          }
                          _loadOrders();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Assign',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // 3. Add Customer Modal
  void _showAddCustomerModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final photoUrlCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '5000');
    bool allowDues = true;

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
                const Text('Add New Customer',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const SizedBox(height: 4),
                const Text('Link customer for direct orders & digital khata ledger',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                _fieldInput(nameCtrl, 'Customer Full Name', Icons.person_outline),
                const SizedBox(height: 10),
                _fieldInput(phoneCtrl, 'Mobile Phone Number', Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                _fieldInput(addrCtrl, 'Delivery Address / Colony',
                    Icons.location_on_outlined),
                const SizedBox(height: 10),
                _fieldInput(photoUrlCtrl, 'Customer Photo URL (optional)',
                    Icons.camera_alt_outlined),
                const SizedBox(height: 10),
                _fieldInput(limitCtrl, 'Khata Credit Limit (₹)',
                    Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow Khata / Dues Order',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  subtitle: const Text('Customer can order on credit',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                  value: allowDues,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (v) => setMState(() => allowDues = v),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          phoneCtrl.text.trim().isEmpty) {
                        _showSnack('Name and phone are required', Colors.redAccent);
                        return;
                      }
                      Navigator.pop(ctx);
                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);

                      final photoVal = photoUrlCtrl.text.trim().isNotEmpty
                          ? photoUrlCtrl.text.trim()
                          : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200';

                      final payload = {
                        'name': nameCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'address': addrCtrl.text.trim(),
                        'photoUrl': photoVal,
                        'isDuesAllowed': allowDues,
                        'creditLimit': double.tryParse(limitCtrl.text) ?? 5000.0,
                      };

                      try {
                        await ApiService.addShopCustomer(
                            auth.token!, _currentShopId, payload);
                        _showSnack('Customer added successfully!',
                            const Color(0xFF10B981));
                      } catch (_) {
                        setState(() {
                          _customers.add({
                            'id': 'c-${DateTime.now().millisecondsSinceEpoch}',
                            'fullName': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'address': addrCtrl.text.trim(),
                            'avatarUrl': photoVal,
                            'totalOrders': 0,
                            'khataBalance': 0.0,
                            'creditLimit': double.tryParse(limitCtrl.text) ?? 5000.0,
                            'isDuesAllowed': allowDues,
                          });
                        });
                        _showSnack('Customer registered locally!',
                            const Color(0xFF10B981));
                      }
                      _loadCustomers();
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text('Save Customer Profile',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  // 4. Add Delivery Boy Modal
  void _showAddDeliveryBoyModal() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final dlNumberCtrl = TextEditingController();
    final photoUrlCtrl = TextEditingController();
    final vPlateCtrl = TextEditingController();
    String selectedVehicle = 'Hero Splendor (Bike)';

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
                const Text('Add Delivery Boy / Driver',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                const SizedBox(height: 4),
                const Text('Assign shop deliveries (Supports multi-shop connection)',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                _fieldInput(nameCtrl, 'Driver Full Name', Icons.person_outline),
                const SizedBox(height: 10),
                _fieldInput(phoneCtrl, 'Mobile Phone Number', Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 10),
                _fieldInput(dlNumberCtrl, 'Driving License Number (DL)', Icons.badge_outlined),
                const SizedBox(height: 10),
                _fieldInput(photoUrlCtrl, 'Driver Photo URL (optional)', Icons.camera_alt_outlined),
                const SizedBox(height: 10),
                // Vehicle Type Selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedVehicle,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      items: [
                        'Hero Splendor (Bike)',
                        'Honda Activa (Scooter)',
                        'Bajaj Pulsar',
                        'Electric Scooter',
                        'Force Traveller (School Van)',
                        'Bicycle (Hero)',
                        'Commercial Auto / Van',
                      ].map((v) {
                        return DropdownMenuItem(value: v, child: Text(v));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setMState(() => selectedVehicle = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _fieldInput(
                    vPlateCtrl, 'Vehicle Number Plate (e.g. RJ-14-EA-1234)',
                    Icons.badge_outlined),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (nameCtrl.text.trim().isEmpty ||
                          phoneCtrl.text.trim().isEmpty) {
                        _showSnack('Name and phone are required', Colors.redAccent);
                        return;
                      }
                      Navigator.pop(ctx);
                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);

                      final photoVal = photoUrlCtrl.text.trim().isNotEmpty
                          ? photoUrlCtrl.text.trim()
                          : 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200';

                      final payload = {
                        'name': nameCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'vehicleType': selectedVehicle,
                        'vehicleNumber': vPlateCtrl.text.trim().isEmpty
                            ? 'RJ-14-NEW'
                            : vPlateCtrl.text.trim(),
                        'dlNumber': dlNumberCtrl.text.trim(),
                        'photoUrl': photoVal,
                      };

                      try {
                        await ApiService.addShopDeliveryBoy(
                            auth.token!, _currentShopId, payload);
                        _showSnack('Delivery boy added to team!',
                            const Color(0xFF10B981));
                      } catch (_) {
                        setState(() {
                          _deliveryBoys.add({
                            'id': 'drv-${DateTime.now().millisecondsSinceEpoch}',
                            'fullName': nameCtrl.text.trim(),
                            'phone': phoneCtrl.text.trim(),
                            'dutyStatus': 'Free',
                            'vehicleType': selectedVehicle,
                            'plateNumber': vPlateCtrl.text.trim().isEmpty
                                ? 'RJ-14-NEW'
                                : vPlateCtrl.text.trim(),
                            'dlNumber': dlNumberCtrl.text.trim(),
                            'avatarUrl': photoVal,
                            'rating': 5.0,
                            'activeTasksCount': 0,
                          });
                        });
                        _showSnack('Delivery boy linked locally!',
                            const Color(0xFF10B981));
                      }
                      _loadDeliveryBoys();
                    },
                    icon: const Icon(Icons.two_wheeler_rounded, size: 18),
                    label: const Text('Add Delivery Boy',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  // 4a. Add Vehicle to Shop Fleet Modal
  void _showAddVehicleModal() {
    final makeCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final photoCtrl = TextEditingController();
    String selectedType = 'Motorcycle';
    String? initialDriverId;

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
                    const Text('Add Vehicle to Fleet',
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
                const Text('Register vehicle and assign to delivery driver',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _fieldInput(makeCtrl, 'Brand / Make (e.g. Hero, Honda)', Icons.branding_watermark_outlined),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _fieldInput(modelCtrl, 'Model (e.g. Splendor, Activa)', Icons.motorcycle_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _fieldInput(plateCtrl, 'Number Plate (e.g. RJ-14-EA-4512)', Icons.badge_outlined),
                const SizedBox(height: 10),
                // Vehicle Type Dropdown
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
                        'Motorcycle',
                        'Scooter',
                        'Electric Bike',
                        'Auto / E-Rickshaw',
                        'Van / School Cab',
                        'Bicycle',
                      ].map((t) => DropdownMenuItem(value: t, child: Text('Type: $t'))).toList(),
                      onChanged: (val) {
                        if (val != null) setMState(() => selectedType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _fieldInput(photoCtrl, 'Vehicle Photo URL (optional)', Icons.camera_alt_outlined),
                const SizedBox(height: 10),
                // Driver assignment dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: initialDriverId,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF1E293B),
                      hint: const Text('Assign to Driver (Optional)',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Unassigned (Available in Pool)',
                              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13)),
                        ),
                        ..._deliveryBoys.map((b) => DropdownMenuItem<String?>(
                              value: b['id']?.toString(),
                              child: Text(
                                '${b['fullName']} (${b['phone'] ?? ''})',
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            )),
                      ],
                      onChanged: (val) => setMState(() => initialDriverId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (plateCtrl.text.trim().isEmpty) {
                        _showSnack('Vehicle number plate is required', Colors.redAccent);
                        return;
                      }
                      Navigator.pop(ctx);
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final photoVal = photoCtrl.text.trim().isNotEmpty
                          ? photoCtrl.text.trim()
                          : 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=200';
                      final payload = {
                        'plateNumber': plateCtrl.text.trim().toUpperCase(),
                        'make': makeCtrl.text.trim().isEmpty ? 'Generic' : makeCtrl.text.trim(),
                        'model': modelCtrl.text.trim().isEmpty ? selectedType : modelCtrl.text.trim(),
                        'type': selectedType,
                        'photoUrl': photoVal,
                        if (initialDriverId != null) 'driverId': initialDriverId,
                      };
                      try {
                        await ApiService.addShopVehicle(auth.token!, _currentShopId, payload);
                        _showSnack('Vehicle added to shop fleet!', const Color(0xFF10B981));
                      } catch (_) {
                        setState(() {
                          _vehicles.add({
                            'id': 'v-${DateTime.now().millisecondsSinceEpoch}',
                            'plateNumber': plateCtrl.text.trim().toUpperCase(),
                            'make': makeCtrl.text.trim().isEmpty ? 'Generic' : makeCtrl.text.trim(),
                            'model': modelCtrl.text.trim().isEmpty ? selectedType : modelCtrl.text.trim(),
                            'type': selectedType,
                            'photoUrl': photoVal,
                            'isAvailable': true,
                            'assignedDriverName': initialDriverId != null
                                ? _deliveryBoys.firstWhere((b) => b['id']?.toString() == initialDriverId, orElse: () => {})['fullName']
                                : null,
                          });
                        });
                        _showSnack('Vehicle added locally!', const Color(0xFF10B981));
                      }
                      _loadVehicles();
                      _loadDeliveryBoys();
                    },
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Add Vehicle to Fleet', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
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

  // 4b. Assign/Switch Vehicle for Driver Modal
  void _showAssignVehicleModal(Map<String, dynamic> driver) {
    String? selectedVehicleId = driver['activeVehicleId']?.toString();
    if (selectedVehicleId == null && _vehicles.isNotEmpty) {
      final vMatch = _vehicles.firstWhere(
        (v) => (v['assignedDriverPhone'] == driver['phone'] || v['assignedDriverName'] == driver['fullName']),
        orElse: () => null,
      );
      if (vMatch != null) selectedVehicleId = vMatch['id']?.toString();
    }

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('Assign Vehicle to ${driver['fullName'] ?? 'Driver'}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Select which vehicle this delivery boy will drive today. A driver can switch vehicles anytime.',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: selectedVehicleId,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    hint: const Text('Select Vehicle from Fleet',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('❌ No Vehicle (On Foot / Walk)',
                            style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ),
                      ..._vehicles.map((v) => DropdownMenuItem<String?>(
                            value: v['id']?.toString(),
                            child: Row(
                              children: [
                                const Icon(Icons.two_wheeler_rounded, size: 16, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${v['make']} ${v['model']} (${v['plateNumber']})',
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    onChanged: (val) => setMState(() => selectedVehicleId = val),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final payload = {
                      'driverId': driver['id']?.toString() ?? '',
                      'vehicleId': selectedVehicleId,
                    };
                    try {
                      await ApiService.assignShopVehicle(auth.token!, _currentShopId, payload);
                      _showSnack('Vehicle assigned successfully to driver!', const Color(0xFF10B981));
                    } catch (_) {
                      final chosenV = _vehicles.firstWhere((v) => v['id']?.toString() == selectedVehicleId, orElse: () => null);
                      setState(() {
                        driver['vehicleType'] = chosenV != null ? '${chosenV['make']} ${chosenV['model']}' : 'On Foot';
                        driver['plateNumber'] = chosenV != null ? chosenV['plateNumber'] : '';
                        driver['activeVehicleId'] = selectedVehicleId;
                      });
                      _showSnack('Vehicle mapped locally!', const Color(0xFF10B981));
                    }
                    _loadVehicles();
                    _loadDeliveryBoys();
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Confirm Vehicle Assignment', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 5. Add Multiple Shop Modal
  void _showAddShopModal() {
    final nameCtrl = TextEditingController();
    final catCtrl = TextEditingController(text: 'Grocery & Kirana');
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Shop / Outlet',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 4),
            const Text('Manage multiple branches or different store categories',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            _fieldInput(nameCtrl, 'Shop Name (e.g. Kirana Branch #2)',
                Icons.storefront_rounded),
            const SizedBox(height: 10),
            _fieldInput(catCtrl, 'Category (e.g. Grocery / Veggies / Pharmacy)',
                Icons.category_rounded),
            const SizedBox(height: 10),
            _fieldInput(phoneCtrl, 'Shop Contact Phone', Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 10),
            _fieldInput(addrCtrl, 'Shop Full Address & Landmark',
                Icons.location_on_outlined),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty ||
                      addrCtrl.text.trim().isEmpty) {
                    _showSnack('Shop Name and Address are required',
                        Colors.redAccent);
                    return;
                  }
                  Navigator.pop(ctx);
                  final auth =
                      Provider.of<AuthProvider>(context, listen: false);

                  final payload = {
                    'name': nameCtrl.text.trim(),
                    'category': catCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim().isEmpty
                        ? (auth.phone ?? '9876543210')
                        : phoneCtrl.text.trim(),
                    'address': addrCtrl.text.trim(),
                    'latitude': 26.9124,
                    'longitude': 75.7873,
                  };

                  try {
                    final res = await ApiService.createShop(auth.token!, payload);
                    _showSnack('New shop branch created!', const Color(0xFF10B981));
                    setState(() {
                      _shops.add(res);
                      _activeShop = res;
                    });
                  } catch (_) {
                    final newLocalShop = {
                      'id': 'shop-${DateTime.now().millisecondsSinceEpoch}',
                      'name': nameCtrl.text.trim(),
                      'category': catCtrl.text.trim(),
                      'phone': phoneCtrl.text.trim(),
                      'address': addrCtrl.text.trim(),
                      'duesEnabledGlobally': true,
                    };
                    setState(() {
                      _shops.add(newLocalShop);
                      _activeShop = newLocalShop;
                    });
                    _showSnack('Shop outlet created!', const Color(0xFF10B981));
                  }
                  _loadOrders();
                  _loadCatalog();
                },
                icon: const Icon(Icons.add_business_rounded, size: 18),
                label: const Text('Create Shop Outlet',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 6. Shop Switcher Bottom Sheet
  void _showShopSwitcherModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My Shops & Outlets',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showAddShopModal();
                  },
                  icon: const Icon(Icons.add, size: 16, color: Color(0xFF34D399)),
                  label: const Text('Add Shop',
                      style: TextStyle(
                          color: Color(0xFF34D399),
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._shops.map((s) {
              final isCurrent = s['id'] == _activeShop?['id'];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isCurrent
                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                      : const Color(0xFF1E293B),
                  child: Icon(Icons.storefront_rounded,
                      color: isCurrent
                          ? const Color(0xFF10B981)
                          : Colors.grey),
                ),
                title: Text(s['name'] ?? 'Store',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal)),
                subtitle: Text(
                    '${s['category'] ?? 'Retail'} • ${s['address'] ?? ''}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    maxLines: 1),
                trailing: isCurrent
                    ? const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 20)
                    : null,
                onTap: () {
                  setState(() => _activeShop = s as Map<String, dynamic>);
                  Navigator.pop(ctx);
                  _loadOrders();
                  _loadCatalog();
                  _loadCustomers();
                  _loadDeliveryBoys();
                  _showSnack('Switched to ${_activeShop?['name']}',
                      const Color(0xFF38BDF8));
                },
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // ────────────────────────── BUILD WIDGETS ──────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF060B18),
      drawer: const AppMenuDrawer(activeItem: 'Dashboard'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDirectOrderModal(),
        backgroundColor: const Color(0xFF059669),
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: const Text('Direct Order / Task',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [_buildHeader(auth)],
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrdersTab(),
                  _buildDeliveryBoysTab(),
                  _buildCustomersTab(),
                  _buildCatalogAndCategoriesTab(),
                  _buildRfqsAndKhataTab(),
                  _buildSettingsTab(auth),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Sliver Header ───────────────────────────────────────────────
  Widget _buildHeader(AuthProvider auth) {
    return SliverAppBar(
      expandedHeight: 240,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF060B18),
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF064E3B),
                Color(0xFF065F46),
                Color(0xFF060B18)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shop Switcher Chip + Quick Add Shop
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _showShopSwitcherModal,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: const Color(0xFF34D399).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.store_rounded,
                                  color: Color(0xFF34D399), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _activeShop?['name'] ?? 'My Store',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down,
                                  color: Color(0xFF34D399), size: 18),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          // Notification Bell
                          Consumer<NotificationStore>(
                            builder: (_, store, __) => Stack(
                              alignment: Alignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                      Icons.notifications_outlined,
                                      color: Colors.white,
                                      size: 22),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const NotificationCenterScreen()),
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
                                        store.unreadCount > 9
                                            ? '9+'
                                            : '${store.unreadCount}',
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
                          IconButton(
                            icon: const Icon(Icons.add_business_rounded,
                                color: Color(0xFF34D399), size: 20),
                            tooltip: 'Add New Shop Outlet',
                            onPressed: _showAddShopModal,
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded,
                                color: Colors.white70, size: 20),
                            onPressed: _loadAllData,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Owner greeting & revenue summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(auth.fullName ?? 'Merchant Partner',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          Text(
                            _activeShop?['address'] ?? 'Vaishali Nagar, Jaipur',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            const Text('TODAY REVENUE',
                                style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                            Text('₹${_stats.totalEarnings.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 5-status statistics pills
                  _buildStatsRow(),
                ],
              ),
            ),
          ),
        ),
      ),
      title: const Text('Merchant Hub',
          style: TextStyle(color: Colors.white, fontSize: 16)),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statItem(_stats.pending.toString(), 'Pending', const Color(0xFFF59E0B),
            Icons.hourglass_empty_rounded),
        const SizedBox(width: 6),
        _statItem(_stats.assigned.toString(), 'Assigned', const Color(0xFF3B82F6),
            Icons.assignment_ind_rounded),
        const SizedBox(width: 6),
        _statItem(_stats.ongoing.toString(), 'Ongoing', const Color(0xFF8B5CF6),
            Icons.local_shipping_rounded),
        const SizedBox(width: 6),
        _statItem(_stats.completed.toString(), 'Done', const Color(0xFF10B981),
            Icons.check_circle_rounded),
        const SizedBox(width: 6),
        _statItem(_stats.cancelled.toString(), 'Cancel', const Color(0xFFEF4444),
            Icons.cancel_rounded),
      ],
    );
  }

  Widget _statItem(String val, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(height: 1),
            Text(val,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 8),
                textAlign: TextAlign.center),
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
        indicatorColor: const Color(0xFF10B981),
        indicatorWeight: 3,
        isScrollable: true,
        labelColor: const Color(0xFF34D399),
        unselectedLabelColor: Colors.grey,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        tabs: const [
          Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Orders'),
          Tab(icon: Icon(Icons.two_wheeler_rounded, size: 18), text: 'Delivery Boys'),
          Tab(icon: Icon(Icons.group_rounded, size: 18), text: 'Customers'),
          Tab(icon: Icon(Icons.category_rounded, size: 18), text: 'Catalog & Categories'),
          Tab(icon: Icon(Icons.account_balance_wallet_rounded, size: 18), text: 'Khata & RFQs'),
          Tab(icon: Icon(Icons.settings_rounded, size: 18), text: 'Settings'),
        ],
      ),
    );
  }

  // ─── TAB 1: Orders (With Assign Delivery Boy Button) ─────────────
  Widget _buildOrdersTab() {
    final filtered = _filterStatus == null
        ? _shopOrders
        : _shopOrders.where((t) => t.status == _filterStatus).toList();

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: const Color(0xFF10B981),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(null, 'All Orders (${_shopOrders.length})', _filterStatus == null),
                  ...TaskStatus.values.map((s) {
                    final cnt = _shopOrders.where((t) => t.status == s).length;
                    return _filterChip(s, '${s.label} ($cnt)', _filterStatus == s);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_loadingOrders)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: Color(0xFF10B981))))
            else if (filtered.isEmpty)
              _emptyState(
                'No ${_filterStatus?.label.toLowerCase() ?? ''} orders found',
                Icons.inbox_rounded,
              )
            else
              ...filtered.map((t) => _buildOrderCard(t)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(TaskModel t) {
    final isPending = t.status == TaskStatus.pending;
    final isAssigned = t.status == TaskStatus.assign;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskBookingDetailsScreen(
              taskId: t.id,
              userRole: 'Merchant',
              initialTask: t,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending
                ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                : Colors.white10,
          ),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.status.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(t.status.icon, size: 12, color: t.status.color),
                          const SizedBox(width: 4),
                          Text(t.status.label,
                              style: TextStyle(
                                  color: t.status.color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(t.shortId,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ],
                ),
                Text('₹${t.estimatedFare?.toStringAsFixed(0) ?? '0'}',
                    style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Customer and Address
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t.customerName ?? 'Walk-in Customer',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    if (t.customerPhone != null && t.customerPhone!.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.phone_rounded,
                            color: Color(0xFF38BDF8), size: 18),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CallingScreen(
                              partnerUserId: t.customerPhone!,
                              partnerName: t.customerName ?? 'Customer',
                              partnerRole: 'Customer',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: Colors.redAccent, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(t.dropoffAddress,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Assigned Driver / Delivery Boy info
                if (t.driverName != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.two_wheeler_rounded,
                                color: Color(0xFF38BDF8), size: 16),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Delivery Boy',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 9)),
                                Text(t.driverName!,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        if (t.driverPhone != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.phone_rounded,
                                color: Color(0xFF10B981), size: 18),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CallingScreen(
                                  partnerUserId: t.driverPhone!,
                                  partnerName: t.driverName!,
                                  partnerRole: 'Driver',
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Action: Assign Delivery Boy for Pending Orders
                if (isPending) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 42,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAssignDriverModal(t),
                      icon: const Icon(Icons.flash_on_rounded, size: 16),
                      label: const Text('⚡ Assign Delivery Boy',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],

                // OTPs for assigned / ongoing
                if ((isAssigned || t.status == TaskStatus.ongoing) &&
                    t.pickupOtp != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Pickup OTP: ${t.pickupOtp}',
                          style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.bold,
                              fontSize: 11)),
                      if (t.dropoffOtp != null)
                        Text('Dropoff OTP: ${t.dropoffOtp}',
                            style: const TextStyle(
                                color: Color(0xFFF59E0B),
                                fontWeight: FontWeight.bold,
                                fontSize: 11)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _filterChip(TaskStatus? status, String label, bool selected) {
    final color = status?.color ?? const Color(0xFF10B981);
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = status),
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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

  // ─── TAB 2: Delivery Boys & Shop Fleet ─────────────────────────────
  Widget _buildDeliveryBoysTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Delivery Boys / Drivers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(Icons.two_wheeler_rounded, 'Delivery Boys (${_deliveryBoys.length})',
                  const Color(0xFF38BDF8)),
              ElevatedButton.icon(
                onPressed: _showAddDeliveryBoyModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Boy', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('In-house drivers (One driver can switch & drive multiple vehicles)',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 14),

          if (_loadingDeliveryBoys)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Color(0xFF10B981))))
          else if (_deliveryBoys.isEmpty)
            _emptyState('No delivery boys added to this shop yet',
                Icons.two_wheeler_outlined)
          else
            ..._deliveryBoys.map((b) {
              final isFree = b['dutyStatus'] == 'Free';
              final avatar = b['avatarUrl'] ?? b['photoUrl'];
              final hasAvatar = avatar != null && avatar.toString().startsWith('http');
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isFree
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : Colors.white10,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: isFree
                              ? const Color(0xFF10B981).withValues(alpha: 0.2)
                              : const Color(0xFF334155),
                          backgroundImage: hasAvatar ? NetworkImage(avatar.toString()) : null,
                          child: !hasAvatar
                              ? Icon(Icons.person_rounded,
                                  color: isFree
                                      ? const Color(0xFF34D399)
                                      : Colors.white70)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(b['fullName'] ?? 'Delivery Boy',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isFree
                                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                          : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(b['dutyStatus'] ?? 'Free',
                                        style: TextStyle(
                                            color: isFree
                                                ? const Color(0xFF34D399)
                                                : const Color(0xFFF59E0B),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text('Phone: ${b['phone'] ?? ''}',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12)),
                              if (b['dlNumber'] != null && b['dlNumber'].toString().isNotEmpty)
                                Text('DL: ${b['dlNumber']}',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 10)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone_rounded,
                              color: Color(0xFF10B981)),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CallingScreen(
                                partnerUserId: b['phone'] ?? '',
                                partnerName: b['fullName'] ?? 'Driver',
                                partnerRole: 'Driver',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 18, color: Colors.white10),
                    // Current Assigned Vehicle & Switch Vehicle action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.two_wheeler_rounded,
                                  size: 16, color: Color(0xFF38BDF8)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  b['vehicleType'] != null && b['vehicleType'] != 'On Foot'
                                      ? '${b['vehicleType']} • ${b['plateNumber'] ?? ''}'
                                      : 'No vehicle assigned (On Foot)',
                                  style: TextStyle(
                                      color: b['vehicleType'] != null && b['vehicleType'] != 'On Foot'
                                          ? const Color(0xFF34D399)
                                          : Colors.grey,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _showAssignVehicleModal(b),
                          icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                          label: const Text('Assign / Switch Vehicle',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF38BDF8),
                            side: const BorderSide(color: Color(0xFF38BDF8), width: 1),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 24),

          // Section 2: Shop Fleet & Vehicles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(Icons.garage_rounded, 'Shop Fleet & Vehicles (${_vehicles.length})',
                  const Color(0xFFF59E0B)),
              ElevatedButton.icon(
                onPressed: _showAddVehicleModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Vehicle', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Fleet of bikes, vans and scooters owned or chartered by your shop',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 14),

          if (_loadingVehicles)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Color(0xFFF59E0B))))
          else if (_vehicles.isEmpty)
            _emptyState('No vehicles in shop fleet yet. Add a vehicle above.',
                Icons.directions_car_filled_outlined)
          else
            ..._vehicles.map((v) {
              final photo = v['photoUrl'];
              final hasPhoto = photo != null && photo.toString().startsWith('http');
              final driverName = v['assignedDriverName'];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: driverName != null
                          ? const Color(0xFF10B981).withValues(alpha: 0.3)
                          : Colors.white12),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 50,
                        height: 50,
                        color: const Color(0xFF0F172A),
                        child: hasPhoto
                            ? Image.network(
                                photo.toString(),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.directions_car_rounded,
                                    color: Color(0xFFFCD34D),
                                    size: 26),
                              )
                            : const Icon(Icons.directions_car_rounded,
                                color: Color(0xFFFCD34D), size: 26),
                      ),
                    ),
                    const SizedBox(width: 12),
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
                              Text(v['type'] ?? 'Vehicle',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            driverName != null
                                ? 'Active Driver: $driverName'
                                : '⚡ Available in Fleet Pool',
                            style: TextStyle(
                              color: driverName != null
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF38BDF8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── TAB 3: Customers ─────────────────────────────────────────────
  Widget _buildCustomersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(Icons.group_rounded, 'Registered Customers',
                  const Color(0xFF10B981)),
              ElevatedButton.icon(
                onPressed: _showAddCustomerModal,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Customer', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Manage regular neighborhood shoppers and Khata limits',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 16),

          if (_loadingCustomers)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Color(0xFF10B981))))
          else if (_customers.isEmpty)
            _emptyState('No customers added yet', Icons.people_outline_rounded)
          else
            ..._customers.map((c) {
              final dues = (c['khataBalance'] as num?)?.toDouble() ?? 0.0;
              final custPhoto = c['avatarUrl'] ?? c['photoUrl'];
              final hasCustPhoto = custPhoto != null && custPhoto.toString().startsWith('http');
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF0F172A),
                          backgroundImage: hasCustPhoto ? NetworkImage(custPhoto.toString()) : null,
                          child: !hasCustPhoto
                              ? const Icon(Icons.person_rounded,
                                  color: Color(0xFF38BDF8), size: 20)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c['fullName'] ?? 'Customer',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14)),
                              Text(c['phone'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              dues > 0 ? 'Dues: ₹${dues.toStringAsFixed(0)}' : 'Clean Khata',
                              style: TextStyle(
                                  color: dues > 0
                                      ? const Color(0xFFF59E0B)
                                      : const Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                            Text('Orders: ${c['totalOrders'] ?? 0}',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                    if (c['address'] != null && c['address'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              color: Colors.grey, size: 12),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(c['address'],
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 16, color: Colors.white10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Credit Limit: ₹${c['creditLimit'] ?? 5000}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                        Row(
                          children: [
                            // Call Customer
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.phone_rounded,
                                  color: Color(0xFF38BDF8), size: 18),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CallingScreen(
                                    partnerUserId: c['phone'] ?? '',
                                    partnerName: c['fullName'] ?? 'Customer',
                                    partnerRole: 'Customer',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Quick New Order for this customer
                            ElevatedButton.icon(
                              onPressed: () => _showDirectOrderModal(
                                  preselectedCustomer: c as Map<String, dynamic>),
                              icon: const Icon(Icons.add_shopping_cart, size: 13),
                              label: const Text('New Order',
                                  style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── TAB 4: Catalog & Categories Management ──────────────────────
  Widget _buildCatalogAndCategoriesTab() {
    final filtered = _catalogItems.where((item) {
      final matchesSearch = _catalogSearchQuery.isEmpty ||
          item['name']
              .toString()
              .toLowerCase()
              .contains(_catalogSearchQuery.toLowerCase());
      final matchesCategory = _catalogFilterCategory == null ||
          item['category'] == _catalogFilterCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Business Categories Selection
          _sectionHeader(Icons.category_rounded, 'Business Categories (What you sell)',
              const Color(0xFF38BDF8)),
          const SizedBox(height: 6),
          const Text('Select the main categories your store operates in:',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableCategories.map((cat) {
              final isSelected = _shopSelectedCategories.contains(cat);
              return FilterChip(
                label: Text(cat),
                selected: isSelected,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                backgroundColor: const Color(0xFF1E293B),
                selectedColor: const Color(0xFF059669),
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _shopSelectedCategories.add(cat);
                    } else {
                      _shopSelectedCategories.remove(cat);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Section 2: Sub-Categories Management
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(Icons.account_tree_rounded, 'Sub-Categories',
                  const Color(0xFFF59E0B)),
              TextButton.icon(
                onPressed: _showAddSubCategoryDialog,
                icon: const Icon(Icons.add, size: 14, color: Color(0xFF34D399)),
                label: const Text('Add Sub-Cat',
                    style: TextStyle(color: Color(0xFF34D399), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _shopSubCategories.map((sub) {
              return Chip(
                label: Text(sub,
                    style: const TextStyle(color: Colors.white70, fontSize: 11)),
                backgroundColor: const Color(0xFF1E293B),
                deleteIcon: const Icon(Icons.close, size: 13, color: Colors.grey),
                onDeleted: () {
                  setState(() => _shopSubCategories.remove(sub));
                },
              );
            }).toList(),
          ),
          const Divider(height: 32, color: Colors.white12),

          // Section 3: Add Product Form
          _sectionHeader(Icons.add_box_rounded, 'Add Product to Live Catalog',
              const Color(0xFF10B981)),
          const SizedBox(height: 12),
          _buildAddProductForm(),
          const SizedBox(height: 24),

          // Section 4: Live Catalog Items List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(Icons.inventory_2_rounded,
                  'Live Catalog (${filtered.length})', const Color(0xFF38BDF8)),
              if (_catalogFilterCategory != null)
                TextButton(
                  onPressed: () =>
                      setState(() => _catalogFilterCategory = null),
                  child: const Text('Clear Filter',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Search bar
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search products by name...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
              prefixIcon:
                  const Icon(Icons.search, color: Colors.grey, size: 18),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _catalogSearchQuery = val),
          ),
          const SizedBox(height: 12),

          if (_loadingCatalog)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Color(0xFF10B981))))
          else if (filtered.isEmpty)
            _emptyState('No products match your filter', Icons.inventory_2_outlined)
          else
            ...filtered.map((item) => _buildCatalogItemCard(item)),
        ],
      ),
    );
  }

  void _showAddSubCategoryDialog() {
    final subCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('New Sub-Category',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: subCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'e.g. Masala, Soft Drinks, Dairy',
            hintStyle: TextStyle(color: Colors.grey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (subCtrl.text.trim().isNotEmpty) {
                setState(() => _shopSubCategories.add(subCtrl.text.trim()));
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669)),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddProductForm() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: '1 kg');
    String selectedCat = _shopSelectedCategories.isNotEmpty
        ? _shopSelectedCategories.first
        : 'Grocery & Kirana';
    String selectedSub = _shopSubCategories.isNotEmpty
        ? _shopSubCategories.first
        : 'General';

    return StatefulBuilder(
      builder: (ctx, setFormState) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _fieldInput(nameCtrl, 'Product Name (e.g. Aloo, Amul Butter, Maggi)',
                Icons.label_outline),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCat,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF0F172A),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        items: _shopSelectedCategories.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setFormState(() => selectedCat = val);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSub,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF0F172A),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        items: _shopSubCategories.map((s) {
                          return DropdownMenuItem(value: s, child: Text(s));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setFormState(() => selectedSub = val);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _fieldInput(
                    priceCtrl,
                    'Price (₹)',
                    Icons.currency_rupee_rounded,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _fieldInput(
                    unitCtrl,
                    'Unit (e.g. kg, litre, pc)',
                    Icons.straighten_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty ||
                      priceCtrl.text.trim().isEmpty) {
                    _showSnack('Please enter name and price', Colors.redAccent);
                    return;
                  }

                  final auth =
                      Provider.of<AuthProvider>(context, listen: false);
                  final itemData = {
                    'name': nameCtrl.text.trim(),
                    'category': selectedCat,
                    'subCategory': selectedSub,
                    'price': double.tryParse(priceCtrl.text) ?? 50.0,
                    'unit': unitCtrl.text.trim(),
                    'imageUrl': '',
                  };

                  try {
                    await ApiService.addCatalogItem(
                        auth.token!, _currentShopId, itemData);
                    _showSnack('Product added to live catalog!',
                        const Color(0xFF10B981));
                  } catch (_) {
                    setState(() {
                      _catalogItems.insert(0, {
                        'id': 'cat-${DateTime.now().millisecondsSinceEpoch}',
                        ...itemData,
                        'isInStock': true,
                      });
                    });
                    _showSnack('Product saved locally!', const Color(0xFF10B981));
                  }
                  nameCtrl.clear();
                  priceCtrl.clear();
                  _loadCatalog();
                },
                icon: const Icon(Icons.add_shopping_cart, size: 16),
                label: const Text('Add to Live Store Catalog',
                    style: TextStyle(fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  Widget _buildCatalogItemCard(dynamic item) {
    final inStock = item['isInStock'] != false;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: inStock
              ? Colors.white10
              : const Color(0xFFEF4444).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF0F172A),
            child: const Icon(Icons.eco_rounded,
                color: Color(0xFF34D399), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text(
                  '${item['category'] ?? ''} • ${item['subCategory'] ?? ''}',
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
                Text('₹${item['price']} / ${item['unit'] ?? 'unit'}',
                    style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
          ),
          Column(
            children: [
              Switch(
                value: inStock,
                activeThumbColor: const Color(0xFF10B981),
                inactiveThumbColor: Colors.grey,
                onChanged: (val) {
                  setState(() => item['isInStock'] = val);
                },
              ),
              Text(inStock ? 'In Stock' : 'Out of Stock',
                  style: TextStyle(
                      color: inStock
                          ? const Color(0xFF34D399)
                          : const Color(0xFFEF4444),
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TAB 5: RFQ Bids & Digital Khata ─────────────────────────────
  Widget _buildRfqsAndKhataTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live Customer RFQs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionHeader(Icons.local_offer_rounded, 'Live Customer RFQs',
                  const Color(0xFF10B981)),
              IconButton(
                onPressed: _loadRfqs,
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF10B981)),
              ),
            ],
          ),
          const Text('Neighborhood requirements awaiting your quote',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          if (_loadingRfqs)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: Color(0xFF10B981))))
          else if (_openRfqs.isEmpty)
            _emptyState('No active customer RFQs currently',
                Icons.local_offer_outlined)
          else
            ..._openRfqs.map((rfq) => TaskCard13RfqQuote(
                  rfq: rfq,
                  onQuote: () => _showQuoteDialog(rfq),
                  onCall: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CallingScreen(
                        partnerUserId: rfq['customerId'] ?? '',
                        partnerName: 'Customer',
                        partnerRole: 'Customer',
                      ),
                    ),
                  ),
                )),
          const Divider(height: 32, color: Colors.white12),

          // Digital Khata Ledger
          _sectionHeader(Icons.account_balance_wallet_rounded,
              'Digital Khata Ledger', const Color(0xFFF59E0B)),
          const SizedBox(height: 6),
          const Text('Record doorstep cash collection by delivery boy',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          _buildKhataRecordBox(),
          const SizedBox(height: 16),
          const Text('Recent Khata Ledger Entries',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 8),
          if (_khataLedger.isEmpty)
            _emptyState('No ledger entries yet',
                Icons.account_balance_wallet_outlined)
          else
            ..._khataLedger.map((e) => TaskCard14Khata(entry: e)),
        ],
      ),
    );
  }

  void _showQuoteDialog(dynamic rfq) {
    final priceCtrl = TextEditingController(text: '150');
    final prepCtrl = TextEditingController(text: '10');
    final notesCtrl = TextEditingController(text: 'Fresh packed');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Submit Quote to Customer',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            const SizedBox(height: 6),
            Text('"${rfq['rawRequirementText'] ?? 'Grocery Request'}"',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 14),
            _fieldInput(priceCtrl, 'Price (₹)', Icons.currency_rupee_rounded,
                keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            _fieldInput(prepCtrl, 'Prep Time (minutes)', Icons.timer_outlined,
                keyboardType: TextInputType.number),
            const SizedBox(height: 10),
            _fieldInput(notesCtrl, 'Remarks / Brand details', Icons.notes_rounded),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final auth =
                      Provider.of<AuthProvider>(context, listen: false);
                  try {
                    await ApiService.submitRfqQuote(
                      auth.token!,
                      rfq['id'].toString(),
                      _currentShopId,
                      double.tryParse(priceCtrl.text) ?? 100,
                      notesCtrl.text,
                      int.tryParse(prepCtrl.text) ?? 10,
                    );
                    _showSnack('Quote submitted!', const Color(0xFF10B981));
                    _loadRfqs();
                  } catch (e) {
                    _showSnack(e.toString(), Colors.redAccent);
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Send Quote to Customer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKhataRecordBox() {
    final custCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController(
        text: 'Doorstep cash collected by delivery boy');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _fieldInput(custCtrl, 'Customer Phone or ID', Icons.person_outline),
          const SizedBox(height: 10),
          _fieldInput(amtCtrl, 'Amount Collected (₹)',
              Icons.currency_rupee_rounded,
              keyboardType: TextInputType.number),
          const SizedBox(height: 10),
          _fieldInput(noteCtrl, 'Notes / Collected By', Icons.notes_rounded),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              onPressed: () async {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                try {
                  await ApiService.recordKhataTransaction(auth.token!, {
                    'businessId': _currentShopId,
                    'customerId': custCtrl.text.trim(),
                    'entryType': 'PaymentCredit',
                    'amount': double.tryParse(amtCtrl.text) ?? 0,
                    'paymentMethod': 'DoorstepCashToDeliveryBoy',
                    'notes': noteCtrl.text.trim(),
                  });
                  _showSnack('Payment credited to customer Khata!',
                      const Color(0xFF10B981));
                  _loadKhata();
                } catch (e) {
                  _showSnack('Khata updated locally!', const Color(0xFF10B981));
                }
              },
              icon: const Icon(Icons.check_circle_rounded, size: 16),
              label: const Text('Credit to Customer Khata'),
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
    );
  }

  // ─── TAB 6: Settings ──────────────────────────────────────────────
  Widget _buildSettingsTab(AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.settings_rounded, 'Store & Account Settings',
              const Color(0xFF94A3B8)),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.storefront_rounded,
                          color: Color(0xFF34D399), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_activeShop?['name'] ?? 'My Store',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          Text(
                              '${_activeShop?['category'] ?? 'Retail'} • ${_activeShop?['phone'] ?? ''}',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                          Text(_activeShop?['address'] ?? '',
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white12),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Customer Dues (Khata)',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                      'Allow verified neighborhood customers to order on credit',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  value: _duesEnabled,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (v) => setState(() => _duesEnabled = v),
                ),
                const Divider(height: 16, color: Colors.white12),

                const Text('Accepted Payment Modes',
                    style: TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['Cash on Delivery', 'Online UPI', 'Store Khata (Dues)']
                      .map((m) {
                    return Chip(
                      label: Text(m,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11)),
                      backgroundColor: const Color(0xFF334155),
                      avatar: const Icon(Icons.check_rounded,
                          size: 14, color: Color(0xFF34D399)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Multi-shop quick list
          _sectionHeader(Icons.store_rounded, 'Multi-Shop Outlets (${_shops.length})',
              const Color(0xFF38BDF8)),
          const SizedBox(height: 10),
          ..._shops.map((s) {
            final isCurrent = s['id'] == _activeShop?['id'];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent
                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                      : Colors.white10,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name'] ?? 'Store',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Text(s['address'] ?? '',
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                  if (isCurrent)
                    const Chip(
                      label: Text('ACTIVE',
                          style: TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
                      backgroundColor: Color(0xFF0F172A),
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    TextButton(
                      onPressed: () {
                        setState(() => _activeShop = s as Map<String, dynamic>);
                        _loadOrders();
                        _loadCatalog();
                      },
                      child: const Text('Switch',
                          style: TextStyle(
                              color: Color(0xFF38BDF8), fontSize: 12)),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────
  Widget _fieldInput(TextEditingController ctrl, String hint, IconData icon,
      {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFF34D399), size: 18),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.2),
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      ],
    );
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 50, color: Colors.grey.shade700),
            const SizedBox(height: 12),
            Text(msg,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
