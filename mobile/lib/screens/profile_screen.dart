import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final userRole = auth.role ?? 'Customer';
    final roleColor = _getRoleColor(userRole);

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Profile & Account',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
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
                color: roleColor.withValues(alpha: isDark ? 0.2 : 0.08),
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
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    auth.phone ?? '',
                    style: TextStyle(color: subTextColor, fontSize: 14),
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
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
              title: 'Account Information',
              items: [
                _infoRow(Icons.phone_iphone_rounded, 'Phone Number', auth.phone ?? 'Not set', subTextColor, textColor),
                _infoRow(Icons.devices_rounded, 'Device ID', auth.deviceId.isEmpty ? 'Registered' : auth.deviceId, subTextColor, textColor),
                _infoRow(Icons.verified_user_rounded, 'KYC Status', 'Verified Level 1', subTextColor, textColor, valueColor: const Color(0xFF34D399)),
                _infoRow(Icons.location_on_rounded, 'City / Region', 'Jaipur, Rajasthan', subTextColor, textColor),
              ],
            ),
            const SizedBox(height: 16),

            // Theme Switcher Section
            _infoCard(
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
              title: 'App Appearance & Theme',
              items: [
                Row(
                  children: [
                    Expanded(
                      child: _themePill(
                        title: 'Dark',
                        icon: Icons.dark_mode_rounded,
                        isSelected: themeProvider.mode == ThemeMode.dark,
                        activeColor: const Color(0xFF38BDF8),
                        textColor: textColor,
                        onTap: () => themeProvider.setDark(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _themePill(
                        title: 'Light',
                        icon: Icons.light_mode_rounded,
                        isSelected: themeProvider.mode == ThemeMode.light,
                        activeColor: const Color(0xFFF59E0B),
                        textColor: textColor,
                        onTap: () => themeProvider.setLight(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _themePill(
                        title: 'System',
                        icon: Icons.settings_brightness_rounded,
                        isSelected: themeProvider.mode == ThemeMode.system,
                        activeColor: const Color(0xFF10B981),
                        textColor: textColor,
                        onTap: () => themeProvider.setSystem(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Role Switcher Section
            _infoCard(
              cardBg: cardBg,
              borderColor: borderColor,
              textColor: textColor,
              title: 'Switch Active Console',
              items: [
                _roleSwitchTile(
                  context,
                  role: 'Customer',
                  icon: Icons.person_rounded,
                  color: const Color(0xFF3B82F6),
                  isSelected: userRole == 'Customer',
                  textColor: textColor,
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
                  textColor: textColor,
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
                  textColor: textColor,
                  onTap: () {
                    auth.switchRoleLocally('Merchant');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Logout Action
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
                subtitle: Text(
                  'End active login on this mobile device',
                  style: TextStyle(color: subTextColor, fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFEF4444)),
                onTap: () => _showLogoutConfirm(context, auth, isDark),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _themePill({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? activeColor : Colors.grey, size: 20),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? activeColor : textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context, AuthProvider auth, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Logout Confirmation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Kya aap sach me app se logout karna chahte hain? Aapko dubara PIN se login karna hoga.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
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

  Widget _infoCard({
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required String title,
    required List<Widget> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
          Divider(height: 20, color: borderColor),
          ...items,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color subTextColor, Color textColor, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: subTextColor),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: subTextColor, fontSize: 13)),
          const Spacer(),
          Text(value, style: TextStyle(color: valueColor ?? textColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _roleSwitchTile(
    BuildContext context, {
    required String role,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required Color textColor,
    required VoidCallback onTap,
  }) {
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
          style: TextStyle(
            color: isSelected ? color : textColor,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
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

