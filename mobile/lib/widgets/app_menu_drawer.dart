import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/profile_screen.dart';
import '../screens/all_orders_tasks_screen.dart';
import '../screens/shops_near_me_screen.dart';
import '../screens/offers_near_me_screen.dart';
import '../screens/broadcast_feed_page.dart';
import '../screens/settings_screen.dart';
import '../screens/support_screen.dart';

class AppMenuDrawer extends StatelessWidget {
  final String activeItem;

  const AppMenuDrawer({super.key, this.activeItem = 'Dashboard'});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userRole = auth.role ?? 'Customer';
    final roleColor = _getRoleColor(userRole);

    return Drawer(
      backgroundColor: const Color(0xFF0F172A),
      child: SafeArea(
        child: Column(
          children: [
            // ─── Profile Header (Tapping opens Profile Screen) ───
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: roleColor.withValues(alpha: 0.15),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: roleColor.withValues(alpha: 0.3),
                      child: Text(
                        auth.fullName?.isNotEmpty == true
                            ? auth.fullName![0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                            color: roleColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.fullName ?? 'User Profile',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            auth.phone ?? '',
                            style: const TextStyle(
                                color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: roleColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: roleColor.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              userRole.toUpperCase(),
                              style: TextStyle(
                                  color: roleColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: Colors.white38, size: 16),
                  ],
                ),
              ),
            ),

            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),

            // ─── Menu Items ───
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _menuTile(
                    context,
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    color: const Color(0xFF38BDF8),
                    isSelected: activeItem == 'Dashboard',
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  _menuTile(
                    context,
                    icon: Icons.receipt_long_rounded,
                    title: 'Order ya task',
                    color: const Color(0xFF10B981),
                    isSelected: activeItem == 'Order ya task',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AllOrdersTasksScreen()),
                      );
                    },
                  ),
                  _menuTile(
                    context,
                    icon: Icons.storefront_rounded,
                    title: 'Shop Near Me',
                    color: const Color(0xFFF59E0B),
                    isSelected: activeItem == 'Shop Near Me',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ShopsNearMeScreen()),
                      );
                    },
                  ),
                  _menuTile(
                    context,
                    icon: Icons.local_offer_rounded,
                    title: 'Offer Near Me',
                    color: const Color(0xFFEC4899),
                    isSelected: activeItem == 'Offer Near Me',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OffersNearMeScreen()),
                      );
                    },
                  ),
                  _menuTile(
                    context,
                    icon: Icons.campaign_rounded,
                    title: 'Needs Near Me',
                    color: const Color(0xFF8B5CF6),
                    isSelected: activeItem == 'Needs Near Me',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BroadcastFeedPage()),
                      );
                    },
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _menuTile(
                    context,
                    icon: Icons.settings_rounded,
                    title: 'Setting',
                    color: const Color(0xFF94A3B8),
                    isSelected: activeItem == 'Setting',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                  _menuTile(
                    context,
                    icon: Icons.support_agent_rounded,
                    title: 'Support',
                    color: const Color(0xFF34D399),
                    isSelected: activeItem == 'Support',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SupportScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Footer info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 6),
                  const Text('LocalConnect v1.0',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProfileScreen()),
                      );
                    },
                    child: const Text('View Profile',
                        style: TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isSelected ? color.withValues(alpha: 0.4) : Colors.transparent,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: isSelected
            ? Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: color, shape: BoxShape.circle),
              )
            : const Icon(Icons.chevron_right_rounded,
                color: Colors.white24, size: 18),
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
