import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/task_status_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_tone_service.dart';
import '../../services/mqtt_service.dart';
import '../../services/order_lifecycle_api.dart';
import '../../widgets/order_rating_bottom_sheet.dart';
import '../../widgets/profile_sheets/shop_profile_sheet.dart';
import '../../widgets/profile_sheets/driver_profile_sheet.dart';
import '../active_order_tracking_screen.dart';
import '../calling_screen.dart';
import '../share_track_screen.dart';

/// ══════════════════════════════════════════════════════════════════════════════
///  CustomerOrderDetailScreen
///  Dedicated 5-Status Customer Experience:
///   1. Pending   - Waiting for shop confirmation & driver broadcast
///   2. Assigned  - Shop preparing, driver assigned & heading to pickup
///   3. Ongoing   - Out for delivery, live map tracker, OTP display
///   4. Completed - Digital invoice, item breakdown, ratings & reorder
///   5. Cancelled - Reason details, refund / Khata reversal status
/// ══════════════════════════════════════════════════════════════════════════════
class CustomerOrderDetailScreen extends StatefulWidget {
  final String taskId;
  final String? token;
  final Map<String, dynamic>? initialTaskData;
  final TaskModel? initialTask;

  const CustomerOrderDetailScreen({
    super.key,
    required this.taskId,
    this.token,
    this.initialTaskData,
    this.initialTask,
  });

  @override
  State<CustomerOrderDetailScreen> createState() => _CustomerOrderDetailScreenState();
}

class _CustomerOrderDetailScreenState extends State<CustomerOrderDetailScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _task;
  late TaskStatus _currentStatus;
  Timer? _pollingTimer;
  StreamSubscription? _mqttSub;
  bool _isLoading = false;
  bool _isCancelling = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  String get _effectiveToken {
    if (widget.token != null && widget.token!.isNotEmpty) {
      return widget.token!;
    }
    try {
      return Provider.of<AuthProvider>(context, listen: false).token ?? '';
    } catch (_) {
      return '';
    }
  }

  TaskModel get _taskModel => TaskModel.fromJson(_task);

  @override
  void initState() {
    super.initState();
    Map<String, dynamic> raw = {};
    if (widget.initialTask != null) {
      raw = Map<String, dynamic>.from(widget.initialTask!.raw);
      if (raw.isEmpty) {
        raw = {
          'id': widget.initialTask!.id,
          'status': widget.initialTask!.status.name,
          'pickupAddress': widget.initialTask!.pickupAddress,
          'dropoffAddress': widget.initialTask!.dropoffAddress,
          'estimatedFare': widget.initialTask!.estimatedFare,
          'fareAmount': widget.initialTask!.estimatedFare,
          'driverName': widget.initialTask!.driverName,
          'driverPhone': widget.initialTask!.driverPhone,
          'shopName': widget.initialTask!.shopName,
          'businessName': widget.initialTask!.shopName,
          'pickupOtp': widget.initialTask!.pickupOtp,
          'dropoffOtp': widget.initialTask!.dropoffOtp,
          'vehiclePlateNumber': widget.initialTask!.vehiclePlateNumber,
          'vehicleMakeModel': widget.initialTask!.vehicleMakeModel,
        };
      }
    } else if (widget.initialTaskData != null) {
      raw = Map<String, dynamic>.from(widget.initialTaskData!);
    }
    _task = raw;
    _currentStatus = taskStatusFromString(_task['status']?.toString());

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _startRealtimeUpdates();
    _fetchLatestTask();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _mqttSub?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startRealtimeUpdates() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchLatestTask());

    try {
      _mqttSub = MqttService.instance.taskStatusStream?.listen((event) {
        if (event['taskId'] == widget.taskId && mounted) {
          final newStatusStr = event['status']?.toString();
          if (newStatusStr != null) {
            final newStatus = taskStatusFromString(newStatusStr);
            if (newStatus != _currentStatus) {
              _onStatusTransition(newStatus);
            }
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _fetchLatestTask() async {
    try {
      final token = _effectiveToken;
      final updated = await OrderLifecycleApi.getTaskStatus(widget.taskId, token);
      if (mounted && updated.isNotEmpty) {
        final newStatus = taskStatusFromString(updated['status']?.toString());
        if (newStatus != _currentStatus) {
          _onStatusTransition(newStatus);
        }
        setState(() {
          _task = updated;
        });
      }
    } catch (_) {}
  }

  void _onStatusTransition(TaskStatus newStatus) {
    setState(() {
      _currentStatus = newStatus;
    });

    if (newStatus == TaskStatus.completed) {
      AudioToneService.playCelebrationTone();
    } else {
      AudioToneService.playStatusUpdateTone();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order Status: ${newStatus.label}'),
        backgroundColor: newStatus.color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openLiveTracking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveOrderTrackingScreen(
          taskId: widget.taskId,
          token: _effectiveToken,
          userRole: 'Customer',
          taskData: _task,
        ),
      ),
    );
  }

  Future<void> _handleCancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Cancel Order?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to cancel this order? This action cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, Keep Order', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);
    try {
      await OrderLifecycleApi.deletePendingTask(widget.taskId, _effectiveToken);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled successfully'), backgroundColor: Color(0xFF10B981)),
        );
        _onStatusTransition(TaskStatus.cancelled);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to cancel: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final model = _taskModel;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Order Details',
                  style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _currentStatus.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _currentStatus.color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _currentStatus.label,
                    style: TextStyle(color: _currentStatus.color, fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            Text(
              '${model.shortId} • ${model.taskTypeLabel}',
              style: TextStyle(color: textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Color(0xFF3B82F6), size: 20),
            tooltip: 'Share Live Track',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShareTrackScreen(
                    taskId: widget.taskId,
                    token: _effectiveToken,
                    taskData: _task,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: textSecondary, size: 20),
            onPressed: _fetchLatestTask,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: cardBorder, height: 1),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLatestTask,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Status Hero Banner
            _buildStatusHeroBanner(model, isDark),
            const SizedBox(height: 14),

            // 2. Live Tracking Button (For Ongoing / Assigned)
            if (_currentStatus == TaskStatus.ongoing || _currentStatus == TaskStatus.assign) ...[
              _buildLiveTrackingActionCard(model, isDark),
              const SizedBox(height: 14),
            ],

            // 3. Security PIN / Delivery OTP Card
            if (_currentStatus == TaskStatus.ongoing || _currentStatus == TaskStatus.assign) ...[
              _buildOtpSecurityCard(model, isDark),
              const SizedBox(height: 14),
            ],

            // 4. Driver Information Card
            if (model.driverName != null && model.driverName!.isNotEmpty) ...[
              _buildDriverCard(model, isDark),
              const SizedBox(height: 14),
            ],

            // 5. Shop / Merchant Card
            if (model.shopName != null && model.shopName!.isNotEmpty) ...[
              _buildShopCard(model, isDark),
              const SizedBox(height: 14),
            ],

            // 6. Complete Itemized Bill & Basket
            _buildItemizedBillCard(model, isDark),
            const SizedBox(height: 14),

            // 7. Route & Address Details
            _buildAddressesCard(model, isDark),
            const SizedBox(height: 14),

            // 8. Order Lifecycle Timeline
            _buildOrderTimelineCard(model, isDark),
            const SizedBox(height: 14),

            // 9. Status Actions (Cancel, Rate, Reorder, Help)
            _buildBottomActionButtons(model, isDark),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Status Hero Banner ──────────────────────────────────────────────────
  Widget _buildStatusHeroBanner(TaskModel model, bool isDark) {
    Color color = _currentStatus.color;
    IconData icon = _currentStatus.icon;
    String title = '';
    String subtitle = '';

    switch (_currentStatus) {
      case TaskStatus.pending:
        title = 'Broadcasting Order to Partners';
        subtitle = model.requiresShopConfirm
            ? 'Waiting for shopkeeper to confirm and pack items'
            : 'Connecting you with the best nearby delivery driver';
        icon = Icons.radar_rounded;
        break;
      case TaskStatus.assign:
        title = 'Driver Assigned & Heading to Shop';
        subtitle = '${model.driverName ?? 'Driver'} has accepted your order and is arriving at the pickup location.';
        icon = Icons.two_wheeler_rounded;
        break;
      case TaskStatus.ongoing:
        title = 'Order Out for Delivery!';
        subtitle = 'Your package is on its way. Live GPS tracking is currently active.';
        icon = Icons.local_shipping_rounded;
        break;
      case TaskStatus.completed:
        title = 'Delivered Successfully! 🎉';
        subtitle = 'Order completed at ${model.completedAt != null ? "${model.completedAt!.hour}:${model.completedAt!.minute.toString().padLeft(2, '0')}" : "just now"}. Thank you!';
        icon = Icons.check_circle_rounded;
        break;
      case TaskStatus.cancelled:
        title = 'Order Cancelled';
        subtitle = model.shopRejectionReason ?? 'This order was cancelled. Any pre-authorized charges or Khata limits are restored.';
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Live Tracking Action Card ───────────────────────────────────────────
  Widget _buildLiveTrackingActionCard(TaskModel model, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _openLiveTracking,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Map & Driver Tracker',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        model.driverLatitude != null
                            ? 'GPS live ping active • Tap to view route'
                            : 'Tap to view live vehicle route & ETA',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Security PIN / Delivery OTP Card ────────────────────────────────────
  Widget _buildOtpSecurityCard(TaskModel model, bool isDark) {
    final dropOtp = model.dropoffOtp ?? _task['dropoffOtp'] ?? _task['dropOtp'];
    final pickupOtp = model.pickupOtp ?? _task['pickupOtp'];

    if (dropOtp == null && pickupOtp == null) return const SizedBox.shrink();

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Security Handover PIN',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'CONFIDENTIAL',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Share this PIN with the delivery partner upon arrival to confirm receipt of your order.',
            style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (dropOtp != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Delivery OTP', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                    dropOtp.toString(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Driver Card ─────────────────────────────────────────────────────────
  Widget _buildDriverCard(TaskModel model, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                backgroundImage: (model.driverAvatarUrl != null && model.driverAvatarUrl!.isNotEmpty)
                    ? NetworkImage(model.driverAvatarUrl!)
                    : null,
                child: (model.driverAvatarUrl == null || model.driverAvatarUrl!.isEmpty)
                    ? const Icon(Icons.person_rounded, color: Color(0xFF3B82F6), size: 28)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            model.driverName ?? 'Assigned Driver',
                            style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                        Text(
                          (model.driverRating ?? 4.9).toStringAsFixed(1),
                          style: TextStyle(color: textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${model.vehicleMakeModel ?? 'Delivery Vehicle'} • ${model.vehiclePlateNumber ?? ''}',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (model.driverPhone != null && model.driverPhone!.isNotEmpty) ...[
                IconButton.filled(
                  style: IconButton.filledStyleFrom(backgroundColor: const Color(0xFF10B981)),
                  icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                  tooltip: 'Call Driver',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallingScreen(
                          targetUserId: model.assignedDriverId ?? '',
                          targetUserName: model.driverName ?? 'Driver',
                          targetUserRole: 'Driver',
                          targetPhoneNumber: model.driverPhone,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─── Shop Card ───────────────────────────────────────────────────────────
  Widget _buildShopCard(TaskModel model, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded, color: Color(0xFF8B5CF6), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.shopName ?? 'Local Merchant',
                  style: TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  model.businessCategory ?? 'General Store & Grocery',
                  style: TextStyle(color: textSecondary, fontSize: 12),
                ),
                if (model.businessAddress != null && model.businessAddress!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    model.businessAddress!,
                    style: TextStyle(color: textSecondary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (model.businessPhone != null && model.businessPhone!.isNotEmpty) ...[
            IconButton.filledTonal(
              style: IconButton.filledStyleFrom(backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15)),
              icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF8B5CF6), size: 18),
              tooltip: 'Call Shopkeeper',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallingScreen(
                      targetUserId: _task['businessMerchantId']?.toString() ?? '',
                      targetUserName: model.shopName ?? 'Shopkeeper',
                      targetUserRole: 'Merchant',
                      targetPhoneNumber: model.businessPhone,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ─── Itemized Bill & Basket ──────────────────────────────────────────────
  Widget _buildItemizedBillCard(TaskModel model, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final items = model.parsedOrderItems;
    final fare = model.estimatedFare ?? 0.0;
    final paymentMode = model.paymentMode ?? 'Cash';
    final paymentStatus = _task['paymentStatus']?.toString() ?? 'Pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              Text(
                'Order Summary & Bill',
                style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: (paymentStatus.toLowerCase() == 'paid')
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  paymentStatus.toUpperCase(),
                  style: TextStyle(
                    color: (paymentStatus.toLowerCase() == 'paid')
                        ? const Color(0xFF10B981)
                        : const Color(0xFFF59E0B),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Items list
          if (items.isNotEmpty) ...[
            ...items.map((it) {
              final name = it['name']?.toString() ?? 'Item';
              final qty = it['quantity'] ?? it['qty'] ?? 1;
              final price = (it['price'] as num?)?.toDouble() ?? 0.0;
              final total = price > 0 ? price * (qty as num) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(color: Color(0xFF3B82F6), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      '${qty}x',
                      style: TextStyle(color: textSecondary, fontSize: 13),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      total > 0 ? '₹${total.toStringAsFixed(2)}' : '—',
                      style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 20),
          ] else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _task['orderItems']?.toString() ?? 'Standard Delivery Package',
                style: TextStyle(color: textPrimary, fontSize: 13),
              ),
            ),
            const Divider(height: 20),
          ],

          // Total Fare Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Fare / Amount', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
              Text('₹${fare.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 17)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment Mode', style: TextStyle(color: textSecondary, fontSize: 12)),
              Text(paymentMode, style: TextStyle(color: textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Addresses & Waypoints ───────────────────────────────────────────────
  Widget _buildAddressesCard(TaskModel model, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 8),
              Text(
                'Route Locations',
                style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, color: Color(0xFF10B981), size: 10),
                  Container(width: 2, height: 26, color: cardBorder),
                  const Icon(Icons.location_pin, color: Color(0xFFEF4444), size: 14),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pickup / Store', style: TextStyle(color: textSecondary, fontSize: 11)),
                    Text(
                      model.pickupAddress,
                      style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    Text('Delivery Address', style: TextStyle(color: textSecondary, fontSize: 11)),
                    Text(
                      model.dropoffAddress,
                      style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Lifecycle Timeline ──────────────────────────────────────────────────
  Widget _buildOrderTimelineCard(TaskModel model, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final logs = model.deliveryLogs;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 8),
              Text(
                'Live Delivery Timeline',
                style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (logs.isNotEmpty) ...[
            ...logs.map((log) {
              final event = log['eventType']?.toString() ?? 'Update';
              final time = log['loggedAt']?.toString() ?? '';
              final notes = log['notes']?.toString();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Color(0xFF8B5CF6), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event, style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                          if (notes != null && notes.isNotEmpty)
                            Text(notes, style: TextStyle(color: textSecondary, fontSize: 11)),
                        ],
                      ),
                    ),
                    if (time.length > 10)
                      Text(
                        time.substring(11, 16),
                        style: TextStyle(color: textSecondary, fontSize: 11),
                      ),
                  ],
                ),
              );
            }),
          ] else ...[
            Text(
              'Order placed at ${model.createdAt.hour}:${model.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Status Actions ──────────────────────────────────────────────────────
  Widget _buildBottomActionButtons(TaskModel model, bool isDark) {
    if (_currentStatus == TaskStatus.pending) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFEF4444)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _isCancelling
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)))
              : const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
          label: Text(
            _isCancelling ? 'Cancelling...' : 'Cancel Order',
            style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
          ),
          onPressed: _isCancelling ? null : _handleCancelOrder,
        ),
      );
    } else if (_currentStatus == TaskStatus.completed) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.star_rounded, color: Colors.white),
                label: const Text('Rate Partner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => OrderRatingBottomSheet(
                      taskId: widget.taskId,
                      driverName: model.driverName ?? 'Driver',
                      shopName: model.shopName ?? 'Shop',
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.replay_rounded, color: Colors.white),
                label: const Text('Reorder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Items added to cart! Proceed to checkout.')),
                  );
                },
              ),
            ),
          ),
        ],
      );
    } else if (_currentStatus == TaskStatus.ongoing) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.map_rounded, color: Colors.white),
          label: const Text('Open Fullscreen Live Tracking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: _openLiveTracking,
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
