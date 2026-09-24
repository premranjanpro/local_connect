import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _phoneController = TextEditingController(text: '9876543210');
  final _pinController = TextEditingController(text: '1234');

  // Register controllers
  final _regPhoneController = TextEditingController();
  final _regNameController = TextEditingController();
  final _regPinController = TextEditingController(text: '1234');
  String _selectedRole = 'Customer';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _regPhoneController.dispose();
    _regNameController.dispose();
    _regPinController.dispose();
    super.dispose();
  }

  void _quickFill(String phone, String pin) {
    _phoneController.text = phone;
    _pinController.text = pin;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Logo & Branding
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: const Icon(Icons.hub_rounded, size: 48, color: Colors.blueAccent),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ShopConnector',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Unified Mobility & Hyper-Local Commerce',
                  style: TextStyle(fontSize: 14, color: Colors.blueGrey.shade300),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Device ID: ${auth.deviceId}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 24),

                // Error Message Banner
                if (auth.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Tab Bar
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.blueAccent,
                    indicatorWeight: 3,
                    labelColor: Colors.blueAccent,
                    unselectedLabelColor: Colors.grey.shade400,
                    tabs: const [
                      Tab(text: 'Fast Login (PIN)'),
                      Tab(text: 'New Account'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Tab View
                SizedBox(
                  height: 380,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // LOGIN TAB
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Mobile Number',
                              labelStyle: TextStyle(color: Colors.grey.shade400),
                              prefixIcon: const Icon(Icons.phone, color: Colors.blueAccent),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pinController,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 18),
                            decoration: InputDecoration(
                              labelText: '4-Digit PIN (Default: 1234)',
                              counterText: '',
                              labelStyle: TextStyle(color: Colors.grey.shade400),
                              prefixIcon: const Icon(Icons.lock, color: Colors.blueAccent),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: auth.isLoading
                                ? null
                                : () => auth.login(_phoneController.text.trim(), _pinController.text.trim()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Login Instantly', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          const SizedBox(height: 20),
                          const Text('Quick Test Switcher:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _quickFill('9350065724', '1234'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.purpleAccent),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text('Admin', style: TextStyle(color: Colors.purpleAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _quickFill('9876543210', '1234'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.amber),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text('Driver', style: TextStyle(color: Colors.amber, fontSize: 11)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _quickFill('9876543211', '1234'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.greenAccent),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text('Merchant', style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _quickFill('9876543212', '1234'),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.blueAccent),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: const Text('Customer', style: TextStyle(color: Colors.blueAccent, fontSize: 11)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // REGISTER TAB
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _regPhoneController,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Mobile Number',
                              labelStyle: TextStyle(color: Colors.grey.shade400),
                              prefixIcon: const Icon(Icons.phone, color: Colors.blueAccent),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _regNameController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              labelStyle: TextStyle(color: Colors.grey.shade400),
                              prefixIcon: const Icon(Icons.person, color: Colors.blueAccent),
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedRole,
                                  dropdownColor: const Color(0xFF1E293B),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: 'Role',
                                    labelStyle: TextStyle(color: Colors.grey.shade400),
                                    filled: true,
                                    fillColor: const Color(0xFF1E293B),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                  items: ['Customer', 'Driver', 'Merchant']
                                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                      .toList(),
                                  onChanged: (val) => setState(() => _selectedRole = val!),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _regPinController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  style: const TextStyle(color: Colors.white, letterSpacing: 4),
                                  decoration: InputDecoration(
                                    labelText: '4-Digit PIN',
                                    counterText: '',
                                    labelStyle: TextStyle(color: Colors.grey.shade400),
                                    filled: true,
                                    fillColor: const Color(0xFF1E293B),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: auth.isLoading
                                ? null
                                : () => auth.register(
                                      _regPhoneController.text.trim(),
                                      _regNameController.text.trim(),
                                      _regPinController.text.trim(),
                                      _selectedRole,
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
