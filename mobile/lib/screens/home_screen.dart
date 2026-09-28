import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_menu_drawer.dart';
import 'driver_dashboard.dart';
import 'customer_dashboard.dart';
import 'merchant_dashboard.dart';

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
      backgroundColor: const Color(0xFF060B18),
      drawer: const AppMenuDrawer(activeItem: 'Dashboard'),
      body: userRole == 'Driver'
          ? const DriverDashboard()
          : userRole == 'Merchant'
              ? const MerchantDashboard()
              : const CustomerDashboard(),
    );
  }
}
