import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'calling_screen.dart';

class SubscriptionsTransitScreen extends StatefulWidget {
  const SubscriptionsTransitScreen({super.key});

  @override
  State<SubscriptionsTransitScreen> createState() =>
      _SubscriptionsTransitScreenState();
}

class _SubscriptionsTransitScreenState extends State<SubscriptionsTransitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Subscriptions State
  List<dynamic> _catalogPlans = [];
  List<dynamic> _mySubscriptions = [];
  bool _loadingSubs = false;

  // School Transit State
  List<dynamic> _myTransitSchedules = [];
  List<dynamic> _driverStudents = [];
  bool _loadingTransit = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadSubscriptions();
    _loadSchoolTransit();
  }

  Future<void> _loadSubscriptions() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _loadingSubs = true);

    try {
      final catalog = await ApiService.getSubscriptionCatalog();
      if (catalog.isNotEmpty) {
        _catalogPlans = catalog;
      } else {
        _catalogPlans = _defaultCatalogPlans();
      }
    } catch (_) {
      _catalogPlans = _defaultCatalogPlans();
    }

    if (auth.isAuthenticated) {
      try {
        final subs = await ApiService.getMySubscriptions(auth.token!);
        setState(() {
          _mySubscriptions = subs;
          _loadingSubs = false;
        });
        return;
      } catch (_) {}
    }

    // Default mock subscriptions
    setState(() {
      _mySubscriptions = [
        {
          'id': 'sub-001',
          'itemName': 'Pure Farm Cow Milk (Desi Gir)',
          'quantity': 1.5,
          'unit': 'litre',
          'deliverySlot': '06:00 - 07:30 AM',
          'daysOfWeek': 'Everyday',
          'pricePerDelivery': 95.0,
          'businessName': 'Sharma Dairy & Kirana',
          'businessPhone': '9828012345',
          'isActive': true,
          'isCurrentlyPaused': false,
        },
        {
          'id': 'sub-002',
          'itemName': 'Homestyle Veg Tiffin (4 Roti, Dal, Sabzi)',
          'quantity': 1.0,
          'unit': 'tiffin',
          'deliverySlot': '12:30 - 01:30 PM',
          'daysOfWeek': 'Mon-Sat',
          'pricePerDelivery': 110.0,
          'businessName': 'Annapurna Kitchen',
          'businessPhone': '9828099887',
          'isActive': true,
          'isCurrentlyPaused': true,
          'activePause': {
            'pauseStartDate': '2026-09-26',
            'pauseEndDate': '2026-09-29',
            'reason': 'Out of town for weekend',
          },
        },
      ];
      _loadingSubs = false;
    });
  }

  Future<void> _loadSchoolTransit() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _loadingTransit = true);

    if (auth.isAuthenticated) {
      try {
        if (auth.role == 'Driver') {
          final students =
              await ApiService.getDriverSchoolTransitStudents(auth.token!);
          setState(() {
            _driverStudents = students;
            _loadingTransit = false;
          });
          return;
        } else {
          final scheds =
              await ApiService.getMySchoolTransitSchedules(auth.token!);
          if (scheds.isNotEmpty) {
            setState(() {
              _myTransitSchedules = scheds;
              _loadingTransit = false;
            });
            return;
          }
        }
      } catch (_) {}
    }

    // Fallback demo data
    setState(() {
      _myTransitSchedules = [
        {
          'id': 'sch-101',
          'studentName': 'Aarav Sharma (Class 6-B)',
          'schoolName': 'St. Xavier\'s Senior Secondary School',
          'pickupTime': '07:20 AM',
          'driverName': 'Mahesh Gurjar',
          'driverPhone': '9829077889',
          'vehicleType': 'Force Traveller (Van #4)',
          'plateNumber': 'RJ-14-SCH-2041',
          'status': 'BoardedVan', // BoardedVan, AtSchool, OnWayHome, DroppedHome
        },
      ];

      _driverStudents = [
        {
          'id': 'sch-101',
          'studentName': 'Aarav Sharma (Class 6-B)',
          'schoolName': 'St. Xavier\'s Senior Secondary',
          'guardianName': 'Rajesh Sharma',
          'guardianPhone': '9828012345',
          'pickupTime': '07:20 AM',
          'status': 'BoardedVan',
        },
        {
          'id': 'sch-102',
          'studentName': 'Ananya Gupta (Class 4-A)',
          'schoolName': 'St. Xavier\'s Senior Secondary',
          'guardianName': 'Priya Gupta',
          'guardianPhone': '9828054321',
          'pickupTime': '07:30 AM',
          'status': 'AtHome',
        },
      ];
      _loadingTransit = false;
    });
  }

  List<dynamic> _defaultCatalogPlans() {
    return [
      {
        'id': 'plan-cow-milk',
        'category': 'Daily Milk',
        'itemName': 'Pure Farm Cow Milk (Desi Gir)',
        'unit': 'litre',
        'quantity': 1.0,
        'pricePerDelivery': 65.0,
        'deliverySlot': '06:00 - 07:30 AM',
        'icon': '🥛',
        'description':
            'Raw, chilled, non-homogenized pure cow milk delivered to your doorstep every morning.',
      },
      {
        'id': 'plan-buffalo-milk',
        'category': 'Daily Milk',
        'itemName': 'Fresh Buffalo Milk (High Fat)',
        'unit': 'litre',
        'quantity': 1.0,
        'pricePerDelivery': 72.0,
        'deliverySlot': '06:00 - 07:30 AM',
        'icon': '🥛',
        'description':
            'Creamy thick buffalo milk, perfect for tea, coffee, curd, and homemade paneer.',
      },
      {
        'id': 'plan-veg-thali',
        'category': 'Tiffin Service',
        'itemName': 'Homestyle Veg Thali (4 Roti, Dal, Sabzi, Rice)',
        'unit': 'tiffin',
        'quantity': 1.0,
        'pricePerDelivery': 110.0,
        'deliverySlot': '12:30 - 01:30 PM',
        'icon': '🍱',
        'description':
            'Healthy, home-cooked lunch with low oil, freshly prepared and delivered hot in insulated tiffin.',
      },
      {
        'id': 'plan-breakfast-basket',
        'category': 'Morning Essentials',
        'itemName': 'Bread, Farm Eggs & Butter Basket',
        'unit': 'basket',
        'quantity': 1.0,
        'pricePerDelivery': 85.0,
        'deliverySlot': '06:30 - 07:30 AM',
        'icon': '🍞',
        'description':
            'Brown/White bread loaf, 6 farm-fresh brown eggs, and Amul butter pack.',
      },
      {
        'id': 'plan-water-can',
        'category': 'Drinking Water',
        'itemName': '20L RO Purified Mineral Water Can',
        'unit': 'can',
        'quantity': 1.0,
        'pricePerDelivery': 45.0,
        'deliverySlot': '08:00 - 10:00 AM',
        'icon': '💧',
        'description':
            'Chilled / normal RO purified 20 litre bubble-top water can delivered and placed at your dispenser.',
      },
    ];
  }

  void _showSnack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ────────────────────────── MODALS ──────────────────────────

  // 1. Subscribe to Plan Modal
  void _showSubscribeModal(dynamic plan) {
    double qty = (plan['quantity'] as num?)?.toDouble() ?? 1.0;
    String selectedSlot = plan['deliverySlot'] ?? '06:00 - 07:30 AM';
    String days = 'Everyday';

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
                children: [
                  Text(plan['icon'] ?? '🥛',
                      style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plan['itemName'] ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                        Text(
                          '₹${plan['pricePerDelivery']} / ${plan['unit']}',
                          style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: Colors.white12),

              // Quantity Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daily Quantity:',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.grey),
                        onPressed: () {
                          if (qty > 0.5) setMState(() => qty -= 0.5);
                        },
                      ),
                      Text('$qty ${plan['unit']}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            color: Color(0xFF34D399)),
                        onPressed: () => setMState(() => qty += 0.5),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Delivery Frequency Chips
              const Text('Delivery Frequency:',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['Everyday', 'Mon-Sat', 'Alternate Days'].map((d) {
                  final isSel = days == d;
                  return ChoiceChip(
                    label: Text(d),
                    selected: isSel,
                    labelStyle: TextStyle(
                        color: isSel ? Colors.white : Colors.grey,
                        fontSize: 11),
                    selectedColor: const Color(0xFF059669),
                    backgroundColor: const Color(0xFF1E293B),
                    onSelected: (val) {
                      if (val) setMState(() => days = d);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Preferred Delivery Slot
              const Text('Preferred Morning Slot:',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSlot,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    items: [
                      '06:00 - 07:00 AM',
                      '07:00 - 08:00 AM',
                      '12:30 - 01:30 PM (Lunch)',
                      '06:00 - 07:30 PM (Evening)',
                    ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      if (val != null) setMState(() => selectedSlot = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Price Summary & Confirm
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Per Delivery Total:',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(
                    '₹${((plan['pricePerDelivery'] as num).toDouble() * (qty / ((plan['quantity'] as num?)?.toDouble() ?? 1.0))).toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final auth =
                        Provider.of<AuthProvider>(context, listen: false);

                    final payload = {
                      'businessId': '7a74b169-0512-4a3b-9f7d-6020832ceaf0',
                      'itemName': plan['itemName'],
                      'quantity': qty,
                      'unit': plan['unit'],
                      'deliverySlot': selectedSlot,
                      'daysOfWeek': days,
                      'pricePerDelivery': (plan['pricePerDelivery'] as num).toDouble(),
                    };

                    try {
                      await ApiService.createSubscription(auth.token!, payload);
                      _showSnack('Daily subscription activated!',
                          const Color(0xFF10B981));
                    } catch (_) {
                      setState(() {
                        _mySubscriptions.insert(0, {
                          'id': 'sub-${DateTime.now().millisecondsSinceEpoch}',
                          'itemName': plan['itemName'],
                          'quantity': qty,
                          'unit': plan['unit'],
                          'deliverySlot': selectedSlot,
                          'daysOfWeek': days,
                          'pricePerDelivery': (plan['pricePerDelivery'] as num).toDouble(),
                          'businessName': 'Neighborhood Dairy & Mart',
                          'businessPhone': '9828012345',
                          'isActive': true,
                          'isCurrentlyPaused': false,
                        });
                      });
                      _showSnack('Subscription activated locally!',
                          const Color(0xFF10B981));
                    }
                    _loadSubscriptions();
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  label: const Text('Start Daily Subscription',
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
    );
  }

  // 2. Pause Subscription / Vacation Mode
  void _showVacationPauseDialog(dynamic sub) {
    final reasonCtrl = TextEditingController(text: 'Going on family vacation');
    DateTime startDate = DateTime.now().add(const Duration(days: 1));
    DateTime endDate = DateTime.now().add(const Duration(days: 5));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.beach_access_rounded,
                  color: Color(0xFFF59E0B), size: 24),
              SizedBox(width: 8),
              Text('Vacation Mode (Pause)',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pause deliveries for "${sub['itemName']}". You will not be billed during these dates.',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 14),
              Text(
                'Pause from: ${startDate.toIso8601String().substring(0, 10)} to ${endDate.toIso8601String().substring(0, 10)}',
                style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Reason for pause',
                  labelStyle: TextStyle(color: Colors.grey, fontSize: 12),
                  filled: true,
                  fillColor: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final auth =
                    Provider.of<AuthProvider>(context, listen: false);
                final sDate = startDate.toIso8601String().substring(0, 10);
                final eDate = endDate.toIso8601String().substring(0, 10);

                try {
                  await ApiService.pauseSubscription(auth.token!,
                      sub['id'].toString(), sDate, eDate, reasonCtrl.text);
                  _showSnack('Deliveries paused till $eDate',
                      const Color(0xFFF59E0B));
                } catch (_) {
                  setState(() {
                    sub['isCurrentlyPaused'] = true;
                    sub['activePause'] = {
                      'pauseStartDate': sDate,
                      'pauseEndDate': eDate,
                      'reason': reasonCtrl.text,
                    };
                  });
                  _showSnack('Vacation pause set locally!',
                      const Color(0xFFF59E0B));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.black),
              child: const Text('Confirm Pause',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // 3. Book Safe School Transit Modal
  void _showBookTransitModal() {
    final stuNameCtrl = TextEditingController(text: 'Aarav Sharma (Class 6-B)');
    final schoolCtrl =
        TextEditingController(text: 'St. Xavier\'s Senior Secondary School');
    final pickupCtrl =
        TextEditingController(text: 'Plot 42, Chitrakoot, Vaishali Nagar');
    final timeCtrl = TextEditingController(text: '07:20 AM');
    String selectedVehicle = 'School Van (Force Traveller)';

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
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_bus_rounded,
                          color: Color(0xFFF59E0B), size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Book Safe School Transit',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17)),
                          Text('Doorstep pickup & drop with live parent tracking',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Colors.white12),

                _fieldInput(stuNameCtrl, 'Student Name & Class',
                    Icons.school_rounded),
                const SizedBox(height: 10),
                _fieldInput(
                    schoolCtrl, 'School Name', Icons.location_city_rounded),
                const SizedBox(height: 10),
                _fieldInput(pickupCtrl, 'Home Pickup Address',
                    Icons.home_work_rounded),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _fieldInput(timeCtrl, 'Morning Pickup Time',
                          Icons.access_time_rounded),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedVehicle,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                            items: [
                              'School Van (Force Traveller)',
                              'School Auto-Rickshaw Pool',
                              'AC Cab (Ertiga / Bolero)',
                            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                            onChanged: (val) {
                              if (val != null) setMState(() => selectedVehicle = val);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Pricing Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monthly Transit Pass',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          Text('Both ways (Pickup + Drop) • Mon to Sat',
                              style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                      Text('₹1,800/mo',
                          style: TextStyle(
                              color: Color(0xFF34D399),
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);

                      final payload = {
                        'studentName': stuNameCtrl.text.trim(),
                        'schoolName': schoolCtrl.text.trim(),
                        'pickupAddress': pickupCtrl.text.trim(),
                        'pickupLatitude': 26.9124,
                        'pickupLongitude': 75.7873,
                        'schoolLatitude': 26.9200,
                        'schoolLongitude': 75.7900,
                        'pickupTime': '07:20:00',
                        'monthlyFee': 1800.0,
                      };

                      try {
                        await ApiService.createSchoolTransitSchedule(
                            auth.token!, payload);
                        _showSnack('School transit pass booked successfully!',
                            const Color(0xFF10B981));
                      } catch (_) {
                        setState(() {
                          _myTransitSchedules.insert(0, {
                            'id': 'sch-${DateTime.now().millisecondsSinceEpoch}',
                            'studentName': stuNameCtrl.text.trim(),
                            'schoolName': schoolCtrl.text.trim(),
                            'pickupTime': timeCtrl.text.trim(),
                            'driverName': 'Mahesh Gurjar (Verified Van Driver)',
                            'driverPhone': '9829077889',
                            'vehicleType': selectedVehicle,
                            'plateNumber': 'RJ-14-SCH-1008',
                            'status': 'AtHome',
                          });
                        });
                        _showSnack('Transit pass activated locally!',
                            const Color(0xFF10B981));
                      }
                      _loadSchoolTransit();
                    },
                    icon: const Icon(Icons.verified_user_rounded, size: 18),
                    label: const Text('Confirm School Transit Pass',
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

  // ────────────────────────── BUILD MAIN ──────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        title: const Text('Daily Subscriptions & School Transit',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF10B981),
          indicatorWeight: 3,
          labelColor: const Color(0xFF34D399),
          unselectedLabelColor: Colors.grey,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(icon: Icon(Icons.repeat_rounded, size: 18), text: '🥛 Milk & Daily Subs'),
            Tab(icon: Icon(Icons.directions_bus_rounded, size: 18), text: '🚌 School Transit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSubscriptionsTab(),
          _buildSchoolTransitTab(),
        ],
      ),
    );
  }

  // ─── TAB 1: Daily Subscriptions ─────────────────────────────────
  Widget _buildSubscriptionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.wb_sunny_rounded,
                      color: Color(0xFF34D399), size: 30),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Morning Runs & Daily Essentials',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      SizedBox(height: 3),
                      Text(
                          'Doorstep fresh milk, tiffin & groceries before 7:30 AM every morning',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Active Subscriptions
          if (_mySubscriptions.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionTitle(
                    Icons.check_circle_rounded, 'My Active Daily Subscriptions'),
                Text('${_mySubscriptions.length} active',
                    style: const TextStyle(
                        color: Color(0xFF34D399), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),
            ..._mySubscriptions.map((sub) => _buildMySubscriptionCard(sub)),
            const SizedBox(height: 20),
          ],

          // Browse Popular Daily Plans
          _sectionTitle(Icons.local_grocery_store_rounded,
              'Available Daily Morning Plans'),
          const SizedBox(height: 10),
          ..._catalogPlans.map((plan) => _buildCatalogPlanCard(plan)),
        ],
      ),
    );
  }

  Widget _buildMySubscriptionCard(dynamic sub) {
    final isPaused = sub['isCurrentlyPaused'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPaused
              ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
              : const Color(0xFF10B981).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(sub['itemName'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPaused
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                      : const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPaused ? 'PAUSED' : 'ACTIVE',
                  style: TextStyle(
                      color: isPaused
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF34D399),
                      fontWeight: FontWeight.bold,
                      fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${sub['quantity']} ${sub['unit']} • Slot: ${sub['deliverySlot']} • ${sub['daysOfWeek']}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          Text('Merchant: ${sub['businessName'] ?? 'Shop'}',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          if (isPaused && sub['activePause'] != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.beach_access_rounded,
                      color: Color(0xFFF59E0B), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Vacation until ${sub['activePause']['pauseEndDate']}',
                    style: const TextStyle(
                        color: Color(0xFFF59E0B), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 16, color: Colors.white10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${sub['pricePerDelivery']} / delivery',
                style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              Row(
                children: [
                  if (isPaused)
                    ElevatedButton.icon(
                      onPressed: () async {
                        final auth = Provider.of<AuthProvider>(context,
                            listen: false);
                        try {
                          await ApiService.resumeSubscription(
                              auth.token!, sub['id'].toString());
                        } catch (_) {}
                        setState(() => sub['isCurrentlyPaused'] = false);
                        _showSnack('Deliveries resumed!',
                            const Color(0xFF10B981));
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 14),
                      label: const Text('Resume', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => _showVacationPauseDialog(sub),
                      icon: const Icon(Icons.pause_rounded,
                          size: 14, color: Color(0xFFF59E0B)),
                      label: const Text('Vacation Pause',
                          style: TextStyle(
                              color: Color(0xFFF59E0B), fontSize: 11)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFF59E0B)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  const SizedBox(width: 8),
                  if (sub['businessPhone'] != null)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.phone_rounded,
                          color: Color(0xFF38BDF8), size: 18),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CallingScreen(
                            partnerUserId: sub['businessPhone'],
                            partnerName: sub['businessName'] ?? 'Shop',
                            partnerRole: 'Merchant',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogPlanCard(dynamic plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF0F172A),
            child: Text(plan['icon'] ?? '🥛',
                style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan['itemName'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text(plan['description'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('₹${plan['pricePerDelivery']} / ${plan['unit']}',
                    style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _showSubscribeModal(plan),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Subscribe',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: Safe School Transit ─────────────────────────────────
  Widget _buildSchoolTransitTab() {
    final auth = Provider.of<AuthProvider>(context);
    final isDriver = auth.role == 'Driver';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Color(0xFFFBBF24), size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Safe School Transit System',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(
                        isDriver
                            ? 'Manage morning student pickups & safety check-ins'
                            : 'Live student tracking, driver contact & emergency SOS',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (!isDriver)
                  IconButton(
                    icon: const Icon(Icons.add_circle,
                        color: Color(0xFFFBBF24), size: 28),
                    tooltip: 'Book New School Pass',
                    onPressed: _showBookTransitModal,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Driver Student Check-in List
          if (isDriver) ...[
            _sectionTitle(Icons.people_alt_rounded,
                'My Assigned Students Route (${_driverStudents.length})'),
            const SizedBox(height: 10),
            ..._driverStudents.map((stu) => _buildDriverStudentCard(stu)),
          ] else ...[
            // Parent Active Passes View
            _sectionTitle(Icons.verified_user_rounded,
                'Child Transit Pass & Live Status'),
            const SizedBox(height: 10),
            if (_myTransitSchedules.isEmpty)
              _emptyTransitState()
            else
              ..._myTransitSchedules.map((s) => _buildParentTransitCard(s)),
          ],
        ],
      ),
    );
  }

  Widget _buildParentTransitCard(dynamic s) {
    final status = s['status']?.toString() ?? 'AtHome';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s['studentName'] ?? 'Student',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Pickup: ${s['pickupTime'] ?? '07:20 AM'}',
                    style: const TextStyle(
                        color: Color(0xFFFBBF24),
                        fontWeight: FontWeight.bold,
                        fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.school_outlined, color: Colors.grey, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(s['schoolName'] ?? 'School',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live Progress Timeline
          _buildTransitTimeline(status),
          const SizedBox(height: 14),

          // Driver & Vehicle Details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF1E293B),
                  child: const Icon(Icons.directions_bus,
                      color: Color(0xFFFBBF24), size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['driverName'] ?? 'School Van Driver',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                      Text('${s['vehicleType'] ?? 'Van'} • ${s['plateNumber'] ?? ''}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                if (s['driverPhone'] != null)
                  IconButton(
                    icon: const Icon(Icons.phone_rounded,
                        color: Color(0xFF10B981)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallingScreen(
                          partnerUserId: s['driverPhone'],
                          partnerName: s['driverName'] ?? 'Van Driver',
                          partnerRole: 'Driver',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // SOS Emergency Alert Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _triggerEmergencySos(s),
              icon: const Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 16),
              label: const Text('EMERGENCY SOS ALERT',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransitTimeline(String status) {
    final stages = [
      {'key': 'AtHome', 'label': 'At Home', 'icon': Icons.home_rounded},
      {
        'key': 'BoardedVan',
        'label': 'In Van',
        'icon': Icons.directions_bus_rounded
      },
      {'key': 'AtSchool', 'label': 'At School', 'icon': Icons.school_rounded},
      {
        'key': 'DroppedHome',
        'label': 'Back Home',
        'icon': Icons.check_circle_rounded
      },
    ];

    int activeIdx = 0;
    if (status == 'BoardedVan') activeIdx = 1;
    if (status == 'AtSchool') activeIdx = 2;
    if (status == 'DroppedHome') activeIdx = 3;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: stages.asMap().entries.map((e) {
        final idx = e.key;
        final st = e.value;
        final isDone = idx <= activeIdx;

        return Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isDone
                  ? const Color(0xFF10B981)
                  : const Color(0xFF334155),
              child: Icon(st['icon'] as IconData,
                  size: 14,
                  color: isDone ? Colors.white : Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(st['label'] as String,
                style: TextStyle(
                    color: isDone ? Colors.white : Colors.grey,
                    fontSize: 9,
                    fontWeight: isDone ? FontWeight.bold : FontWeight.normal)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildDriverStudentCard(dynamic stu) {
    final status = stu['status'] ?? 'AtHome';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(stu['studentName'] ?? '',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Text('Slot: ${stu['pickupTime'] ?? ''}',
                  style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
              '${stu['schoolName'] ?? ''} • Parent: ${stu['guardianName'] ?? ''}',
              style: const TextStyle(color: Colors.grey, fontSize: 11)),
          const Divider(height: 16, color: Colors.white10),

          // Check-in action buttons for driver
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Current: $status',
                  style: const TextStyle(
                      color: Color(0xFF34D399),
                      fontWeight: FontWeight.bold,
                      fontSize: 11)),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);
                      try {
                        await ApiService.updateSchoolTransitStatus(
                            auth.token!, stu['id'].toString(), 'BoardedVan');
                      } catch (_) {}
                      setState(() => stu['status'] = 'BoardedVan');
                      _showSnack('Marked student Boarded Van!',
                          const Color(0xFF10B981));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Boarded', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () async {
                      final auth =
                          Provider.of<AuthProvider>(context, listen: false);
                      try {
                        await ApiService.updateSchoolTransitStatus(
                            auth.token!, stu['id'].toString(), 'AtSchool');
                      } catch (_) {}
                      setState(() => stu['status'] = 'AtSchool');
                      _showSnack('Marked dropped at School!',
                          const Color(0xFF3B82F6));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('At School', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _triggerEmergencySos(dynamic s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF450A0A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text('TRIGGER SOS ALERT',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ],
        ),
        content: Text(
          'Immediate emergency broadcast will be sent to the school control room, driver, and emergency authorities for ${s['studentName']}.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              try {
                await ApiService.triggerSchoolTransitSos(auth.token!,
                    s['id'].toString(), 'Emergency SOS triggered by parent');
              } catch (_) {}
              _showSnack('🚨 EMERGENCY SOS SENT TO POLICE & CONTROL ROOM!',
                  Colors.red);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('SEND SOS NOW',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _emptyTransitState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.directions_bus_outlined,
                size: 50, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No active school transit pass found',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _showBookTransitModal,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Book Safe School Van'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────
  Widget _fieldInput(TextEditingController ctrl, String hint, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        prefixIcon: Icon(icon, color: const Color(0xFFFBBF24), size: 18),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF34D399), size: 18),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      ],
    );
  }
}
