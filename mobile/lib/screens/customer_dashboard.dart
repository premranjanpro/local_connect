import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_store.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../models/task_status_models.dart';
import '../widgets/task_detail_cards.dart';
import '../widgets/live_tracking_map_widget.dart';
import '../widgets/driver_vehicle_bottom_sheet.dart';
import '../widgets/order_rating_bottom_sheet.dart';
import 'calling_screen.dart';
import 'notification_center_screen.dart';
import 'task_booking_details_screen.dart';
import '../widgets/app_menu_drawer.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── Rides ──
  final _pickupCtrl =
      TextEditingController(text: 'Sindhi Camp, Jaipur');
  final _dropCtrl =
      TextEditingController(text: 'Malviya Nagar, Jaipur');
  Map<String, dynamic>? _fareEstimate;
  Map<String, dynamic>? _activeRide;
  bool _estimating = false;

  // ── Grocery ──
  final _groceryCtrl = TextEditingController(
      text: 'Mujhe 5kg aaloo, 2 kg pyaj, 1 kg tomato chahiye');
  String _rfqMode = 'SingleShop';
  Map<String, dynamic>? _activeRfq;
  Map<String, dynamic>? _aiAnalysis;
  bool _analyzingAi = false;
  List<dynamic> _rfqQuotes = [];
  bool _loadingQuotes = false;

  // ── Subscriptions ──
  List<dynamic> _subs = [];
  bool _loadingSubs = false;

  // ── Banners ──
  List<dynamic> _banners = [];
  bool _loadingBanners = false;

  // ── My Orders (all tasks) ──
  List<TaskModel> _myTasks = [];
  bool _loadingTasks = false;
  TaskStatus? _filterStatus;

  // ── Stats ──
  DashboardStats _stats = const DashboardStats();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadAll();
    NotificationService.onTaskUpdated = (d) {
      if (mounted) {
        _loadAll();
        _showSnack('🔔 ${d['type'] ?? 'Order update'}', const Color(0xFF6366F1));
      }
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pickupCtrl.dispose();
    _dropCtrl.dispose();
    _groceryCtrl.dispose();
    super.dispose();
  }

  void _loadAll() {
    _loadSubs();
    _loadBanners();
    _loadMyTasks();
  }

  // ─────────────────────────── Loaders ─────────────────────────────

  Future<void> _loadMyTasks() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    setState(() => _loadingTasks = true);
    // Simulate with mock data when backend not ready
    try {
      await ApiService.getMySubscriptions(auth.token!);
      // Real endpoint would be: GET /api/v1/tasks/my
      // For now we build mock tasks from subs
      final mocks = _buildMockTasks();
      setState(() {
        _myTasks = mocks;
        _stats = DashboardStats.fromTasks(mocks);
        _loadingTasks = false;
      });
    } catch (_) {
      final mocks = _buildMockTasks();
      setState(() {
        _myTasks = mocks;
        _stats = DashboardStats.fromTasks(mocks);
        _loadingTasks = false;
      });
    }
  }

  List<TaskModel> _buildMockTasks() {
    return [
      TaskModel.fromJson({
        'id': 'cab-001-pending',
        'taskType': 'MobilityRide',
        'status': 'pending',
        'pickupAddress': 'Sindhi Camp Bus Stand, Jaipur',
        'dropoffAddress': 'Malviya Nagar Metro Station',
        'estimatedFare': 120,
        'createdAt': DateTime.now().subtract(const Duration(minutes: 3)).toIso8601String(),
        'paymentMode': 'Cash',
      }),
      TaskModel.fromJson({
        'id': 'cab-002-assigned',
        'taskType': 'MobilityRide',
        'status': 'assigned',
        'pickupAddress': 'C-Scheme, Jaipur',
        'dropoffAddress': 'Vaishali Nagar',
        'estimatedFare': 85,
        'driverName': 'Deepak Yadav',
        'driverAvatarUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
        'driverDlNumber': 'DL-1420110012345',
        'driverRating': 4.9,
        'vehicleType': 'Bike',
        'vehiclePlateNumber': 'RJ14-SC-7890',
        'vehicleColor': 'Flame Red',
        'vehicleMakeModel': 'Hero Splendor Plus',
        'vehiclePhotoUrl': 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?w=500',
        'pickupOtp': '4821',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 12)).toIso8601String(),
      }),
      TaskModel.fromJson({
        'id': 'groc-001-ongoing',
        'taskType': 'GroceryDelivery',
        'status': 'ongoing',
        'pickupAddress': 'Gupta Kirana Store, Vaishali',
        'dropoffAddress': 'Flat 402, Royal Palms, Jaipur',
        'estimatedFare': 245,
        'shopName': 'Gupta Kirana Store',
        'driverName': 'Mohit Kumar',
        'driverAvatarUrl': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=300',
        'driverDlNumber': 'DL-1420180098765',
        'driverRating': 4.7,
        'vehicleType': 'Auto',
        'vehiclePlateNumber': 'RJ14-TR-5566',
        'vehicleColor': 'Yellow & Green',
        'vehicleMakeModel': 'Bajaj RE Compact Auto',
        'vehiclePhotoUrl': 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=500',
        'createdAt': DateTime.now().subtract(const Duration(minutes: 25)).toIso8601String(),
        'items': [
          {'item': 'Aaloo 5kg'},
          {'item': 'Pyaj 2kg'},
          {'item': 'Tomato 1kg'}
        ],
      }),
      TaskModel.fromJson({
        'id': 'cab-003-completed',
        'taskType': 'MobilityRide',
        'status': 'completed',
        'pickupAddress': 'Jaipur Airport',
        'dropoffAddress': 'Hotel Rajmahal, MI Road',
        'estimatedFare': 350,
        'driverName': 'Deepak Yadav',
        'driverAvatarUrl': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
        'driverDlNumber': 'DL-1420110012345',
        'driverRating': 4.8,
        'vehicleType': 'CabSedan',
        'vehiclePlateNumber': 'RJ14-CP-1234',
        'vehicleColor': 'Arctic White',
        'vehicleMakeModel': 'Maruti Suzuki Swift',
        'vehiclePhotoUrl': 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=500',
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'completedAt': DateTime.now().subtract(const Duration(hours: 1, minutes: 30)).toIso8601String(),
      }),
      TaskModel.fromJson({
        'id': 'groc-002-completed',
        'taskType': 'GroceryDelivery',
        'status': 'completed',
        'pickupAddress': 'Fresh Mart, Tonk Road',
        'dropoffAddress': 'Flat 201, Shiv Vihar Colony',
        'estimatedFare': 180,
        'shopName': 'Fresh Mart',
        'createdAt': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'completedAt': DateTime.now().subtract(const Duration(hours: 22)).toIso8601String(),
      }),
      TaskModel.fromJson({
        'id': 'cab-004-cancelled',
        'taskType': 'MobilityRide',
        'status': 'cancelled',
        'pickupAddress': 'Gopalpura Bypass',
        'dropoffAddress': 'Durgapura Railway Station',
        'estimatedFare': 70,
        'createdAt': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      }),
    ];
  }

  Future<void> _loadSubs() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    setState(() => _loadingSubs = true);
    try {
      final subs = await ApiService.getMySubscriptions(auth.token!);
      setState(() {
        _subs = subs;
        _loadingSubs = false;
      });
    } catch (_) {
      setState(() => _loadingSubs = false);
    }
  }

  Future<void> _loadBanners() async {
    setState(() => _loadingBanners = true);
    try {
      final b = await ApiService.getIntercityBanners();
      setState(() {
        _banners = b;
        _loadingBanners = false;
      });
    } catch (_) {
      setState(() => _loadingBanners = false);
    }
  }

  // ─────────────────────────── Actions ─────────────────────────────

  Future<void> _estimateRide() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _estimating = true);
    try {
      final res = await ApiService.estimateTask(
          auth.token ?? '', 26.9200, 75.7900, 26.8500, 75.8200, 'MobilityRide');
      setState(() {
        _fareEstimate = res;
        _estimating = false;
      });
    } catch (e) {
      setState(() => _estimating = false);
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _bookRide() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final task = await ApiService.createTask(auth.token!, {
        'taskType': 'MobilityRide',
        'pickupAddress': _pickupCtrl.text.trim(),
        'pickupLatitude': 26.9200,
        'pickupLongitude': 75.7900,
        'dropoffAddress': _dropCtrl.text.trim(),
        'dropoffLatitude': 26.8500,
        'dropoffLongitude': 75.8200,
        'paymentMode': 'Cash',
      });
      setState(() => _activeRide = task);
      _showSnack('Ride booked! OTP: ${task['pickupOtp']}', const Color(0xFF10B981));
      _loadMyTasks();
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _analyzeAi() async {
    final q = _groceryCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() => _analyzingAi = true);
    try {
      final res = await ApiService.parseAiIntent(q);
      setState(() {
        _aiAnalysis = res;
        _analyzingAi = false;
        final mode = res['target_mode'];
        if (mode == 'THREE_SHOPS') {
          _rfqMode = 'MultiShop';
        } else if (mode == 'SINGLE_SHOP') {
          _rfqMode = 'SingleShop';
        } else if (mode == 'BROADCAST') {
          _rfqMode = 'BroadcastNetwork';
        }
      });
    } catch (e) {
      setState(() => _analyzingAi = false);
      _showSnack('AI: ${e.toString()}', Colors.orange);
    }
  }

  Future<void> _submitGrocery() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      String itemsJson =
          '[{"item":"Potato","qty":5},{"item":"Onion","qty":2},{"item":"Tomato","qty":1}]';
      if (_aiAnalysis?['items'] != null &&
          (_aiAnalysis!['items'] as List).isNotEmpty) {
        itemsJson = jsonEncode(_aiAnalysis!['items']);
      }
      final rfq = await ApiService.createRfq(auth.token!, {
        'mode': _rfqMode,
        'rawPrompt': _groceryCtrl.text.trim(),
        'structuredItemsJson': itemsJson,
        'deliveryAddress': 'Flat 402, Royal Palms, Jaipur',
        'deliveryLatitude': 26.8520,
        'deliveryLongitude': 75.8230,
      });
      setState(() => _activeRfq = rfq);
      _showSnack('Grocery request sent!', const Color(0xFF3B82F6));
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _loadRfqQuotes() async {
    if (_activeRfq == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _loadingQuotes = true);
    try {
      final res = await ApiService.getRfq(auth.token!, _activeRfq!['id']);
      setState(() {
        _rfqQuotes = res['quotes'] ?? [];
        _loadingQuotes = false;
      });
    } catch (e) {
      setState(() => _loadingQuotes = false);
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _acceptQuote(String qId, String shop, double price, String mode) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await ApiService.acceptRfqQuote(auth.token!, _activeRfq!['id'], qId, mode);
      _showSnack('Order placed with $shop!', const Color(0xFF10B981));
      await _loadRfqQuotes();
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _toggleVacation(String subId, bool isPaused) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      if (isPaused) {
        await ApiService.resumeSubscription(auth.token!, subId);
        _showSnack('Delivery resumed!', const Color(0xFF10B981));
      } else {
        final now = DateTime.now();
        final s = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final e = '${now.year}-${now.month.toString().padLeft(2, '0')}-${(now.day + 5).toString().padLeft(2, '0')}';
        await ApiService.pauseSubscription(auth.token!, subId, s, e, 'Vacation');
        _showSnack('Vacation Mode: 5 days paused', const Color(0xFFF59E0B));
      }
      _loadSubs();
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  void _showSnack(String msg, Color bg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: bg));
    }
  }

  // ─────────────────────────── Build ───────────────────────────────

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return '🌅 Good Morning';
    if (h < 17) return '☀️ Good Afternoon';
    if (h < 20) return '🌇 Good Evening';
    return '🌙 Good Night';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFF050A15),
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
                  _buildMyOrdersTab(),
                  _buildRidesTab(),
                  _buildGroceryTab(),
                  _buildSubscriptionsTab(),
                  _buildBannersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Premium Stat Pills ─────────────────────────────────────────────
  Widget _buildStatPills() {
    return Row(
      children: [
        _statPill(_stats.pending.toString(), 'Pending', const Color(0xFFF59E0B), Icons.schedule_rounded),
        const SizedBox(width: 7),
        _statPill(_stats.assigned.toString(), 'Active', const Color(0xFF3B82F6), Icons.person_pin_rounded),
        const SizedBox(width: 7),
        _statPill(_stats.ongoing.toString(), 'Ongoing', const Color(0xFF8B5CF6), Icons.local_shipping_rounded),
        const SizedBox(width: 7),
        _statPill(_stats.completed.toString(), 'Done', const Color(0xFF10B981), Icons.check_circle_rounded),
        const SizedBox(width: 7),
        _statPill(_stats.cancelled.toString(), 'Cancel', const Color(0xFFEF4444), Icons.cancel_rounded),
      ],
    );
  }

  Widget _statPill(String val, String label, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.06)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(val, style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 16, height: 1.1)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(
                color: Colors.white38, fontSize: 8.5, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── Quick Shortcuts ────────────────────────────────────────────────
  Widget _buildQuickShortcuts() {
    final shortcuts = [
      (Icons.local_taxi_rounded, 'Book\nRide', const Color(0xFF3B82F6), 1),
      (Icons.shopping_basket_rounded, 'Grocery', const Color(0xFF10B981), 2),
      (Icons.repeat_rounded, 'Daily\nSubs', const Color(0xFF8B5CF6), 3),
      (Icons.alt_route_rounded, 'Intercity', const Color(0xFFFF9F43), 4),
      (Icons.campaign_rounded, 'Broadcast', const Color(0xFFEC4899), 0),
    ];
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shortcuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final s = shortcuts[i];
          return GestureDetector(
            onTap: () => _tabController.animateTo(s.$4),
            child: Container(
              width: 72,
              decoration: BoxDecoration(
                color: s.$3.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: s.$3.withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [s.$3.withValues(alpha: 0.3), s.$3.withValues(alpha: 0.1)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(s.$1, color: s.$3, size: 20),
                  ),
                  const SizedBox(height: 6),
                  Text(s.$2, textAlign: TextAlign.center,
                      style: TextStyle(color: s.$3, fontSize: 9.5,
                          fontWeight: FontWeight.w600, height: 1.2)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Premium Order Card ─────────────────────────────────────────────
  Widget _buildPremiumOrderCard(TaskModel t) {
    final statusColor = t.status.color;
    final taskIcon = _taskTypeIcon(t.taskType);
    final taskLabel = _taskTypeLabel(t.taskType);
    final fare = t.estimatedFare?.toStringAsFixed(0) ?? '—';
    final timeAgo = _timeAgo(t.createdAt);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => TaskBookingDetailsScreen(
          taskId: t.id, userRole: 'Customer', initialTask: t),
      )),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E1626),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: statusColor.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(
              color: statusColor.withValues(alpha: 0.06),
              blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left colored status bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusColor, statusColor.withValues(alpha: 0.3)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Icon box
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      statusColor.withValues(alpha: 0.25),
                      statusColor.withValues(alpha: 0.08),
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.2)),
                  ),
                  child: Center(child: Text(taskIcon,
                      style: const TextStyle(fontSize: 20))),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(taskLabel, style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Text('₹$fare', style: TextStyle(
                              color: statusColor, fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _routeRow(const Color(0xFF10B981), t.pickupAddress ?? 'Pickup point'),
                      const SizedBox(height: 3),
                      _routeRow(const Color(0xFFEF4444), t.dropoffAddress ?? 'Drop point'),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(children: [
                              Icon(t.status.icon, color: statusColor, size: 10),
                              const SizedBox(width: 4),
                              Text(t.status.label, style: TextStyle(
                                  color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                            ]),
                          ),
                          Text(timeAgo, style: const TextStyle(
                              color: Colors.white24, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _routeRow(Color dot, String text) {
    return Row(children: [
      Container(width: 7, height: 7,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Expanded(child: Text(text,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
    ]);
  }

  String _taskTypeIcon(String? type) {
    switch (type) {
      case 'MobilityRide': return '🚕';
      case 'GroceryDelivery': return '🛒';
      case 'SubscriptionDelivery': return '🔄';
      case 'Intercity': return '🚌';
      default: return '📦';
    }
  }

  String _taskTypeLabel(String? type) {
    switch (type) {
      case 'MobilityRide': return 'Mobility Ride';
      case 'GroceryDelivery': return 'Grocery Delivery';
      case 'SubscriptionDelivery': return 'Subscription Delivery';
      case 'Intercity': return 'Intercity Trip';
      default: return 'Delivery Order';
    }
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }

  // ── Premium Sliver Header ──────────────────────────────────────────
  Widget _buildSliverHeader(AuthProvider auth) {
    final name = auth.fullName ?? 'User';
    final initials = name.length >= 2
        ? '${name[0]}${name.split(' ').length > 1 ? name.split(' ').last[0] : name[1]}'.toUpperCase()
        : name[0].toUpperCase();

    return SliverAppBar(
      expandedHeight: 230,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF050A15),
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
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationCenterScreen())),
              ),
              if (store.unreadCount > 0)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                        color: Color(0xFFEF4444), shape: BoxShape.circle),
                    child: Text(
                      store.unreadCount > 9 ? '9+' : '${store.unreadCount}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0F0C29),
                Color(0xFF1A1060),
                Color(0xFF050A15),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              // Mesh glow orbs
              Positioned(
                top: -40, right: -30,
                child: Container(
                  width: 180, height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [const Color(0xFF6C63FF).withValues(alpha: 0.35), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 20, left: -20,
                child: Container(
                  width: 140, height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [const Color(0xFF3ECFCF).withValues(alpha: 0.25), Colors.transparent],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: greeting + avatar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greeting(),
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 13,
                                    fontWeight: FontWeight.w500, letterSpacing: 0.3),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                name,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 24,
                                    fontWeight: FontWeight.w800, letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 6, height: 6,
                                    decoration: const BoxDecoration(
                                        color: Color(0xFF10B981), shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 5),
                                  const Text('Vaishali Nagar, Jaipur',
                                      style: TextStyle(
                                          color: Colors.white38, fontSize: 11,
                                          fontWeight: FontWeight.w400)),
                                ],
                              ),
                            ],
                          ),
                          // Avatar
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)],
                                begin: Alignment.topLeft, end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6C63FF).withValues(alpha: 0.4),
                                  blurRadius: 16, spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(initials,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      // Premium stat pills
                      _buildStatPills(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF3ECFCF)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                (auth.fullName ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('My Dashboard',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _statItem(_stats.pending.toString(), 'Pending', const Color(0xFFF59E0B)),
        const SizedBox(width: 12),
        _statItem(_stats.assigned.toString(), 'Assigned', const Color(0xFF3B82F6)),
        const SizedBox(width: 12),
        _statItem(_stats.ongoing.toString(), 'Ongoing', const Color(0xFF8B5CF6)),
        const SizedBox(width: 12),
        _statItem(_stats.completed.toString(), 'Done', const Color(0xFF10B981)),
        const SizedBox(width: 12),
        _statItem(_stats.cancelled.toString(), 'Cancelled', const Color(0xFFEF4444)),
      ],
    );
  }

  Widget _statItem(String val, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.18),
              color.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(val,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 9),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ── Premium Tab Bar with Pill Indicator ──────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF080D1C),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1729),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6C63FF)]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
                blurRadius: 10, spreadRadius: 0,
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: EdgeInsets.zero,
          dividerColor: Colors.transparent,
          labelPadding: EdgeInsets.zero,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 11),
          tabs: const [
            Tab(child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long_rounded, size: 14), SizedBox(width: 5), Text('Orders'),
              ]),
            )),
            Tab(child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.local_taxi_rounded, size: 14), SizedBox(width: 5), Text('Ride'),
              ]),
            )),
            Tab(child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.shopping_basket_rounded, size: 14), SizedBox(width: 5), Text('Grocery'),
              ]),
            )),
            Tab(child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.repeat_rounded, size: 14), SizedBox(width: 5), Text('Subs'),
              ]),
            )),
            Tab(child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.alt_route_rounded, size: 14), SizedBox(width: 5), Text('Intercity'),
              ]),
            )),
          ],
        ),
      ),
    );
  }

  // ── TAB 1: My Orders ───────────────────────────────────────────────
  Widget _buildMyOrdersTab() {
    final filtered = _filterStatus == null
        ? _myTasks
        : _myTasks.where((t) => t.status == _filterStatus).toList();


    return RefreshIndicator(
      onRefresh: _loadMyTasks,
      color: const Color(0xFF6C63FF),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick action shortcuts row
            _buildQuickShortcuts(),
            const SizedBox(height: 16),

            // Section header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Orders',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700,
                        fontSize: 16, letterSpacing: -0.3)),
                GestureDetector(
                  onTap: () => setState(() => _filterStatus = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Row(children: [
                      Icon(Icons.filter_list_rounded,
                          color: Colors.white54, size: 14),
                      SizedBox(width: 4),
                      Text('Filter', style: TextStyle(
                          color: Colors.white54, fontSize: 11)),
                    ]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Premium Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(null, 'All 📎', _filterStatus == null),
                  ...TaskStatus.values.map((s) =>
                      _filterChip(s, s.label, _filterStatus == s)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_loadingTasks)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(
                    color: Color(0xFF6C63FF), strokeWidth: 2),
              ))
            else if (filtered.isEmpty)
              _emptyState(
                  'No ${_filterStatus?.label.toLowerCase() ?? ''} orders found',
                  Icons.inbox_rounded)
            else
              ...filtered.map((t) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPremiumOrderCard(t),
                      const SizedBox(height: 12),
                    ],
                  )),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(TaskStatus? status, String label, bool selected) {
    final color = status?.color ?? const Color(0xFF6C63FF);
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
                )
              : null,
          color: selected ? null : const Color(0xFF111827),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? color : Colors.white.withValues(alpha: 0.08),
              width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [BoxShadow(
                  color: color.withValues(alpha: 0.2),
                  blurRadius: 8, spreadRadius: 0)]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? color : Colors.white38,
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w400)),
      ),
    );
  }


  // ── TAB 2: Book Ride ──────────────────────────────────────────────
  Widget _buildRidesTab() {

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(Icons.local_taxi_rounded, 'Book a Mobility Ride',
              const Color(0xFF3B82F6)),
          const SizedBox(height: 12),
          _inputField(_pickupCtrl, 'Pickup Location',
              Icons.my_location_rounded, const Color(0xFF10B981)),
          const SizedBox(height: 10),
          _inputField(_dropCtrl, 'Dropoff Destination',
              Icons.pin_drop_rounded, const Color(0xFFEF4444)),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _estimating ? null : _estimateRide,
            icon: _estimating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.calculate_rounded),
            label:
                Text(_estimating ? 'Calculating...' : 'Get Fare Estimate'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_fareEstimate != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${_fareEstimate!['distanceKm']} km • ${_fareEstimate!['durationMinutes']} mins',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13)),
                          Text(
                              'Engine: ${_fareEstimate!['provider'] ?? 'Haversine'}',
                              style: const TextStyle(
                                  color: Color(0xFF64748B), fontSize: 11)),
                        ],
                      ),
                      Text('₹${_fareEstimate!['estimatedFare']}',
                          style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 26,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _bookRide,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirm Ride Booking',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
          if (_activeRide != null) ...[
            const SizedBox(height: 16),
            LiveTrackingMapWidget(
              pickupLat: (_activeRide!['pickupLatitude'] as num?)?.toDouble() ?? 26.9200,
              pickupLng: (_activeRide!['pickupLongitude'] as num?)?.toDouble() ?? 75.7900,
              dropoffLat: (_activeRide!['dropoffLatitude'] as num?)?.toDouble() ?? 26.8500,
              dropoffLng: (_activeRide!['dropoffLongitude'] as num?)?.toDouble() ?? 75.8200,
              initialDriverLat: 26.9150,
              initialDriverLng: 75.7950,
              status: _activeRide!['status'] ?? 'En Route',
              otp: _activeRide!['pickupOtp']?.toString(),
              taskId: _activeRide!['id']?.toString(),
              driverId: _activeRide!['assignedDriverId']?.toString(),
            ),
          ],
        ],
      ),
    );
  }

  // ─── TAB 3: Grocery RFQ ───────────────────────────────────────────
  Widget _buildGroceryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(Icons.shopping_basket_rounded, 'AI Grocery Order',
              const Color(0xFF8B5CF6)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _groceryCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'e.g. 5kg aaloo, 2kg pyaj...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.mic_rounded,
                        color: Color(0xFF8B5CF6)),
                  ),
                ),
                const SizedBox(height: 12),
                // Mode selector
                Row(
                  children: [
                    Expanded(child: _modeChip('SingleShop', '1 Shop')),
                    const SizedBox(width: 6),
                    Expanded(child: _modeChip('MultiShop', 'Compare 3')),
                    const SizedBox(width: 6),
                    Expanded(child: _modeChip('BroadcastNetwork', 'Network')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _analyzingAi ? null : _analyzeAi,
                        icon: _analyzingAi
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF8B5CF6)))
                            : const Icon(Icons.auto_awesome_rounded,
                                color: Color(0xFF8B5CF6), size: 16),
                        label: Text(
                            _analyzingAi ? 'Analyzing...' : 'Parse with AI',
                            style: const TextStyle(
                                color: Color(0xFF8B5CF6))),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFF8B5CF6))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _submitGrocery,
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Send RFQ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_aiAnalysis != null) ...[
            const SizedBox(height: 12),
            _aiResultCard(),
          ],
          if (_activeRfq != null) ...[
            const SizedBox(height: 12),
            _rfqStatusCard(),
          ],
          if (_rfqQuotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('3-Shop Comparative Rates',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            const SizedBox(height: 10),
            ..._rfqQuotes.map((q) {
              final price =
                  (q['quotedTotalPrice'] as num?)?.toDouble() ?? 0;
              final shop = q['businessName']?.toString() ?? 'Store';
              final prep = q['estimatedPrepMinutes'] ?? 15;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(shop,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14)),
                        Text('₹${price.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Color(0xFF34D399),
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Ready in $prep mins',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _acceptQuote(q['id'], shop, price, 'Cash'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                foregroundColor: Colors.white),
                            child: const Text('Accept Cash'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _acceptQuote(q['id'], shop, price, 'Dues'),
                            style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: Color(0xFFF59E0B))),
                            child: const Text('Add to Khata',
                                style: TextStyle(
                                    color: Color(0xFFF59E0B))),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _modeChip(String mode, String label) {
    final selected = _rfqMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _rfqMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.2)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected
                  ? const Color(0xFF8B5CF6)
                  : Colors.white12),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: selected
                    ? const Color(0xFF8B5CF6)
                    : Colors.grey,
                fontSize: 11,
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.normal)),
      ),
    );
  }

  Widget _aiResultCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.psychology_rounded,
                color: Color(0xFF8B5CF6), size: 16),
            const SizedBox(width: 6),
            Text('AI: ${_aiAnalysis!['intent_type'] ?? 'Detected'}',
                style: const TextStyle(
                    color: Color(0xFFA78BFA),
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 6),
          Text(_aiAnalysis!['reply_message'] ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _rfqStatusCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mode: ${_activeRfq!['mode'] ?? 'SingleShop'}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            Text('Status: ${_activeRfq!['status']}',
                style: const TextStyle(
                    color: Colors.grey, fontSize: 12)),
          ]),
          ElevatedButton.icon(
            onPressed: _loadingQuotes ? null : _loadRfqQuotes,
            icon: _loadingQuotes
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.refresh_rounded, size: 14),
            label: const Text('Refresh', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // ─── TAB 4: Subscriptions ─────────────────────────────────────────
  Widget _buildSubscriptionsTab() {
    if (_loadingSubs) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)));
    }
    return RefreshIndicator(
      onRefresh: _loadSubs,
      color: const Color(0xFF10B981),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.repeat_rounded,
                'Daily Morning Deliveries', const Color(0xFF10B981)),
            const SizedBox(height: 4),
            const Text(
                'Pure milk, newspaper, tiffin — auto-delivered 06:00–07:30 AM',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 16),
            if (_subs.isEmpty)
              _emptyState('No active subscriptions', Icons.subscriptions_rounded)
            else
              ..._subs.map((s) => TaskCard10Subscription(
                    sub: s,
                    onTogglePause: () =>
                        _toggleVacation(s['id'], s['isCurrentlyPaused'] == true),
                  )),
          ],
        ),
      ),
    );
  }

  // ─── TAB 5: Intercity Banners ─────────────────────────────────────
  Widget _buildBannersTab() {
    return RefreshIndicator(
      onRefresh: _loadBanners,
      color: const Color(0xFF6366F1),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(Icons.alt_route_rounded,
                'Intercity Carpools', const Color(0xFF6366F1)),
            const SizedBox(height: 12),
            if (_loadingBanners)
              const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF6366F1)))
            else if (_banners.isEmpty)
              _emptyState(
                  'No intercity routes today', Icons.directions_car_rounded)
            else
              ..._banners.map((b) => TaskCard11Banner(
                    banner: b,
                    onBook: () async {
                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      try {
                        final res = await ApiService.bookBannerSeat(
                            auth.token!, b['id'], 1);
                        _showSnack(
                            'Seat booked! OTP: ${res['pickupOtp']}',
                            const Color(0xFF10B981));
                        _loadBanners();
                      } catch (e) {
                        _showSnack(e.toString(), Colors.redAccent);
                      }
                    },
                  )),
          ],
        ),
      ),
    );
  }

  // ─── Shared Helpers ───────────────────────────────────────────────
  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16)),
    ]);
  }

  Widget _inputField(
      TextEditingController ctrl, String label, IconData icon, Color iconColor) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: iconColor, size: 20),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: iconColor, width: 1.5)),
      ),
    );
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
