import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/live_tracking_map_widget.dart';
import 'calling_screen.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mobility Form & Live Tracking
  final _pickupController = TextEditingController(text: 'Sindhi Camp, Jaipur');
  final _dropoffController = TextEditingController(text: 'Malviya Nagar, Jaipur');
  Map<String, dynamic>? _fareEstimate;
  Map<String, dynamic>? _activeRideTask;
  bool _isEstimating = false;

  // Grocery RFQ & AI Form & 3-Shop Comparative Quotes
  final _groceryPromptController = TextEditingController(text: 'Mujhe 5kg aaloo, 2 kg pyag, 1 kg tomato chahiye apne shopkeeper ko bhej diya');
  String _rfqMode = 'SingleShop'; // SingleShop, MultiShop, BroadcastNetwork
  Map<String, dynamic>? _activeRfq;
  Map<String, dynamic>? _aiAnalysis;
  bool _isAnalyzingAi = false;
  List<dynamic> _rfqQuotes = [];
  bool _loadingQuotes = false;

  // Intercity Route Banners
  List<dynamic> _banners = [];
  bool _loadingBanners = false;

  // Subscriptions
  List<dynamic> _subscriptions = [];
  bool _loadingSubs = false;

  // Social & Classifieds
  List<dynamic> _meetups = [];
  List<dynamic> _classifieds = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSubscriptions();
    _loadSocialData();
    _loadBanners();

    NotificationService.onTaskUpdated = (taskData) {
      if (mounted) {
        _loadSubscriptions();
        _loadBanners();
        if (_activeRfq != null) {
          _loadRfqQuotes();
        }
        _showSnack('🔔 Real-time Update: ${taskData['type'] ?? "Order update"}', Colors.indigoAccent);
      }
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    _groceryPromptController.dispose();
    super.dispose();
  }

  Future<void> _estimateRide() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isEstimating = true);
    try {
      final res = await ApiService.estimateTask(
        auth.token ?? '',
        26.9200, 75.7900,
        26.8500, 75.8200,
        'MobilityRide',
      );
      setState(() {
        _fareEstimate = res;
        _isEstimating = false;
      });
    } catch (e) {
      setState(() => _isEstimating = false);
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _bookRide() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final task = await ApiService.createTask(auth.token!, {
        'taskType': 'MobilityRide',
        'pickupAddress': _pickupController.text.trim(),
        'pickupLatitude': 26.9200,
        'pickupLongitude': 75.7900,
        'dropoffAddress': _dropoffController.text.trim(),
        'dropoffLatitude': 26.8500,
        'dropoffLongitude': 75.8200,
        'paymentMode': 'Cash',
      });
      setState(() => _activeRideTask = task);
      _showSnack('Ride booked! Pickup OTP: ${task['pickupOtp']}', Colors.green);
      NotificationService.showOngoingOrderNotification(
        id: 101,
        title: '🚗 Driver En Route • OTP: ${task['pickupOtp']}',
        body: 'Driver assigned! Head to pickup spot: ${_pickupController.text.trim()}',
      );
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _analyzeWithAi() async {
    final query = _groceryPromptController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isAnalyzingAi = true);
    try {
      final res = await ApiService.parseAiIntent(query);
      setState(() {
        _aiAnalysis = res;
        _isAnalyzingAi = false;
        if (res['target_mode'] == 'THREE_SHOPS') {
          _rfqMode = 'MultiShop';
        } else if (res['target_mode'] == 'SINGLE_SHOP') {
          _rfqMode = 'SingleShop';
        } else if (res['target_mode'] == 'BROADCAST' || res['target_mode'] == 'OPEN_NETWORK') {
          _rfqMode = 'BroadcastNetwork';
        }
      });
      _showSnack(res['reply_message'] ?? 'AI analyzed your list!', Colors.indigoAccent);
    } catch (e) {
      setState(() => _isAnalyzingAi = false);
      _showSnack('AI Agent ready on port 8000: ${e.toString()}', Colors.orange);
    }
  }

  Future<void> _submitGroceryRfq() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      String structuredJson = '[{"item":"Potato","qty":5},{"item":"Onion","qty":2},{"item":"Tomato","qty":1}]';
      if (_aiAnalysis != null && _aiAnalysis!['items'] != null && (_aiAnalysis!['items'] as List).isNotEmpty) {
        structuredJson = jsonEncode(_aiAnalysis!['items']);
      }
      final rfq = await ApiService.createRfq(auth.token!, {
        'mode': _rfqMode,
        'rawPrompt': _groceryPromptController.text.trim(),
        'structuredItemsJson': structuredJson,
        'deliveryAddress': 'Flat 402, Royal Palms, Jaipur',
        'deliveryLatitude': 26.8520,
        'deliveryLongitude': 75.8230,
      });
      setState(() => _activeRfq = rfq);
      _showSnack('Grocery request broadcasted to $_rfqMode network!', Colors.blueAccent);
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _loadSubscriptions() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;
    setState(() => _loadingSubs = true);
    try {
      final subs = await ApiService.getMySubscriptions(auth.token!);
      setState(() {
        _subscriptions = subs;
        _loadingSubs = false;
      });
    } catch (_) {
      setState(() => _loadingSubs = false);
    }
  }

  Future<void> _toggleVacationMode(String subId, bool currentPaused) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      if (currentPaused) {
        await ApiService.resumeSubscription(auth.token!, subId);
        _showSnack('Vacation pause cancelled. Deliveries resumed!', Colors.green);
      } else {
        final now = DateTime.now();
        final start = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        final endDt = now.add(const Duration(days: 5));
        final end = '${endDt.year}-${endDt.month.toString().padLeft(2, '0')}-${endDt.day.toString().padLeft(2, '0')}';
        await ApiService.pauseSubscription(auth.token!, subId, start, end, 'Vacation Mode');
        _showSnack('Vacation Mode active: Deliveries paused for 5 days.', Colors.amber);
      }
      await _loadSubscriptions();
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _loadSocialData() async {
    try {
      final m = await ApiService.getSocialMeetups();
      final c = await ApiService.getClassifieds();
      setState(() {
        _meetups = m;
        _classifieds = c;
      });
    } catch (_) {}
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

  Future<void> _bookBannerSeat(String bannerId, String fromCity, String toCity, double price) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await ApiService.bookBannerSeat(auth.token!, bannerId, 1);
      _showSnack('Seat booked for $fromCity -> $toCity! Pickup OTP: ${res['pickupOtp']}', Colors.green);
      await _loadBanners();
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
      _showSnack('Updated quotes from neighborhood shops!', Colors.blueAccent);
    } catch (e) {
      setState(() => _loadingQuotes = false);
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _acceptQuote(String quoteId, String shopName, double price, String paymentMode) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await ApiService.acceptRfqQuote(auth.token!, _activeRfq!['id'], quoteId, paymentMode);
      _showSnack('Quote accepted from $shopName! Grocery delivery dispatched.', Colors.green);
      await _loadRfqQuotes();
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  void _showSnack(String msg, Color bg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: bg));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Text('Customer Hub (${auth.fullName ?? "User"})', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          isScrollable: true,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.local_taxi), text: 'Rides'),
            Tab(icon: Icon(Icons.shopping_basket), text: 'Grocery RFQ'),
            Tab(icon: Icon(Icons.repeat), text: 'Daily Morning'),
            Tab(icon: Icon(Icons.people_outline), text: 'Community & Social'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. RIDES TAB
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Book Mobility Ride', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _pickupController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Pickup Location', prefixIcon: Icon(Icons.my_location, color: Colors.greenAccent)),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _dropoffController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Dropoff Destination', prefixIcon: Icon(Icons.pin_drop, color: Colors.redAccent)),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _isEstimating ? null : _estimateRide,
                          icon: const Icon(Icons.calculate),
                          label: const Text('Calculate Fare (Haversine 1.30x)'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                        ),
                        if (_fareEstimate != null) ...[
                          const Divider(height: 24, color: Colors.white24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${_fareEstimate!['distanceKm']} km • ${_fareEstimate!['durationMinutes']} mins', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                  Text('Engine: ${_fareEstimate!['provider']}', style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
                                ],
                              ),
                              Text('₹${_fareEstimate!['estimatedFare']}', style: const TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _bookRide,
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, foregroundColor: Colors.white),
                            child: const Text('Confirm Ride Booking'),
                          )
                        ],
                        if (_activeRideTask != null) ...[
                          const SizedBox(height: 16),
                          LiveTrackingMapWidget(
                            pickupLat: (_activeRideTask!['pickupLatitude'] as num?)?.toDouble() ?? 26.9200,
                            pickupLng: (_activeRideTask!['pickupLongitude'] as num?)?.toDouble() ?? 75.7900,
                            dropoffLat: (_activeRideTask!['dropoffLatitude'] as num?)?.toDouble() ?? 26.8500,
                            dropoffLng: (_activeRideTask!['dropoffLongitude'] as num?)?.toDouble() ?? 75.8200,
                            initialDriverLat: 26.9150,
                            initialDriverLng: 75.7950,
                            status: _activeRideTask!['status'] ?? 'En Route',
                            otp: _activeRideTask!['pickupOtp']?.toString(),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Active Ride Dispatched & Tracked Live!', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('Pickup OTP: ${_activeRideTask!['pickupOtp']} | Dropoff OTP: ${_activeRideTask!['dropoffOtp']}',
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('Status: ${_activeRideTask!['status']}', style: const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CallingScreen(
                                          partnerUserId: _activeRideTask!['assignedDriverId'] ?? '7a74b169-0512-4a3b-9f7d-6020832ceaf0',
                                          partnerName: 'Assigned Driver',
                                          partnerRole: 'Driver',
                                          taskId: _activeRideTask!['id'],
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.call, size: 16),
                                  label: const Text('Call Driver (VoIP)'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.greenAccent.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. GROCERY RFQ TAB
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('AI & Multi-Shop Grocery Request', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text('Request vegetables, grocery items via natural Hindi/English prompt.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _groceryPromptController,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'e.g. 5kg aaloo, 2kg pyaj, 1kg tomato...',
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFF334155),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Select Request Mode:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('1 Shop Only'),
                              selected: _rfqMode == 'SingleShop',
                              selectedColor: Colors.blueAccent,
                              onSelected: (_) => setState(() => _rfqMode = 'SingleShop'),
                            ),
                            ChoiceChip(
                              label: const Text('Compare 3 Shops'),
                              selected: _rfqMode == 'MultiShop',
                              selectedColor: Colors.blueAccent,
                              onSelected: (_) => setState(() => _rfqMode = 'MultiShop'),
                            ),
                            ChoiceChip(
                              label: const Text('Network Broadcast'),
                              selected: _rfqMode == 'BroadcastNetwork',
                              selectedColor: Colors.blueAccent,
                              onSelected: (_) => setState(() => _rfqMode = 'BroadcastNetwork'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isAnalyzingAi ? null : _analyzeWithAi,
                                icon: _isAnalyzingAi
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent))
                                    : const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                                label: Text(_isAnalyzingAi ? 'Analyzing...' : 'Parse with AI', style: const TextStyle(color: Colors.purpleAccent)),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.purpleAccent)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _submitGroceryRfq,
                                icon: const Icon(Icons.send),
                                label: const Text('Send Order/RFQ'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        if (_aiAnalysis != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1B4B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.psychology, color: Colors.purpleAccent, size: 18),
                                    const SizedBox(width: 6),
                                    Text('AI Intent: ${_aiAnalysis!['intent_type']}', style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const Spacer(),
                                    Chip(
                                      label: Text(_aiAnalysis!['target_mode'] ?? 'OPEN', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                      backgroundColor: Colors.purple.shade900,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(_aiAnalysis!['reply_message'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 13)),
                                if (_aiAnalysis!['items'] != null && (_aiAnalysis!['items'] as List).isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: (_aiAnalysis!['items'] as List).map<Widget>((it) {
                                      return Chip(
                                        backgroundColor: const Color(0xFF312E81),
                                        label: Text('${it['quantity']} ${it['unit']} ${it['normalized_name']}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (_activeRfq != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3))),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Mode: ${_activeRfq!['mode']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ElevatedButton.icon(
                                      onPressed: _loadingQuotes ? null : _loadRfqQuotes,
                                      icon: _loadingQuotes
                                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : const Icon(Icons.refresh, size: 14),
                                      label: const Text('Refresh Quotes', style: TextStyle(fontSize: 11)),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                                    ),
                                  ],
                                ),
                                Text('Status: ${_activeRfq!['status']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (_rfqQuotes.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Text('3-Shop Comparative Rate Card:', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            ..._rfqQuotes.map((q) {
                              final price = (q['quotedTotalPrice'] as num?)?.toDouble() ?? 0.0;
                              final prep = q['estimatedPrepMinutes'] ?? 15;
                              final shop = q['businessName'] ?? 'Kirana Store';
                              final details = q['quoteDetails'] ?? '';

                              return Card(
                                color: const Color(0xFF0F172A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.greenAccent.withValues(alpha: 0.3))),
                                margin: const EdgeInsets.only(bottom: 10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(shop, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                          Text('₹${price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 17)),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text('Ready in $prep mins • $details', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      const Divider(height: 16, color: Colors.white12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () {
                                                _acceptQuote(q['id'], shop, price, 'Cash');
                                                NotificationService.showOngoingOrderNotification(
                                                  id: 102,
                                                  title: '📦 Order Placed with $shop',
                                                  body: 'Ready in $prep mins • Total ₹${price.toStringAsFixed(0)} (Cash on Delivery)',
                                                );
                                              },
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, foregroundColor: Colors.white),
                                              child: const Text('Accept Cash'),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () {
                                                _acceptQuote(q['id'], shop, price, 'Dues');
                                                NotificationService.showOngoingOrderNotification(
                                                  id: 102,
                                                  title: '📦 Order Placed with $shop (Khata)',
                                                  body: 'Ready in $prep mins • Added to your neighborhood Khata ledger',
                                                );
                                              },
                                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber)),
                                              child: const Text('Add to Khata', style: TextStyle(color: Colors.amber)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.phone_in_talk, color: Colors.greenAccent),
                                            tooltip: 'Call $shop',
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => CallingScreen(
                                                    partnerUserId: q['businessId'] ?? '7a74b169-0512-4a3b-9f7d-6020832ceaf0',
                                                    partnerName: shop,
                                                    partnerRole: 'Shop Owner',
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. DAILY MORNING SUBSCRIPTIONS TAB
          _loadingSubs
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Daily Morning Runs (06:00 - 07:30 AM)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('Pure milk, newspaper, breakfast tiffin auto-delivered with month-end Khata billing.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      const SizedBox(height: 16),
                      if (_subscriptions.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No subscriptions active.', style: TextStyle(color: Colors.grey))))
                      else
                        ..._subscriptions.map((s) {
                          final isPaused = s['isCurrentlyPaused'] == true;
                          return Card(
                            color: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(s['itemName'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                      Chip(
                                        label: Text(isPaused ? 'VACATION PAUSED' : 'ACTIVE', style: TextStyle(color: isPaused ? Colors.white : Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                        backgroundColor: isPaused ? Colors.amber.shade800 : Colors.greenAccent,
                                      )
                                    ],
                                  ),
                                  Text('${s['quantity']} ${s['unit']} • Slot: ${s['deliverySlot']} (${s['daysOfWeek']})', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                  Text('Shop: ${s['businessName']} • Rate: ₹${s['pricePerDelivery']}/day', style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                                  const Divider(height: 20, color: Colors.white12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(isPaused ? 'Paused for Vacation' : 'Going on holiday?', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                      ElevatedButton.icon(
                                        onPressed: () => _toggleVacationMode(s['id'], isPaused),
                                        icon: Icon(isPaused ? Icons.play_arrow : Icons.pause, size: 16),
                                        label: Text(isPaused ? 'Resume Delivery' : '1-Tap 5-Day Vacation Pause'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isPaused ? Colors.green : Colors.amber.shade800,
                                          foregroundColor: Colors.white,
                                          textStyle: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ),

          // 4. COMMUNITY & SOCIAL TAB
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Intercity Route Carpools & Banners', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text('Scheduled intercity rides by verified drivers with fixed seats.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                const SizedBox(height: 10),
                if (_loadingBanners)
                  const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.indigoAccent)))
                else if (_banners.isEmpty)
                  const Text('No intercity banners active today.', style: TextStyle(color: Colors.grey))
                else
                  ..._banners.map((b) {
                    final from = b['fromCity'] ?? 'City';
                    final to = b['toCity'] ?? 'City';
                    final price = (b['expectedPrice'] as num?)?.toDouble() ?? 1500.0;
                    final seats = b['seatsAvailable'] ?? 0;
                    final driver = b['driverName'] ?? 'Driver';

                    return Card(
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.indigoAccent.withValues(alpha: 0.3))),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.alt_route, color: Colors.indigoAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Text('$from ➔ $to', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  ],
                                ),
                                Text('₹${price.toStringAsFixed(0)}/seat', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Driver: $driver • Seats Remaining: $seats', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            const Divider(height: 16, color: Colors.white12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                onPressed: seats > 0 ? () => _bookBannerSeat(b['id'], from, to, price) : null,
                                icon: const Icon(Icons.airline_seat_recline_normal, size: 16),
                                label: Text(seats > 0 ? 'Book 1 Seat (₹${price.toStringAsFixed(0)})' : 'Sold Out'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigoAccent,
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 20),
                const Text('Social Meetups & Coffee Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (_meetups.isEmpty)
                  const Text('No meetups posted yet.', style: TextStyle(color: Colors.grey))
                else
                  ..._meetups.map((m) => Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.pinkAccent, child: Icon(Icons.coffee, color: Colors.white)),
                          title: Text(m['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('${m['description']}\nAt: ${m['locationName']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: Chip(label: Text(m['category'], style: const TextStyle(fontSize: 10))),
                        ),
                      )),
                const SizedBox(height: 20),
                const Text('Hyper-Local Classifieds (Tuitions, Gigs)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (_classifieds.isEmpty)
                  const Text('No classifieds posted yet.', style: TextStyle(color: Colors.grey))
                else
                  ..._classifieds.map((c) => Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.school, color: Colors.white)),
                          title: Text(c['title'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('${c['description']}\nBudget: ₹${c['budget'] ?? "Negotiable"} • Loc: ${c['locationName']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: Chip(label: Text(c['category'], style: const TextStyle(fontSize: 10))),
                        ),
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
