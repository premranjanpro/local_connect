import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mobility Form
  final _pickupController = TextEditingController(text: 'Sindhi Camp, Jaipur');
  final _dropoffController = TextEditingController(text: 'Malviya Nagar, Jaipur');
  Map<String, dynamic>? _fareEstimate;
  Map<String, dynamic>? _activeRideTask;
  bool _isEstimating = false;

  // Grocery RFQ Form
  final _groceryPromptController = TextEditingController(text: 'Mujhe 5kg aaloo, 2kg pyaj, 1kg tomato chahiye');
  String _rfqMode = 'SingleShop'; // SingleShop, MultiShop, BroadcastNetwork
  Map<String, dynamic>? _activeRfq;

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
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  Future<void> _submitGroceryRfq() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final rfq = await ApiService.createRfq(auth.token!, {
        'mode': _rfqMode,
        'rawPrompt': _groceryPromptController.text.trim(),
        'structuredItemsJson': '[{"item":"Potato","qty":5},{"item":"Onion","qty":2},{"item":"Tomato","qty":1}]',
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
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Active Ride Dispatched!', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                Text('Pickup OTP: ${_activeRideTask!['pickupOtp']} | Dropoff OTP: ${_activeRideTask!['dropoffOtp']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                Text('Status: ${_activeRideTask!['status']}', style: const TextStyle(color: Colors.white70)),
                              ],
                            ),
                          )
                        ]
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
                        ElevatedButton.icon(
                          onPressed: _submitGroceryRfq,
                          icon: const Icon(Icons.send),
                          label: const Text('Send Requirement to Vendors'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                        ),
                        if (_activeRfq != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('RFQ ID: ${_activeRfq!['id']}', style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontFamily: 'monospace')),
                                Text('Mode: ${_activeRfq!['mode']} • Status: ${_activeRfq!['status']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        ]
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
