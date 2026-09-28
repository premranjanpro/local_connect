import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_store.dart';
import '../providers/auth_provider.dart';
import 'task_booking_details_screen.dart';
import 'incoming_call_screen.dart';
import 'active_order_tracking_screen.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key});

  // ── Deep-link navigator ─────────────────────────────────────────
  static void navigateFromNotification(
    BuildContext context,
    AppNotification n,
    NotificationStore store,
  ) {
    store.markRead(n.id);
    final payload = n.payload;
    final taskId = payload['taskId']?.toString();
    final userRole = payload['userRole']?.toString() ??
        Provider.of<AuthProvider>(context, listen: false).role ??
        'Customer';

    switch (n.type) {
      case AppNotificationType.incomingCall:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
              callId: payload['callId'] ?? '',
              callerName: payload['callerName'] ?? 'Caller',
              callerRole: payload['callerRole'] ?? 'User',
              callerUserId: payload['callerId'],
              liveKitUrl: payload['liveKitUrl'],
              calleeToken: payload['calleeToken'],
            ),
          ),
        );
        break;

      case AppNotificationType.driverAssigned:
      case AppNotificationType.orderUpdate:
      case AppNotificationType.orderCompleted:
        if (taskId != null && taskId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskBookingDetailsScreen(
                taskId: taskId,
                userRole: userRole,
              ),
            ),
          );
        }
        break;

      case AppNotificationType.dispatchReceived:
        if (taskId != null && taskId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskBookingDetailsScreen(
                taskId: taskId,
                userRole: 'Driver',
              ),
            ),
          );
        }
        break;

      case AppNotificationType.payment:
        if (taskId != null && taskId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskBookingDetailsScreen(
                taskId: taskId,
                userRole: userRole,
              ),
            ),
          );
        }
        break;

      case AppNotificationType.subscriptionAlert:
        // Pop back to dashboard — subscription tab is there
        Navigator.pop(context);
        break;

      case AppNotificationType.generalAlert:
        // No specific deep-link, just mark read
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationStore>(
      builder: (context, store, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF060B18),
          body: CustomScrollView(
            slivers: [
              _buildHeader(context, store),
              if (store.all.isEmpty)
                _buildEmptyState()
              else ...[
                if (store.today.isNotEmpty) ...[
                  _buildSectionHeader('Today', store.today.where((n) => !n.isRead).length),
                  _buildNotificationList(context, store.today, store),
                ],
                if (store.yesterday.isNotEmpty) ...[
                  _buildSectionHeader('Yesterday', 0),
                  _buildNotificationList(context, store.yesterday, store),
                ],
                if (store.older.isNotEmpty) ...[
                  _buildSectionHeader('Older', 0),
                  _buildNotificationList(context, store.older, store),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Sliver Header ───────────────────────────────────────────────
  Widget _buildHeader(BuildContext context, NotificationStore store) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: const Color(0xFF060B18),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (store.unreadCount > 0)
          TextButton.icon(
            onPressed: store.markAllRead,
            icon: const Icon(Icons.done_all_rounded,
                color: Color(0xFF60A5FA), size: 16),
            label: const Text(
              'Mark all read',
              style: TextStyle(
                  color: Color(0xFF60A5FA),
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
        if (store.all.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded,
                color: Colors.redAccent, size: 22),
            tooltip: 'Clear All',
            onPressed: () => _confirmClearAll(context, store),
          ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81), Color(0xFF060B18)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.notifications_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Notification Center',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Consumer<NotificationStore>(
                              builder: (_, s, __) => Text(
                                s.unreadCount > 0
                                    ? '${s.unreadCount} unread notification${s.unreadCount > 1 ? 's' : ''}'
                                    : 'All caught up!',
                                style: TextStyle(
                                  color: s.unreadCount > 0
                                      ? const Color(0xFF818CF8)
                                      : Colors.white60,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Section Label ───────────────────────────────────────────────
  Widget _buildSectionHeader(String label, int unread) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unread new',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const Spacer(),
            Container(height: 1, width: 60, color: Colors.white12),
          ],
        ),
      ),
    );
  }

  // ── Notification Cards List ─────────────────────────────────────
  Widget _buildNotificationList(
    BuildContext context,
    List<AppNotification> notifications,
    NotificationStore store,
  ) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          final n = notifications[i];
          return _NotificationCard(
            notification: n,
            onTap: () => navigateFromNotification(context, n, store),
            onDismiss: () => store.remove(n.id),
          );
        },
        childCount: notifications.length,
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: const Icon(
              Icons.notifications_off_rounded,
              color: Color(0xFF4B5563),
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Notifications Yet',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Order updates, call alerts, and delivery\nstatus will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  void _confirmClearAll(BuildContext context, NotificationStore store) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear All Notifications',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text(
          'All notifications will be permanently deleted. Are you sure?',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              store.clearAll();
              Navigator.pop(context);
            },
            child: const Text('Clear All',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Individual Notification Card ─────────────────────────────────
class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final config = _NotificationConfig.from(notification.type);
    final isUnread = !notification.isRead;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Dismissible(
        key: Key(notification.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline_rounded,
              color: Colors.redAccent, size: 24),
        ),
        onDismissed: (_) => onDismiss(),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: isUnread
                  ? LinearGradient(
                      colors: [
                        config.color.withValues(alpha: 0.08),
                        const Color(0xFF1E293B),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
              color: isUnread ? null : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnread
                    ? config.color.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.05),
                width: isUnread ? 1.2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Icon ──
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: config.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(config.icon, color: config.color, size: 22),
                  ),
                  const SizedBox(width: 12),

                  // ── Content ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: isUnread
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 6),
                                decoration: BoxDecoration(
                                  color: config.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          notification.body,
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 12, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time_rounded,
                                size: 11, color: Colors.white38),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(notification.timestamp),
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 11),
                            ),
                            const Spacer(),
                            if (_hasDeepLink(notification.type))
                              Row(
                                children: [
                                  Text(
                                    'View',
                                    style: TextStyle(
                                      color: config.color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(Icons.arrow_forward_ios_rounded,
                                      size: 10, color: config.color),
                                ],
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
      ),
    );
  }

  bool _hasDeepLink(AppNotificationType type) {
    return type != AppNotificationType.generalAlert &&
        type != AppNotificationType.subscriptionAlert;
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Type → Icon + Color Mapping ────────────────────────────────
class _NotificationConfig {
  final IconData icon;
  final Color color;

  const _NotificationConfig(this.icon, this.color);

  static _NotificationConfig from(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.incomingCall:
        return const _NotificationConfig(
            Icons.phone_in_talk_rounded, Color(0xFF10B981));
      case AppNotificationType.orderUpdate:
        return const _NotificationConfig(
            Icons.local_shipping_rounded, Color(0xFF3B82F6));
      case AppNotificationType.driverAssigned:
        return const _NotificationConfig(
            Icons.two_wheeler_rounded, Color(0xFFF59E0B));
      case AppNotificationType.orderCompleted:
        return const _NotificationConfig(
            Icons.check_circle_rounded, Color(0xFF34D399));
      case AppNotificationType.payment:
        return const _NotificationConfig(
            Icons.currency_rupee_rounded, Color(0xFF059669));
      case AppNotificationType.dispatchReceived:
        return const _NotificationConfig(
            Icons.flash_on_rounded, Color(0xFFF97316));
      case AppNotificationType.subscriptionAlert:
        return const _NotificationConfig(
            Icons.repeat_rounded, Color(0xFF8B5CF6));
      case AppNotificationType.generalAlert:
        return const _NotificationConfig(
            Icons.notifications_rounded, Color(0xFF6366F1));
    }
  }
}
