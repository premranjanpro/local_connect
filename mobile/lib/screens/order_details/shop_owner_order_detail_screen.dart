import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/task_status_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_tone_service.dart';
import '../../services/mqtt_service.dart';
import '../../services/order_lifecycle_api.dart';
import '../active_order_tracking_screen.dart';
import '../calling_screen.dart';

/// ══════════════════════════════════════════════════════════════════════════════
///  ShopOwnerOrderDetailScreen
///  Dedicated 5-Status Merchant / Shopkeeper Operational Experience:
///   1. Pending   - Order review, Khata balance check, [Confirm] & [Reject]
///   2. Assigned  - Store packing checklist, KOT print, [Post to Market]
///   3. Ongoing   - Handed over, live driver transit tracking, customer card
///   4. Completed - Counter settlement, Khata ledger debit, order history
///   5. Cancelled - Rejection reason record & inventory release
/// ══════════════════════════════════════════════════════════════════════════════
class ShopOwnerOrderDetailScreen extends StatefulWidget {
  final String taskId;
  final String? token;
  final Map<String, dynamic>? initialTaskData;
  final TaskModel? initialTask;

  const ShopOwnerOrderDetailScreen({
    super.key,
    required this.taskId,
    this.token,
    this.initialTaskData,
    this.initialTask,
  });

  @override
  State<ShopOwnerOrderDetailScreen> createState() => _ShopOwnerOrderDetailScreenState();
}

class _ShopOwnerOrderDetailScreenState extends State<ShopOwnerOrderDetailScreen> {
  late Map<String, dynamic> _task;
  late TaskStatus _currentStatus;
  Timer? _pollingTimer;
  StreamSubscription? _mqttSub;
  bool _isLoading = false;

  final Set<int> _packedItems = {};
  bool _reqPickupOtp = true;
  bool _reqDropOtp = true;

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
          'customerName': widget.initialTask!.customerName,
          'customerPhone': widget.initialTask!.customerPhone,
          'driverName': widget.initialTask!.driverName,
          'driverPhone': widget.initialTask!.driverPhone,
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
          userRole: 'Merchant',
          taskData: _task,
        ),
      ),
    );
  }

  // Confirm order action
  Future<void> _handleConfirmOrder() async {
    setState(() => _isLoading = true);
    try {
      await OrderLifecycleApi.confirmOrder(
        _effectiveToken,
        widget.taskId,
        requirePickupOtp: _reqPickupOtp,
        requireDropOtp: _reqDropOtp,
      );
      _onStatusTransition(TaskStatus.assign);
      _fetchLatestTask();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order confirmed & broadcast to drivers!'), backgroundColor: Color(0xFF10B981)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Confirm failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Reject order action
  Future<void> _handleRejectOrder() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Reject Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this order:', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'e.g. Items out of stock, store closed',
                hintStyle: TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, reasonCtrl.text.trim()),
            child: const Text('Reject Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await OrderLifecycleApi.rejectOrder(_effectiveToken, widget.taskId, reason);
      _onStatusTransition(TaskStatus.cancelled);
      _fetchLatestTask();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reject failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Post to open market drivers
  Future<void> _handlePostToMarket() async {
    final fareCtrl = TextEditingController(text: '100');
    final fare = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Broadcast to Market Drivers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Offer a fare incentive to nearby freelance/market drivers to pick up immediately:', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 14),
            TextField(
              controller: fareCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                prefixText: '₹ ',
                prefixStyle: TextStyle(color: Color(0xFF10B981), fontSize: 18, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: Color(0xFF0F172A),
                labelText: 'Driver Fare Offer',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () => Navigator.pop(ctx, double.tryParse(fareCtrl.text) ?? 100.0),
            child: const Text('Broadcast Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (fare == null) return;

    setState(() => _isLoading = true);
    try {
      await OrderLifecycleApi.postToMarket(_effectiveToken, widget.taskId, fare);
      _fetchLatestTask();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order broadcasted to open market with ₹$fare offer!'), backgroundColor: const Color(0xFF10B981)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPrintKotDialog(TaskModel model) {
    final items = model.parsedOrderItems;
    final kotText = StringBuffer();
    kotText.writeln('=================================');
    kotText.writeln('   KITCHEN / STORE ORDER TICKET   ');
    kotText.writeln('=================================');
    kotText.writeln('Order: ${model.shortId}');
    kotText.writeln('Customer: ${model.customerName ?? "Customer"}');
    kotText.writeln('Time: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}');
    kotText.writeln('---------------------------------');
    for (final it in items) {
      final name = it['name'] ?? 'Item';
      final qty = it['quantity'] ?? 1;
      kotText.writeln('$qty x $name');
    }
    kotText.writeln('---------------------------------');
    kotText.writeln('Total Items: ${items.length}');
    kotText.writeln('Payment: ${model.paymentMode ?? "Cash"}');
    kotText.writeln('=================================');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.print_rounded, color: Color(0xFF3B82F6)),
            SizedBox(width: 8),
            Text('Kitchen Order Ticket (KOT)', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white24),
          ),
          child: SingleChildScrollView(
            child: Text(
              kotText.toString(),
              style: const TextStyle(color: Color(0xFF10B981), fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white70),
            label: const Text('Copy Text', style: TextStyle(color: Colors.white70)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: kotText.toString()));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('KOT copied to clipboard!')),
              );
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
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
                  'Merchant Order Desk',
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
              '${model.shortId} • Shop Owner View',
              style: TextStyle(color: textSecondary, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_rounded, color: Color(0xFF8B5CF6), size: 20),
            tooltip: 'Print / View KOT',
            onPressed: () => _showPrintKotDialog(model),
          ),
          IconButton(
            icon: const Icon(Icons.navigation_rounded, color: Color(0xFF2563EB), size: 20),
            tooltip: 'Live Driver Tracker',
            onPressed: _openLiveTracking,
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
            _buildShopHeroBanner(model, isDark),
            const SizedBox(height: 14),

            // 2. Pending Review Actions (Accept / Reject)
            if (_currentStatus == TaskStatus.pending) ...[
              _buildPendingReviewCard(model, isDark),
              const SizedBox(height: 14),
            ],

            // 3. Store Packing Checklist
            _buildStorePackingChecklist(model, isDark),
            const SizedBox(height: 14),

            // 4. Assigned Driver Card & Market Broadcast
            _buildAssignedDriverSection(model, isDark),
            const SizedBox(height: 14),

            // 5. Customer & Khata Details
            _buildCustomerKhataCard(model, isDark),
            const SizedBox(height: 14),

            // 6. Security Handover PIN (Shop gives to driver)
            if (_task['pickupOtp'] != null) ...[
              _buildHandoverPinCard(model, isDark),
              const SizedBox(height: 14),
            ],

            // 7. Order Items & Financials
            _buildFinancialsCard(model, isDark),
            const SizedBox(height: 14),

            // 8. Lifecycle Logs
            _buildLifecycleLogs(model, isDark),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Status Hero Banner ──────────────────────────────────────────────────
  Widget _buildShopHeroBanner(TaskModel model, bool isDark) {
    Color color = _currentStatus.color;
    IconData icon = _currentStatus.icon;
    String title = '';
    String subtitle = '';

    switch (_currentStatus) {
      case TaskStatus.pending:
        title = 'Incoming Order Review Required';
        subtitle = 'Please review items, verify availability, and accept to broadcast to drivers.';
        icon = Icons.notification_important_rounded;
        break;
      case TaskStatus.assign:
        title = 'Order Confirmed • Packing In Progress';
        subtitle = model.driverName != null
            ? '${model.driverName} is arriving at your store for pickup.'
            : 'Broadcasting to nearby drivers. You can also post to open market.';
        icon = Icons.inventory_2_rounded;
        break;
      case TaskStatus.ongoing:
        title = 'Handed Over • In Transit to Customer';
        subtitle = 'Driver has collected items and is heading to customer delivery address.';
        icon = Icons.delivery_dining_rounded;
        break;
      case TaskStatus.completed:
        title = 'Delivered & Settled 🎉';
        subtitle = 'Order successfully delivered. Counter payment settled / debited to Khata.';
        icon = Icons.check_circle_rounded;
        break;
      case TaskStatus.cancelled:
        title = 'Order Rejected / Cancelled';
        subtitle = model.shopRejectionReason ?? 'Order was not fulfilled.';
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

  // ─── Pending Review Card (Accept / Reject) ────────────────────────────────
  Widget _buildPendingReviewCard(TaskModel model, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gavel_rounded, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Text('Acceptance & OTP Policy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Require Driver Pickup OTP Handover', style: TextStyle(fontSize: 13)),
            value: _reqPickupOtp,
            onChanged: (v) => setState(() => _reqPickupOtp = v ?? true),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Require Customer Delivery OTP at Doorstep', style: TextStyle(fontSize: 13)),
            value: _reqDropOtp,
            onChanged: (v) => setState(() => _reqDropOtp = v ?? true),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isLoading ? null : _handleRejectOrder,
                  child: const Text('Reject Order', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isLoading ? null : _handleConfirmOrder,
                  child: const Text('Confirm & Dispatch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Store Packing Checklist ─────────────────────────────────────────────
  Widget _buildStorePackingChecklist(TaskModel model, bool isDark) {
    final items = model.parsedOrderItems;

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
              const Icon(Icons.inventory_rounded, color: Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 8),
              const Text('Store Packing Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              Text(
                '${_packedItems.length}/${items.length} Packed',
                style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isNotEmpty) ...[
            ...List.generate(items.length, (idx) {
              final it = items[idx];
              final name = it['name']?.toString() ?? 'Item';
              final qty = it['quantity'] ?? it['qty'] ?? 1;
              final isPacked = _packedItems.contains(idx);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isPacked) {
                      _packedItems.remove(idx);
                    } else {
                      _packedItems.add(idx);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        isPacked ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                        color: isPacked ? const Color(0xFF10B981) : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13,
                            decoration: isPacked ? TextDecoration.lineThrough : null,
                            color: isPacked ? Colors.grey : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                      ),
                      Text('${qty}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              );
            }),
          ] else ...[
            Text(_task['orderItems']?.toString() ?? 'Standard store items', style: const TextStyle(fontSize: 13)),
          ],
        ],
      ),
    );
  }

  // ─── Assigned Driver & Market Broadcast ──────────────────────────────────
  Widget _buildAssignedDriverSection(TaskModel model, bool isDark) {
    final hasDriver = model.driverName != null && model.driverName!.isNotEmpty;

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
              const Icon(Icons.two_wheeler_rounded, color: Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              const Text('Assigned Driver / Fleet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              if (hasDriver && model.driverPhone != null) ...[
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
          const SizedBox(height: 8),
          if (hasDriver) ...[
            Text(model.driverName!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text('${model.vehicleMakeModel ?? "Vehicle"} • ${model.vehiclePlateNumber ?? ""}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ] else ...[
            const Text('No driver assigned yet.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.cell_tower_rounded, color: Colors.white, size: 18),
              label: const Text('Broadcast to Market Drivers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _handlePostToMarket,
            ),
          ],
        ],
      ),
    );
  }

  // ─── Customer Khata Card ─────────────────────────────────────────────────
  Widget _buildCustomerKhataCard(TaskModel model, bool isDark) {
    final mode = model.paymentMode ?? 'Cash';
    final isKhata = mode.toLowerCase().contains('dues') || mode.toLowerCase().contains('khata');

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
              const Icon(Icons.person_outline_rounded, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              const Text('Customer & Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              if (isKhata)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                  child: const Text('KHATA / DUES', style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(model.customerName ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 2),
          Text(model.dropoffAddress, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  // ─── Handover PIN Card ───────────────────────────────────────────────────
  Widget _buildHandoverPinCard(TaskModel model, bool isDark) {
    final pickupOtp = _task['pickupOtp']?.toString();
    if (pickupOtp == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Store Handover PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Give to driver upon handing over package', style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          Text(
            pickupOtp,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF8B5CF6), letterSpacing: 4),
          ),
        ],
      ),
    );
  }

  // ─── Financials Card ─────────────────────────────────────────────────────
  Widget _buildFinancialsCard(TaskModel model, bool isDark) {
    final fare = model.estimatedFare ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Total Order Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text('₹${fare.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }

  // ─── Lifecycle Logs ──────────────────────────────────────────────────────
  Widget _buildLifecycleLogs(TaskModel model, bool isDark) {
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
          const Text('Order Activity Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 10),
          ...logs.map((log) {
            final ev = log['eventType']?.toString() ?? '';
            final tm = log['loggedAt']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 8, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ev, style: const TextStyle(fontSize: 12))),
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
