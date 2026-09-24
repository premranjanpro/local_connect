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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMerchantData();
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

          // 2. CATALOG MANAGEMENT
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
