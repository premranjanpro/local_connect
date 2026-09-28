import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/task_status_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_tone_service.dart';
import '../../services/mqtt_service.dart';
import '../../services/order_lifecycle_api.dart';
import '../active_order_tracking_screen.dart';
import '../calling_screen.dart';

/// ══════════════════════════════════════════════════════════════════════════════
///  DriverOrderDetailScreen
///  Dedicated 5-Status Driver Operational Experience:
///   1. Pending   - Incoming dispatch offer with acceptance timer
///   2. Assigned  - Navigation to store, counter checklist, arrive & pickup OTP
///   3. Ongoing   - Navigation to customer, cash collection alert, delivery OTP
///   4. Completed - Earnings summary, distance payout, trip history
///   5. Cancelled - Trip cancelled notice & support
/// ══════════════════════════════════════════════════════════════════════════════
class DriverOrderDetailScreen extends StatefulWidget {
  final String taskId;
  final String? token;
  final Map<String, dynamic>? initialTaskData;
  final TaskModel? initialTask;

  const DriverOrderDetailScreen({
    super.key,
    required this.taskId,
    this.token,
    this.initialTaskData,
    this.initialTask,
  });

  @override
  State<DriverOrderDetailScreen> createState() => _DriverOrderDetailScreenState();
}

class _DriverOrderDetailScreenState extends State<DriverOrderDetailScreen> {
  late Map<String, dynamic> _task;
  late TaskStatus _currentStatus;
  Timer? _pollingTimer;
  StreamSubscription? _mqttSub;
  bool _isLoading = false;

  final TextEditingController _otpCtrl = TextEditingController();
  final Set<int> _checkedItems = {};

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
          'shopName': widget.initialTask!.shopName,
          'customerName': widget.initialTask!.customerName,
          'customerPhone': widget.initialTask!.customerPhone,
        };
      }
    } else if (widget.initialTaskData != null) {
      raw = Map<String, dynamic>.from(widget.initialTaskData!);
    }
    _task = raw;
    _currentStatus = taskStatusFromString(_task['status']?.toString());

    _startRealtimeUpdates();
    _fetchLatestTask();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _mqttSub?.cancel();
    _otpCtrl.dispose();
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
          userRole: 'Driver',
          taskData: _task,
        ),
      ),
    );
  }

  Future<void> _openExternalMaps(double lat, double lng, String label) async {
    final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final fallbackUri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening coordinates: $lat, $lng')),
      );
    }
  }

  // Lifecycle driver transitions
  Future<void> _handleStartTrip() async {
    setState(() => _isLoading = true);
    try {
      final lat = (_task['pickupLatitude'] as num?)?.toDouble() ?? 26.9124;
      final lng = (_task['pickupLongitude'] as num?)?.toDouble() ?? 75.7873;
      await OrderLifecycleApi.startTrip(_effectiveToken, widget.taskId, lat, lng);
      _onStatusTransition(TaskStatus.assign);
      _fetchLatestTask();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleArrivedPickup() async {
    setState(() => _isLoading = true);
    try {
      final lat = (_task['pickupLatitude'] as num?)?.toDouble() ?? 26.9124;
      final lng = (_task['pickupLongitude'] as num?)?.toDouble() ?? 75.7873;
      await OrderLifecycleApi.arrivePickup(_effectiveToken, widget.taskId, lat, lng);
      _fetchLatestTask();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked Arrived at Pickup!'), backgroundColor: Color(0xFF10B981)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleConfirmPickup() async {
    final requiresOtp = _task['isPickupOtpRequired'] != false;
    String? otp;

    if (requiresOtp) {
      final inputOtp = await _showOtpDialog('Enter Pickup Verification OTP', 'Ask the store manager for the 6-digit OTP');
      if (inputOtp == null || inputOtp.isEmpty) return;
      otp = inputOtp;
    }

    setState(() => _isLoading = true);
    try {
      final lat = (_task['pickupLatitude'] as num?)?.toDouble() ?? 26.9124;
      final lng = (_task['pickupLongitude'] as num?)?.toDouble() ?? 75.7873;
      await OrderLifecycleApi.confirmPickup(_effectiveToken, widget.taskId, lat, lng, otp: otp);
      _onStatusTransition(TaskStatus.ongoing);
      _fetchLatestTask();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pickup failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleArrivedDrop() async {
    setState(() => _isLoading = true);
    try {
      final lat = (_task['dropoffLatitude'] as num?)?.toDouble() ?? 26.9124;
      final lng = (_task['dropoffLongitude'] as num?)?.toDouble() ?? 75.7873;
      await OrderLifecycleApi.arriveDrop(_effectiveToken, widget.taskId, lat, lng);
      _fetchLatestTask();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked Arrived at Destination!'), backgroundColor: Color(0xFF10B981)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCompleteDelivery() async {
    final requiresOtp = _task['isDropOtpRequired'] != false;
    String? otp;

    if (requiresOtp) {
      final inputOtp = await _showOtpDialog('Enter Customer Delivery OTP', 'Ask the customer for their 6-digit PIN');
      if (inputOtp == null || inputOtp.isEmpty) return;
      otp = inputOtp;
    }

    setState(() => _isLoading = true);
    try {
      final lat = (_task['dropoffLatitude'] as num?)?.toDouble() ?? 26.9124;
      final lng = (_task['dropoffLongitude'] as num?)?.toDouble() ?? 75.7873;
      await OrderLifecycleApi.completeDelivery(_effectiveToken, widget.taskId, lat, lng, otp: otp);
      _onStatusTransition(TaskStatus.completed);
      _fetchLatestTask();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delivery failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _showOtpDialog(String title, String subtitle) {
    _otpCtrl.clear();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 6),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                counterText: '',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
                hintText: '• • • • • •',
                hintStyle: const TextStyle(color: Colors.white30, letterSpacing: 4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.pop(ctx, _otpCtrl.text.trim()),
            child: const Text('Verify & Proceed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
                  'Driver Trip Sheet',
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
              '${model.shortId} • Driver Mode',
              style: TextStyle(color: textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.navigation_rounded, color: Color(0xFF2563EB), size: 20),
            tooltip: 'Live Navigation Map',
            onPressed: _openLiveTracking,
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
            _buildDriverHeroBanner(model, isDark),
            const SizedBox(height: 14),

            // 2. Cash Collection / Payment Banner
            _buildCashCollectionBanner(model, isDark),
            const SizedBox(height: 14),

            // 3. Current Waypoint & Action Card (Navigation + Action Button)
            _buildCurrentWaypointCard(model, isDark),
            const SizedBox(height: 14),

            // 4. Shop / Pickup Counter Details
            _buildShopPickupCard(model, isDark),
            const SizedBox(height: 14),

            // 5. Customer / Dropoff Details
            _buildCustomerDropCard(model, isDark),
            const SizedBox(height: 14),

            // 6. Interactive Items Checklist (for driver to verify items)
            _buildItemsChecklistCard(model, isDark),
            const SizedBox(height: 14),

            // 7. Earnings & Payout Breakdown
            _buildDriverEarningsCard(model, isDark),
            const SizedBox(height: 14),

            // 8. Lifecycle Logs
            _buildLifecycleTimeline(model, isDark),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Status Banner ───────────────────────────────────────────────────────
  Widget _buildDriverHeroBanner(TaskModel model, bool isDark) {
    Color color = _currentStatus.color;
    IconData icon = _currentStatus.icon;
    String title = '';
    String subtitle = '';

    switch (_currentStatus) {
      case TaskStatus.pending:
        title = 'New Order Offer Received!';
        subtitle = 'Distance: ${model.distanceKm?.toStringAsFixed(1) ?? '2.5'} km • Fare: ₹${model.estimatedFare?.toStringAsFixed(2) ?? '80'}';
        icon = Icons.notifications_active_rounded;
        break;
      case TaskStatus.assign:
        title = 'Step 1: Proceed to Pickup Location';
        subtitle = 'Navigate to the store, confirm items packed, and verify handover.';
        icon = Icons.storefront_rounded;
        break;
      case TaskStatus.ongoing:
        title = 'Step 2: Deliver to Customer';
        subtitle = 'Proceed to customer address. Collect payment & verify delivery OTP.';
        icon = Icons.directions_bike_rounded;
        break;
      case TaskStatus.completed:
        title = 'Delivery Completed! 🎉';
        subtitle = '₹${(model.estimatedFare ?? 0).toStringAsFixed(2)} credited to your driver wallet balance.';
        icon = Icons.check_circle_rounded;
        break;
      case TaskStatus.cancelled:
        title = 'Trip Cancelled';
        subtitle = model.shopRejectionReason ?? 'This order was cancelled by customer/system.';
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Cash Collection Banner ──────────────────────────────────────────────
  Widget _buildCashCollectionBanner(TaskModel model, bool isDark) {
    final mode = (model.paymentMode ?? 'Cash').toLowerCase();
    final isCash = mode.contains('cash');
    final isKhata = mode.contains('dues') || mode.contains('khata');

    Color bannerColor = isCash ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    String title = '';
    String sub = '';

    if (isCash) {
      title = 'COLLECT ₹${(model.estimatedFare ?? 0).toStringAsFixed(2)} CASH';
      sub = 'Customer must pay cash at doorstep. Hand over exact change.';
    } else if (isKhata) {
      title = 'KHATA / DUES ORDER (DO NOT COLLECT CASH)';
      sub = 'Amount is debited to customer shop khata ledger.';
    } else {
      title = 'PREPAID ONLINE (DO NOT COLLECT CASH)';
      sub = 'Paid via UPI / Card. Just deliver and verify delivery OTP.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(isCash ? Icons.payments_rounded : Icons.check_circle_outline_rounded, color: bannerColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: bannerColor, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(sub, style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF334155), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Current Waypoint & Action Card ──────────────────────────────────────
  Widget _buildCurrentWaypointCard(TaskModel model, bool isDark) {
    final isPickupPhase = _currentStatus == TaskStatus.assign;
    final isDropPhase = _currentStatus == TaskStatus.ongoing;

    if (!isPickupPhase && !isDropPhase) return const SizedBox.shrink();

    final targetName = isPickupPhase ? (model.shopName ?? 'Pickup Store') : (model.customerName ?? 'Customer');
    final targetAddress = isPickupPhase ? model.pickupAddress : model.dropoffAddress;
    final targetLat = isPickupPhase ? ((_task['pickupLatitude'] as num?)?.toDouble() ?? 26.9124) : ((_task['dropoffLatitude'] as num?)?.toDouble() ?? 26.9124);
    final targetLng = isPickupPhase ? ((_task['pickupLongitude'] as num?)?.toDouble() ?? 75.7873) : ((_task['dropoffLongitude'] as num?)?.toDouble() ?? 75.7873);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(isPickupPhase ? Icons.store_rounded : Icons.pin_drop_rounded, color: const Color(0xFF3B82F6), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPickupPhase ? 'NEXT STOP: PICKUP' : 'NEXT STOP: CUSTOMER DROP',
                      style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.w900),
                    ),
                    Text(targetName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.turn_right_rounded, color: Colors.white, size: 16),
                label: const Text('Maps', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: () => _openExternalMaps(targetLat, targetLng, targetName),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(targetAddress, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 16),

          // Operational Action Buttons
          if (isPickupPhase) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isLoading ? null : _handleArrivedPickup,
                    child: const Text('Arrived at Store', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isLoading ? null : _handleConfirmPickup,
                    child: const Text('Verify Pickup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else if (isDropPhase) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isLoading ? null : _handleArrivedDrop,
                    child: const Text('Arrived at Drop', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isLoading ? null : _handleCompleteDelivery,
                    child: const Text('Complete Delivery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Shop Pickup Card ────────────────────────────────────────────────────
  Widget _buildShopPickupCard(TaskModel model, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront_rounded, color: Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 8),
              const Text('Shop Details (Pickup)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              if (model.businessPhone != null && model.businessPhone!.isNotEmpty) ...[
                IconButton.filledTonal(
                  style: IconButton.filledStyleFrom(backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15)),
                  icon: const Icon(Icons.phone_rounded, color: Color(0xFF8B5CF6), size: 18),
                  tooltip: 'Call Shop',
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
          const SizedBox(height: 6),
          Text(model.shopName ?? 'Store Name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(model.pickupAddress, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Customer Drop Card ──────────────────────────────────────────────────
  Widget _buildCustomerDropCard(TaskModel model, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_pin_circle_rounded, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              const Text('Customer Details (Drop)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              if (model.customerPhone != null && model.customerPhone!.isNotEmpty) ...[
                IconButton.filled(
                  style: IconButton.filledStyleFrom(backgroundColor: const Color(0xFF10B981)),
                  icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                  tooltip: 'Call Customer',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallingScreen(
                          targetUserId: _task['customerId']?.toString() ?? '',
                          targetUserName: model.customerName ?? 'Customer',
                          targetUserRole: 'Customer',
                          targetPhoneNumber: model.customerPhone,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(model.customerName ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(model.dropoffAddress, style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Items Checklist Card ────────────────────────────────────────────────
  Widget _buildItemsChecklistCard(TaskModel model, bool isDark) {
    final items = model.parsedOrderItems;
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.checklist_rounded, color: Color(0xFFF59E0B), size: 20),
              const SizedBox(width: 8),
              const Text('Store Pickup Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text(
                '${_checkedItems.length}/${items.length} Checked',
                style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Check off items at store counter before leaving:', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 10),
          ...List.generate(items.length, (idx) {
            final it = items[idx];
            final name = it['name']?.toString() ?? 'Item';
            final qty = it['quantity'] ?? it['qty'] ?? 1;
            final isChecked = _checkedItems.contains(idx);

            return InkWell(
              onTap: () {
                setState(() {
                  if (isChecked) {
                    _checkedItems.remove(idx);
                  } else {
                    _checkedItems.add(idx);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      color: isChecked ? const Color(0xFF10B981) : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          decoration: isChecked ? TextDecoration.lineThrough : null,
                          color: isChecked ? Colors.grey : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                    Text('${qty}x', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Earnings Card ───────────────────────────────────────────────────────
  Widget _buildDriverEarningsCard(TaskModel model, bool isDark) {
    final fare = model.estimatedFare ?? 80.0;
    final dist = model.distanceKm ?? 2.5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Text('Driver Payout & Earnings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Estimated Trip Payout', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('₹${fare.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Includes base rate + ₹10/km for $dist km', style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  // ─── Lifecycle Timeline ──────────────────────────────────────────────────
  Widget _buildLifecycleTimeline(TaskModel model, bool isDark) {
    final logs = model.deliveryLogs;
    if (logs.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: Color(0xFF8B5CF6), size: 20),
              SizedBox(width: 8),
              Text('Trip Event Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ...logs.map((log) {
            final ev = log['eventType']?.toString() ?? '';
            final tm = log['loggedAt']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.radio_button_checked, size: 10, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 10),
                  Expanded(child: Text(ev, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  if (tm.length > 10) Text(tm.substring(11, 16), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
