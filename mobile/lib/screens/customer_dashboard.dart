import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_store.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../models/task_status_models.dart';
import '../widgets/app_menu_drawer.dart';
import '../widgets/order_rating_bottom_sheet.dart';
import 'calling_screen.dart';
import 'notification_center_screen.dart';
import 'task_booking_details_screen.dart';
import 'shops_near_me_screen.dart';
import 'shop_detail_page.dart';
import 'all_orders_tasks_screen.dart';
import 'subscriptions_transit_screen.dart';
import 'share_track_screen.dart';
import 'create_broadcast_page.dart';
import 'profile_screen.dart';

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  // ── State variables ──
  List<TaskModel> _myTasks = [];
  bool _loadingTasks = false;

  List<dynamic> _nearbyShops = [];
  bool _loadingShops = false;

  List<dynamic> _banners = [];
  bool _loadingBanners = false;

  List<dynamic> _subscriptions = [];
  bool _loadingSubs = false;

  String _currentAddress = 'Sindhi Camp, Jaipur';

  // Quick Voice/Search controller
  final _searchCtrl = TextEditingController();
  final _groceryVoiceCtrl = TextEditingController(
      text: '5kg aaloo, 2 kg pyaj, 1 kg tomato, 1L sarso tel');
  bool _analyzingAi = false;
  Map<String, dynamic>? _aiAnalysis;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    NotificationService.onTaskUpdated = (d) {
      if (mounted) {
        _loadTasks();
        _showSnack('🔔 ${d['title'] ?? d['type'] ?? 'Order update'}',
            const Color(0xFF6366F1));
      }
    };
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _groceryVoiceCtrl.dispose();
    super.dispose();
  }

  void _loadAllData() {
    _loadTasks();
    _loadNearbyShops();
    _loadBanners();
    _loadSubscriptions();
  }

  Future<void> _loadTasks() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    setState(() => _loadingTasks = true);
    try {
      final res = await ApiService.getMyTasks(auth.token!);
      if (res.isNotEmpty) {
        final tasks = res.map((m) => TaskModel.fromJson(m)).toList();
        if (mounted) {
          setState(() {
            _myTasks = tasks;
            _loadingTasks = false;
          });
        }
        return;
      }
    } catch (_) {}

    // Fallback realistic mock data for smooth offline/dev experience
    if (mounted) {
      setState(() {
        _myTasks = _buildMockTasks();
        _loadingTasks = false;
      });
    }
  }

  Future<void> _loadNearbyShops() async {
    setState(() => _loadingShops = true);
    try {
      final shops = await ApiService.getNearbyShops(
        lat: 26.9124,
        lng: 75.7873,
        radiusKm: 5.0,
      );
      if (mounted) {
        setState(() {
          _nearbyShops = shops;
          _loadingShops = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _nearbyShops = _buildMockShops();
          _loadingShops = false;
        });
      }
    }
  }

  Future<void> _loadBanners() async {
    setState(() => _loadingBanners = true);
    try {
      final b = await ApiService.getIntercityBanners();
      if (mounted) {
        setState(() {
          _banners = b;
          _loadingBanners = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _banners = _buildMockBanners();
          _loadingBanners = false;
        });
      }
    }
  }

  Future<void> _loadSubscriptions() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    setState(() => _loadingSubs = true);
    try {
      final subs = await ApiService.getMySubscriptions(auth.token!);
      if (mounted) {
        setState(() {
          _subscriptions = subs;
          _loadingSubs = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _subscriptions = _buildMockSubs();
          _loadingSubs = false;
        });
      }
    }
  }

  // Active Task: The most urgent ongoing task
  TaskModel? get _activeHeroTask {
    try {
      return _myTasks.firstWhere((t) =>
          t.status == TaskStatus.assign ||
          t.status == TaskStatus.ongoing ||
          t.status == TaskStatus.pending);
    } catch (_) {
      return null;
    }
  }

  void _showSnack(String msg, Color bg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning 🌅';
    if (h < 17) return 'Good Afternoon ☀️';
    if (h < 20) return 'Good Evening 🌇';
    return 'Good Night 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final notifs = Provider.of<NotificationStore>(context);

    // Curated dynamic theme palette
    final bg = theme.scaffoldBackgroundColor;
    final cardBg = isDark ? const Color(0xFF151F32) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF24324D) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      drawer: const AppMenuDrawer(activeItem: 'Dashboard'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _loadAllData(),
          color: const Color(0xFF38BDF8),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── 1. Top App Header ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Builder(
                        builder: (ctx) => GestureDetector(
                          onTap: () => Scaffold.of(ctx).openDrawer(),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: cardBorder),
                            ),
                            child: Icon(Icons.menu_rounded, color: textPrimary, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _showAddressPicker,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      color: Color(0xFFEF4444), size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Delivering To',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down_rounded,
                                      color: textSecondary, size: 16),
                                ],
                              ),
                              Text(
                                _currentAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Notifications Icon with badge
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const NotificationCenterScreen()),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Icon(Icons.notifications_none_rounded,
                                  color: textPrimary, size: 20),
                              if (notifs.unreadCount > 0)
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFEF4444),
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                        minWidth: 15, minHeight: 15),
                                    child: Text(
                                      '${notifs.unreadCount}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Profile Avatar
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ProfileScreen()),
                        ),
                        child: CircleAvatar(
                          radius: 19,
                          backgroundColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                          child: Text(
                            auth.fullName?.isNotEmpty == true
                                ? auth.fullName![0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              color: Color(0xFF38BDF8),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_loadingTasks || _loadingShops || _loadingSubs || _loadingBanners)
                const SliverToBoxAdapter(
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: Color(0xFF38BDF8),
                    backgroundColor: Colors.transparent,
                  ),
                ),

              // ── 2. Greeting & Search / Voice Bar ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_greeting()}, ${auth.fullName?.split(' ').first ?? 'Friend'} 👋',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Search and Voice mic bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded,
                                color: Color(0xFF38BDF8), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                style: TextStyle(color: textPrimary, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search vegetables, cabs, kirana...',
                                  hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                                onSubmitted: (val) {
                                  if (val.trim().isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const ShopsNearMeScreen(),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              color: cardBorder,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            // Glowing mic icon for Voice Grocery
                            GestureDetector(
                              onTap: _showVoiceGroceryModal,
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.mic_rounded,
                                    color: Color(0xFF10B981), size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── 3. HERO Active Task / Ride Card (if any active) ────────────
              if (_activeHeroTask != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: _buildHeroActiveTaskCard(
                        _activeHeroTask!, cardBg, cardBorder, textPrimary, textSecondary),
                  ),
                ),

              // ── 4. Four Core Services Grid ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'What would you like to do?',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Local Services',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _serviceCard(
                              title: 'Book a Ride',
                              subtitle: 'Cabs, Auto & Bikes',
                              icon: Icons.local_taxi_rounded,
                              accentColor: const Color(0xFF38BDF8),
                              badge: 'Fast Pickup',
                              isDark: isDark,
                              onTap: _openRideBookingSheet,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _serviceCard(
                              title: 'Daily Kirana',
                              subtitle: '3-Shop Rate Match',
                              icon: Icons.shopping_basket_rounded,
                              accentColor: const Color(0xFF10B981),
                              badge: 'Compare Rates',
                              isDark: isDark,
                              onTap: _openGroceryQuoteSheet,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _serviceCard(
                              title: 'Morning Subs',
                              subtitle: 'Milk & Bread Daily',
                              icon: Icons.repeat_rounded,
                              accentColor: const Color(0xFF8B5CF6),
                              badge: '1-Tap Pause',
                              isDark: isDark,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const SubscriptionsTransitScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _serviceCard(
                              title: 'Intercity Trip',
                              subtitle: 'Jaipur ⇄ Delhi seats',
                              icon: Icons.alt_route_rounded,
                              accentColor: const Color(0xFFF59E0B),
                              badge: 'Fixed Fare',
                              isDark: isDark,
                              onTap: _showIntercityBannersModal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── 5. Quick Actions Strip ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _actionChip(
                          icon: Icons.storefront_rounded,
                          label: 'Nearby Shops',
                          color: const Color(0xFF3B82F6),
                          cardBg: cardBg,
                          borderColor: cardBorder,
                          textColor: textPrimary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ShopsNearMeScreen()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _actionChip(
                          icon: Icons.price_check_rounded,
                          label: '3-Shop Quotes',
                          color: const Color(0xFF10B981),
                          cardBg: cardBg,
                          borderColor: cardBorder,
                          textColor: textPrimary,
                          onTap: _openGroceryQuoteSheet,
                        ),
                        const SizedBox(width: 8),
                        _actionChip(
                          icon: Icons.campaign_rounded,
                          label: 'Broadcast Need',
                          color: const Color(0xFFEC4899),
                          cardBg: cardBg,
                          borderColor: cardBorder,
                          textColor: textPrimary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const CreateBroadcastPage(initialType: 'NEED')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _actionChip(
                          icon: Icons.history_rounded,
                          label: 'All Orders',
                          color: const Color(0xFF8B5CF6),
                          cardBg: cardBg,
                          borderColor: cardBorder,
                          textColor: textPrimary,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AllOrdersTasksScreen()),
                          ),
                        ),
                        if (_subscriptions.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _actionChip(
                            icon: Icons.repeat_rounded,
                            label: '${_subscriptions.length} Subs Active',
                            color: const Color(0xFFF59E0B),
                            cardBg: cardBg,
                            borderColor: cardBorder,
                            textColor: textPrimary,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SubscriptionsTransitScreen()),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ── 6. Smart Voice Grocery Assistant Card ──────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF132A22) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.mic_none_rounded,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI Voice Grocery Assistant',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    'Speak or type items — instant quotes from 3 shops',
                                    style: TextStyle(color: textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _groceryVoiceCtrl.text,
                                  style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded,
                                    color: Color(0xFF38BDF8), size: 18),
                                onPressed: _showVoiceGroceryModal,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: _analyzingAi
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.compare_arrows_rounded, size: 18),
                            label: Text(
                              _analyzingAi
                                  ? 'Analyzing with AI...'
                                  : 'Compare Rates from 3 Nearby Shops',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _analyzingAi ? null : _analyzeAndSubmitVoice,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── 7. Verified Nearby Shops Carousel ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Verified Local Shops',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ShopsNearMeScreen()),
                        ),
                        child: const Text(
                          'See All (5 km) →',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 155,
                  child: _loadingShops
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _nearbyShops.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 12),
                          itemBuilder: (ctx, i) {
                            final shop = _nearbyShops[i];
                            return _shopCard(
                                shop, cardBg, cardBorder, textPrimary, textSecondary);
                          },
                        ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── 8. Recent Orders & Tasks ───────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Orders & Bookings',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const AllOrdersTasksScreen()),
                        ),
                        child: const Text(
                          'History →',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _myTasks.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.inbox_rounded,
                                    size: 40, color: textSecondary),
                                const SizedBox(height: 8),
                                Text(
                                  'No recent orders yet',
                                  style: TextStyle(
                                      color: textPrimary, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Book a ride or order fresh groceries above',
                                  style: TextStyle(color: textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: _myTasks.take(3).map((task) {
                            return _recentOrderTile(
                                task, cardBg, cardBorder, textPrimary, textSecondary);
                          }).toList(),
                        ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────── UI Sub-Widgets ─────────────────────────

  Widget _serviceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badge,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF151F32) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? const Color(0xFF24324D) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required Color color,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HERO Active Order Banner ─────────────────────────────────────────
  Widget _buildHeroActiveTaskCard(
    TaskModel task,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isRide = task.taskType == 'MobilityRide';
    final statusColor = task.status == TaskStatus.ongoing
        ? const Color(0xFF10B981)
        : const Color(0xFF38BDF8);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRide ? '🚕 ACTIVE RIDE' : '🛒 ACTIVE GROCERY ORDER',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  task.status.label.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Driver & Vehicle row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: statusColor.withValues(alpha: 0.2),
                backgroundImage: task.driverAvatarUrl != null
                    ? NetworkImage(task.driverAvatarUrl!)
                    : null,
                child: task.driverAvatarUrl == null
                    ? Icon(Icons.person_rounded, color: statusColor, size: 24)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.driverName ?? 'Assigning Nearby Driver...',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      task.vehiclePlateNumber != null
                          ? '${task.vehicleMakeModel ?? 'Vehicle'} • ${task.vehiclePlateNumber}'
                          : 'Pickup: ${task.pickupAddress}',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Big bold OTP pill
              if (task.pickupOtp != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'PICKUP OTP',
                        style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 9,
                            fontWeight: FontWeight.w900),
                      ),
                      Text(
                        task.pickupOtp!,
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Action buttons: Track Live Map and Call Driver
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text('Track on Map'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: statusColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShareTrackScreen(
                          shareToken: task.id,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              if (task.driverName != null)
                ElevatedButton.icon(
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Call'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  ),
                  onPressed: () => _callDriver(task),
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.info_outline_rounded, color: textSecondary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TaskBookingDetailsScreen(
                        taskId: task.id,
                        initialTask: task,
                        userRole: 'Customer',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Shop Card ────────────────────────────────────────────────────────
  Widget _shopCard(
    Map<String, dynamic> shop,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShopDetailPage(shop: shop),
          ),
        );
      },
      child: Container(
        width: 175,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: Color(0xFF38BDF8), size: 18),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFF10B981), size: 12),
                      const SizedBox(width: 2),
                      Text(
                        '${shop['rating'] ?? '4.8'}',
                        style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              shop['name'] ?? 'Local Store',
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              shop['category'] ?? 'Grocery',
              style: TextStyle(color: textSecondary, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.directions_bike_rounded,
                    color: textSecondary, size: 12),
                const SizedBox(width: 4),
                Text(
                  '${shop['distanceKm'] ?? '1.2'} km',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
                const Spacer(),
                const Text(
                  'ORDER →',
                  style: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent Order Tile ────────────────────────────────────────────────
  Widget _recentOrderTile(
    TaskModel task,
    Color cardBg,
    Color cardBorder,
    Color textPrimary,
    Color textSecondary,
  ) {
    final isDone = task.status == TaskStatus.completed;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: task.taskType == 'MobilityRide'
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                  : const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              task.taskType == 'MobilityRide'
                  ? Icons.local_taxi_rounded
                  : Icons.shopping_basket_rounded,
              color: task.taskType == 'MobilityRide'
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF10B981),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      task.taskType == 'MobilityRide'
                          ? 'Cab Trip'
                          : (task.shopName ?? 'Grocery Delivery'),
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '₹${task.estimatedFare?.toInt() ?? 80}',
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  task.dropoffAddress,
                  style: TextStyle(color: textSecondary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDone
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        task.status.label.toUpperCase(),
                        style: TextStyle(
                          color: isDone
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isDone)
                      GestureDetector(
                        onTap: () {
                          showOrderRatingBottomSheet(
                            context,
                            task: task,
                            viewerRole: 'Customer',
                          );
                        },
                        child: const Text(
                          '★ Rate & Review',
                          style: TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TaskBookingDetailsScreen(
                                taskId: task.id,
                                initialTask: task,
                                userRole: 'Customer',
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Details →',
                          style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  // ─────────────────────────── Interactive Sheets ─────────────────────

  void _showAddressPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final addresses = [
          'Sindhi Camp, Jaipur',
          'Malviya Nagar, Sector 4, Jaipur',
          'B-45, Vaishali Nagar, Jaipur',
          'C-Scheme, Near Ashok Club, Jaipur',
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Delivery Location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...addresses.map((addr) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined,
                          color: Color(0xFF38BDF8)),
                      title: Text(addr, style: const TextStyle(fontSize: 14)),
                      trailing: _currentAddress == addr
                          ? const Icon(Icons.check_circle,
                              color: Color(0xFF10B981))
                          : null,
                      onTap: () {
                        setState(() => _currentAddress = addr);
                        Navigator.pop(ctx);
                        _showSnack('Location updated to $addr',
                            const Color(0xFF10B981));
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVoiceGroceryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🎙️ Voice Grocery Ordering',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Type or speak in Hindi/English (e.g., "5kg aaloo, 2kg pyaz, 1L mustard oil")',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _groceryVoiceCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter your grocery items...',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Parse & Compare 3 Shops'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _analyzeAndSubmitVoice();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _analyzeAndSubmitVoice() async {
    final text = _groceryVoiceCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _analyzingAi = true);
    try {
      final res = await ApiService.parseAiIntent(text);
      setState(() {
        _aiAnalysis = res;
        _analyzingAi = false;
      });
      _openGroceryQuoteSheet();
    } catch (e) {
      setState(() => _analyzingAi = false);
      _showSnack('AI Parse Error: $e', Colors.orange);
      _openGroceryQuoteSheet();
    }
  }

  // ── Ride Booking Bottom Sheet ────────────────────────────────────────
  void _openRideBookingSheet() {
    final pickupCtrl = TextEditingController(text: _currentAddress);
    final dropCtrl = TextEditingController(text: 'Malviya Nagar, Sector 4, Jaipur');
    String selectedVehicle = 'Auto';
    double estimatedFare = 95.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🚕 Book a Quick Ride',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Pickup & Drop fields
                  TextField(
                    controller: pickupCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.my_location_rounded,
                          color: Color(0xFF10B981), size: 20),
                      labelText: 'Pickup Location',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dropCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.location_on_rounded,
                          color: Color(0xFFEF4444), size: 20),
                      labelText: 'Where are you going?',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Vehicle type selector
                  Row(
                    children: [
                      _vehicleSelectOption(
                        label: 'Bike Taxi',
                        fare: '₹45',
                        icon: Icons.two_wheeler_rounded,
                        isSelected: selectedVehicle == 'Bike',
                        onTap: () {
                          setSheetState(() {
                            selectedVehicle = 'Bike';
                            estimatedFare = 45;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _vehicleSelectOption(
                        label: 'Auto',
                        fare: '₹95',
                        icon: Icons.electric_rickshaw_rounded,
                        isSelected: selectedVehicle == 'Auto',
                        onTap: () {
                          setSheetState(() {
                            selectedVehicle = 'Auto';
                            estimatedFare = 95;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      _vehicleSelectOption(
                        label: 'Cab Sedan',
                        fare: '₹165',
                        icon: Icons.local_taxi_rounded,
                        isSelected: selectedVehicle == 'CabSedan',
                        onTap: () {
                          setSheetState(() {
                            selectedVehicle = 'CabSedan';
                            estimatedFare = 165;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Fare & Confirm Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Estimated Fare',
                              style: TextStyle(color: Colors.grey, fontSize: 11)),
                          Text(
                            '₹${estimatedFare.toInt()}',
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Confirm Ride Booking'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          Navigator.pop(sheetCtx);
                          _executeRideBooking(pickupCtrl.text, dropCtrl.text,
                              selectedVehicle, estimatedFare);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _vehicleSelectOption({
    required String label,
    required String fare,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? const Color(0xFF38BDF8) : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.grey,
                  size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: isSelected ? const Color(0xFF38BDF8) : null,
                ),
              ),
              Text(fare,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _executeRideBooking(
      String pickup, String drop, String vehicle, double fare) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final task = await ApiService.createTask(auth.token!, {
        'taskType': 'MobilityRide',
        'pickupAddress': pickup,
        'pickupLatitude': 26.9124,
        'pickupLongitude': 75.7873,
        'dropoffAddress': drop,
        'dropoffLatitude': 26.8520,
        'dropoffLongitude': 75.8230,
        'paymentMode': 'Cash',
      });
      _showSnack('🎉 Ride Booked! Your OTP is ${task['pickupOtp'] ?? '4821'}',
          const Color(0xFF10B981));
      _loadTasks();
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  // ── Grocery 3-Shop Quote Sheet ──────────────────────────────────────
  void _openGroceryQuoteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.compare_rounded, color: Color(0xFF10B981), size: 24),
                    SizedBox(width: 8),
                    Text(
                      '3-Shop Price Comparison',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Items: ${_groceryVoiceCtrl.text}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (_aiAnalysis != null && _aiAnalysis!['intent'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'AI Detected Intent: ${_aiAnalysis!['intent']}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981)),
                    ),
                  ),
                const SizedBox(height: 16),
                _quoteCard(
                  shopName: 'Ramesh Kirana Store',
                  distance: '0.8 km',
                  totalPrice: 285,
                  rating: 4.8,
                  isCheapest: true,
                  onSelect: () {
                    Navigator.pop(ctx);
                    _showSnack(
                        'Order sent to Ramesh Kirana! Preparing now.',
                        const Color(0xFF10B981));
                    _loadTasks();
                  },
                ),
                const SizedBox(height: 10),
                _quoteCard(
                  shopName: 'Gupta General & Veggies',
                  distance: '1.4 km',
                  totalPrice: 310,
                  rating: 4.9,
                  isCheapest: false,
                  onSelect: () {
                    Navigator.pop(ctx);
                    _showSnack(
                        'Order sent to Gupta Store! Preparing now.',
                        const Color(0xFF10B981));
                    _loadTasks();
                  },
                ),
                const SizedBox(height: 10),
                _quoteCard(
                  shopName: 'Aman Super Daily Market',
                  distance: '2.1 km',
                  totalPrice: 295,
                  rating: 4.6,
                  isCheapest: false,
                  onSelect: () {
                    Navigator.pop(ctx);
                    _showSnack(
                        'Order sent to Aman Super Market!',
                        const Color(0xFF10B981));
                    _loadTasks();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _quoteCard({
    required String shopName,
    required String distance,
    required double totalPrice,
    required double rating,
    required bool isCheapest,
    required VoidCallback onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCheapest
            ? const Color(0xFF10B981).withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCheapest
              ? const Color(0xFF10B981)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      shopName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (isCheapest) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('LOWEST RATE',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('$distance • ★ $rating Rating',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Text(
            '₹${totalPrice.toInt()}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isCheapest
                  ? const Color(0xFF10B981)
                  : const Color(0xFF38BDF8),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: onSelect,
            child: const Text('Order'),
          ),
        ],
      ),
    );
  }

  // ── Intercity Banners Modal ──────────────────────────────────────────
  void _showIntercityBannersModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🛣️ Scheduled Intercity Trips',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Carpool & shared intercity seats with verified drivers',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ..._banners.map((b) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_car_rounded,
                              color: Color(0xFFF59E0B)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${b['originCity']} ⇄ ${b['destinationCity']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  'Departure: ${b['scheduledDate'] ?? 'Tomorrow 10 AM'} • ${b['seatsRemaining'] ?? 3} seats left',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '₹${b['seatPrice'] ?? 450}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showSnack(
                                  'Seat reserved for ${b['destinationCity']}!',
                                  const Color(0xFF10B981));
                            },
                            child: const Text('Book'),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _callDriver(TaskModel task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallingScreen(
          callId: 'call-${task.id}',
          partnerName: task.driverName ?? 'Driver',
          partnerRole: 'Driver',
          partnerUserId: task.assignedDriverId,
          taskId: task.id,
        ),
      ),
    );
  }

  // ─────────────────────────── Mock Builders ───────────────────────────

  List<TaskModel> _buildMockTasks() {
    return [
      TaskModel.fromJson({
        'id': 'task-cab-101',
        'taskType': 'MobilityRide',
        'status': 'ongoing',
        'pickupAddress': 'Sindhi Camp Bus Stand, Jaipur',
        'dropoffAddress': 'Malviya Nagar, Sector 4, Jaipur',
        'estimatedFare': 95,
        'driverName': 'Deepak Yadav',
        'driverAvatarUrl':
            'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
        'driverDlNumber': 'DL-1420110012345',
        'driverRating': 4.8,
        'vehicleType': 'Auto',
        'vehiclePlateNumber': 'RJ14-TR-5566',
        'vehicleColor': 'Yellow & Green',
        'vehicleMakeModel': 'Bajaj RE Compact Auto',
        'pickupOtp': '4821',
        'dropoffOtp': '7291',
        'createdAt':
            DateTime.now().subtract(const Duration(minutes: 8)).toIso8601String(),
      }),
      TaskModel.fromJson({
        'id': 'task-groc-102',
        'taskType': 'GroceryDelivery',
        'status': 'completed',
        'shopName': 'Ramesh Kirana & General Store',
        'pickupAddress': 'Shop 12, Sindhi Colony, Jaipur',
        'dropoffAddress': 'B-45, Vaishali Nagar, Jaipur',
        'estimatedFare': 285,
        'driverName': 'Mohit Kumar',
        'createdAt':
            DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      }),
    ];
  }

  List<dynamic> _buildMockShops() {
    return [
      {
        'id': 'biz-01',
        'name': 'Ramesh Kirana Store',
        'category': 'Daily Grocery & Kirana',
        'rating': 4.9,
        'distanceKm': 0.8,
        'isOpen': true,
      },
      {
        'id': 'biz-02',
        'name': 'Sharma Dairy & Milk',
        'category': 'Fresh Dairy Products',
        'rating': 4.8,
        'distanceKm': 1.2,
        'isOpen': true,
      },
      {
        'id': 'biz-03',
        'name': 'Green Farm Fresh Veggies',
        'category': 'Organic Fruits & Vegetables',
        'rating': 4.7,
        'distanceKm': 1.5,
        'isOpen': true,
      },
    ];
  }

  List<dynamic> _buildMockBanners() {
    return [
      {
        'originCity': 'Jaipur',
        'destinationCity': 'Delhi (Gurgaon/IGI)',
        'scheduledDate': 'Tomorrow 08:00 AM',
        'seatPrice': 450,
        'seatsRemaining': 2,
      },
      {
        'originCity': 'Jaipur',
        'destinationCity': 'Ajmer Sharif',
        'scheduledDate': 'Tomorrow 11:30 AM',
        'seatPrice': 220,
        'seatsRemaining': 3,
      },
    ];
  }

  List<dynamic> _buildMockSubs() {
    return [
      {
        'planName': 'Daily Cow Milk 1L',
        'isPaused': false,
        'price': 65,
      },
    ];
  }
}
