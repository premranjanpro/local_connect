import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userRole = auth.role ?? 'Customer';
    final roleColor = _getRoleColor(userRole);

    return Scaffold(
      backgroundColor: const Color(0xFF060B18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Profile & Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Card Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    roleColor.withValues(alpha: 0.3),
                    const Color(0xFF1E293B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: roleColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: roleColor.withValues(alpha: 0.25),
                    child: Text(
                      auth.fullName?.isNotEmpty == true ? auth.fullName![0].toUpperCase() : 'U',
                      style: TextStyle(color: roleColor, fontSize: 34, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    auth.fullName ?? 'User Profile',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.phone ?? '',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: roleColor.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      '${userRole.toUpperCase()} ACCOUNT',
                      style: TextStyle(color: roleColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Account Details List
            _infoCard(
              title: 'Account Information',
              items: [
                _infoRow(Icons.phone_iphone_rounded, 'Phone Number', auth.phone ?? 'Not set'),
                _infoRow(Icons.devices_rounded, 'Device ID', auth.deviceId ?? 'Registered'),
                _infoRow(Icons.verified_user_rounded, 'KYC Status', 'Verified Level 1', valueColor: const Color(0xFF34D399)),
                _infoRow(Icons.location_on_rounded, 'City / Region', 'Jaipur, Rajasthan'),
              ],
            ),
            const SizedBox(height: 16),

            // Role Switcher Section
            _infoCard(
              title: 'Switch Active Console',
              items: [
                _roleSwitchTile(
                  context,
                  role: 'Customer',
                  icon: Icons.person_rounded,
                  color: const Color(0xFF3B82F6),
                  isSelected: userRole == 'Customer',
                  onTap: () {
                    auth.switchRoleLocally('Customer');
                    Navigator.pop(context);
                  },
                ),
                _roleSwitchTile(
                  context,
                  role: 'Driver',
                  icon: Icons.two_wheeler_rounded,
                  color: const Color(0xFFF59E0B),
                  isSelected: userRole == 'Driver',
                  onTap: () {
                    auth.switchRoleLocally('Driver');
                    Navigator.pop(context);
                  },
                ),
                _roleSwitchTile(
                  context,
                  role: 'Merchant',
                  icon: Icons.storefront_rounded,
                  color: const Color(0xFF10B981),
                  isSelected: userRole == 'Merchant',
                  onTap: () {
                    auth.switchRoleLocally('Merchant');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Logout Action (Placed here as per requirements!)
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                ),
                title: const Text(
                  'Logout Session',
                  style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: const Text(
                  'End active login on this mobile device',
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFEF4444)),
                onTap: () => _showLogoutConfirm(context, auth),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Logout Confirmation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Kya aap sach me app se logout karna chahte hain? Aapko dubara PIN se login karna hoga.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Pop profile screen
              auth.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout Now', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required String title, required List<Widget> items}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          const Divider(height: 20, color: Colors.white10),
          ...items,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _roleSwitchTile(BuildContext context,
      {required String role, required IconData icon, required Color color, required bool isSelected, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? color.withValues(alpha: 0.5) : Colors.transparent),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
        title: Text(
          '$role Console',
          style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13),
        ),
        trailing: isSelected ? Icon(Icons.check_circle_rounded, color: color, size: 18) : null,
        onTap: onTap,
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Driver':
        return const Color(0xFFF59E0B);
      case 'Merchant':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF3B82F6);
    }
  }
}
