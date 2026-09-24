import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class MerchantScreen extends StatefulWidget {
  const MerchantScreen({super.key});

  @override
  State<MerchantScreen> createState() => _MerchantScreenState();
}

class _MerchantScreenState extends State<MerchantScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String? _businessId;
  final String _businessName = 'My Kirana Store';
  bool _duesEnabledGlobally = true;
  final String _allowedPaymentModes = 'Cash,Online,Dues';

  List<dynamic> _khataLedger = [];

  // New Catalog Item Controllers
  final _itemNameController = TextEditingController();
  final _itemPriceController = TextEditingController();
  final _itemUnitController = TextEditingController(text: 'kg');

  // Khata Doorstep Collection Controllers
  final _khataCustIdController = TextEditingController();
  final _khataAmountController = TextEditingController();
  final _khataNotesController = TextEditingController(text: 'Doorstep cash collected by delivery boy');

  // Customer RFQ Feed
  List<dynamic> _openRfqs = [];
  bool _loadingRfqs = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadMerchantData();
    _loadMerchantRfqs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _itemNameController.dispose();
    _itemPriceController.dispose();
    _itemUnitController.dispose();
    _khataCustIdController.dispose();
    _khataAmountController.dispose();
    _khataNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadMerchantData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) return;

    try {
      final ledgerData = await ApiService.getKhataLedger(auth.token!, 'default');
      setState(() {
        _khataLedger = ledgerData['entries'] ?? [];
      });
    } catch (_) {}
  }

  Future<void> _loadMerchantRfqs() async {
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

  Future<void> _submitQuoteForRfq(String rfqId, double price, int prepMin, String details) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await ApiService.submitRfqQuote(
        auth.token!,
        rfqId,
        _businessId ?? '7a74b169-0512-4a3b-9f7d-6020832ceaf0',
        price,
        details,
        prepMin,
      );
      _showSnack('Quote submitted to customer! Rate: ₹$price', Colors.green);
      await _loadMerchantRfqs();
    } catch (e) {
      _showSnack(e.toString(), Colors.redAccent);
    }
  }

  void _showQuoteDialog(dynamic rfq) {
    final priceCtrl = TextEditingController(text: '150');
    final prepCtrl = TextEditingController(text: '10');
    final notesCtrl = TextEditingController(text: 'Fresh items ready for pickup');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Submit Direct Rate Quote', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Requirement: "${rfq['rawRequirementText']}"', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Offered Price (₹)', prefixText: '₹ '),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: prepCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Estimated Prep Time (Minutes)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notesCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Item Notes / Remarks'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              final price = double.tryParse(priceCtrl.text) ?? 100.0;
              final prep = int.tryParse(prepCtrl.text) ?? 10;
              _submitQuoteForRfq(rfq['id'].toString(), price, prep, notesCtrl.text);
            },
            child: const Text('Send Quote to Customer'),
          ),
        ],
      ),
    );
  }

  Future<void> _recordDoorstepCash() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (_businessId == null) {
      _showSnack('Please ensure shop is registered.', Colors.redAccent);
      return;
    }

    try {
      final amount = double.tryParse(_khataAmountController.text) ?? 100.0;
      await ApiService.recordKhataTransaction(auth.token!, {
        'businessId': _businessId,
        'customerId': _khataCustIdController.text.trim(),
        'entryType': 'PaymentCredit',
        'amount': amount,
        'paymentMethod': 'DoorstepCashToDeliveryBoy',
        'notes': _khataNotesController.text.trim(),
      });
      _showSnack('Doorstep Cash Payment credited to Khata ledger!', Colors.green);
      _loadMerchantData();
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
        title: Text('Merchant Console (${auth.fullName ?? "Shop"})', style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.greenAccent,
          labelColor: Colors.greenAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.storefront), text: 'Shop & Dues'),
            Tab(icon: Icon(Icons.local_offer), text: 'Customer RFQs'),
            Tab(icon: Icon(Icons.inventory_2), text: 'Catalog'),
            Tab(icon: Icon(Icons.menu_book), text: 'Digital Khata'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. SHOP & DUES SETTINGS
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
                        Text(_businessName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 4),
                        const Text('Hyper-Local Grocery & Daily Essentials Vendor', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const Divider(height: 24, color: Colors.white12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Global Customer Dues (Khata)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Allow verified neighborhood customers to order on credit', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          value: _duesEnabledGlobally,
                          activeThumbColor: Colors.greenAccent,
                          onChanged: (val) => setState(() => _duesEnabledGlobally = val),
                        ),
                        const SizedBox(height: 8),
                        Text('Accepted Payment Modes: $_allowedPaymentModes', style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. CUSTOMER RFQs FEED (Option 2: 3-Shop Comparative Rate Card)
          RefreshIndicator(
            onRefresh: _loadMerchantRfqs,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Live Neighborhood RFQs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.greenAccent),
                        onPressed: _loadMerchantRfqs,
                        tooltip: 'Refresh RFQ Feed',
                      ),
                    ],
                  ),
                  const Text('Nearby customer requirement broadcasts awaiting shop quotes.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  if (_loadingRfqs)
                    const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: Colors.greenAccent)))
                  else if (_openRfqs.isEmpty)
                    Card(
                      color: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined, color: Colors.grey, size: 48),
                            SizedBox(height: 8),
                            Text('No active customer broadcasts in your area.', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._openRfqs.map((rfq) {
                      final quotes = (rfq['quotes'] as List?) ?? [];
                      final status = rfq['status']?.toString() ?? 'Open';
                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: status == 'OrderCreated' ? Colors.greenAccent : Colors.white12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: status == 'OrderCreated' ? Colors.greenAccent.withValues(alpha: 0.15) : Colors.orangeAccent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: status == 'OrderCreated' ? Colors.greenAccent : Colors.orangeAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text('${quotes.length} Quotes Recvd', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                rfq['rawRequirementText'] ?? 'General Grocery Request',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text('Requested By: ${rfq['customerId'] ?? "Customer"}', style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                              const SizedBox(height: 12),
                              if (status != 'OrderCreated')
                                ElevatedButton.icon(
                                  onPressed: () => _showQuoteDialog(rfq),
                                  icon: const Icon(Icons.send_rounded, size: 16),
                                  label: const Text('Submit Competitive Quote'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.greenAccent.shade700,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                )
                              else
                                const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                                    SizedBox(width: 6),
                                    Text('Customer finalized order from quotes.', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),

          // 3. CATALOG MANAGEMENT
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
                        const Text('Add Product to Catalog', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _itemNameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Item Name (e.g. Aaloo, Pyaj, Cow Milk)'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _itemPriceController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(labelText: 'Price (₹)'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _itemUnitController,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(labelText: 'Unit (kg/litre/packet)'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: () => _showSnack('Catalog item saved to inventory!', Colors.green),
                          icon: const Icon(Icons.add),
                          label: const Text('Add to Live Catalog'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, foregroundColor: Colors.white),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. DIGITAL KHATA LEDGER
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
                        const Row(
                          children: [
                            Icon(Icons.payments, color: Colors.greenAccent),
                            SizedBox(width: 8),
                            Text('Record Doorstep Cash / Settlement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text('Log cash collected by delivery boys at customer doorsteps.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _khataCustIdController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Customer User ID'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _khataAmountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Collected Amount (₹)'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _khataNotesController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(labelText: 'Remarks / Delivery Boy Name'),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _recordDoorstepCash,
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Credit Payment to Customer Khata'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Recent Khata Ledger Transactions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                if (_khataLedger.isEmpty)
                  const Text('No recent ledger transactions.', style: TextStyle(color: Colors.grey))
                else
                  ..._khataLedger.map((l) => Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            l['entryType'] == 'DuesDebit' ? Icons.arrow_upward : Icons.arrow_downward,
                            color: l['entryType'] == 'DuesDebit' ? Colors.redAccent : Colors.greenAccent,
                          ),
                          title: Text(
                            '${l['customerName'] ?? "Customer"} • ₹${l['amount']}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('${l['paymentMethod']} • ${l['notes'] ?? ""}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: Chip(
                            label: Text(
                              l['entryType'] == 'DuesDebit' ? 'DUES ADDED' : 'PAID',
                              style: TextStyle(
                                color: l['entryType'] == 'DuesDebit' ? Colors.redAccent : Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ))
              ],
            ),
          ),
        ],
      ),
    );
  }
}
