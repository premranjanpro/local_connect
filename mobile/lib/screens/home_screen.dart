import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'driver_screen.dart';
import 'customer_screen.dart';
import 'merchant_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userRole = auth.role ?? 'Customer';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: Row(
          children: [
            const Icon(Icons.hub_rounded, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Text('ShopConnector', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getRoleColor(userRole).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getRoleColor(userRole)),
              ),
              child: Text(
                userRole.toUpperCase(),
                style: TextStyle(color: _getRoleColor(userRole), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E293B),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF0F172A)),
              accountName: Text(auth.fullName ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              accountEmail: Text('${auth.phone ?? ""} • Role: ${auth.role ?? "None"}'),
              currentAccountPicture: CircleAvatar(
                backgroundColor: _getRoleColor(userRole),
                child: Text(
                  (auth.fullName?.isNotEmpty == true ? auth.fullName![0] : 'U'),
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.devices, color: Colors.blueAccent),
              title: const Text('Device Session', style: TextStyle(color: Colors.white)),
              subtitle: Text('ID: ${auth.deviceId}', style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
            ),
            const Divider(color: Colors.white12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('SWITCH TESTING MODULE', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.blueAccent),
              title: const Text('Customer Mode', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                auth.switchRoleLocally('Customer');
              },
            ),
            ListTile(
              leading: const Icon(Icons.two_wheeler, color: Colors.amber),
              title: const Text('Driver Console', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                auth.switchRoleLocally('Driver');
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront, color: Colors.greenAccent),
              title: const Text('Merchant Console', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                auth.switchRoleLocally('Merchant');
              },
            ),
            const Divider(color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Logout Session', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                auth.logout();
              },
            ),
          ],
        ),
      ),
      body: userRole == 'Driver'
          ? const DriverScreen()
          : userRole == 'Merchant'
              ? const MerchantScreen()
              : const CustomerScreen(),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Driver':
        return Colors.amber;
      case 'Merchant':
        return Colors.greenAccent;
      default:
        return Colors.blueAccent;
    }
  }
}
