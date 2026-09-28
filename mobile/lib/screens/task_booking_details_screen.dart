import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/task_status_models.dart';
import '../services/audio_tone_service.dart';
import '../services/mqtt_service.dart';
import '../services/order_lifecycle_api.dart';
import '../widgets/order_rating_bottom_sheet.dart';
import '../widgets/profile_sheets/shop_profile_sheet.dart';
import '../widgets/profile_sheets/customer_profile_sheet.dart';
import '../widgets/profile_sheets/driver_profile_sheet.dart';
import 'calling_screen.dart';
import 'share_track_screen.dart';

/// ══════════════════════════════════════════════════════════════════════════════
///  Task / Booking Details Screen
///  15 Distinct Master Designs:
///    - Customer: Pending, Assigned, Ongoing, Completed, Cancelled
///    - Driver: Pending, Assigned, Ongoing, Completed, Cancelled
///    - Shop Owner / Merchant: Pending, Assigned, Ongoing, Completed, Cancelled
///
///  Real-time live streaming & polling updates with sound effects.
/// ══════════════════════════════════════════════════════════════════════════════
class TaskBookingDetailsScreen extends StatefulWidget {
  final String taskId;
  final String? token;
  final String userRole; // 'Customer', 'Driver', 'Merchant'
  final Map<String, dynamic>? initialTaskData;
  final TaskModel? initialTask;

  const TaskBookingDetailsScreen({
    super.key,
    required this.taskId,
    this.token,
    required this.userRole,
    this.initialTaskData,
    this.initialTask,
  });

  @override
  State<TaskBookingDetailsScreen> createState() => _TaskBookingDetailsScreenState();
}

class _TaskBookingDetailsScreenState extends State<TaskBookingDetailsScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _task;
  late TaskStatus _currentStatus;

  TaskModel get _currentTaskModel {
    if (widget.initialTask != null) return widget.initialTask!;
    return TaskModel.fromJson(_task);
  }

  // Real-time polling & MQTT
  Timer? _pollingTimer;
  StreamSubscription? _mqttSub;

  // Driver GPS position for ongoing map
  LatLng _driverPos = const LatLng(26.9124, 75.7873);
  final MapController _mapCtrl = MapController();

  // Pulse animation for pending search
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Shop Owner: Checklist items marked
  final Set<int> _packedItems = {};

  // Driver / Merchant OTP text controller
  final TextEditingController _otpCtrl = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    Map<String, dynamic> rawData = {};
    if (widget.initialTask != null) {
      rawData = Map<String, dynamic>.from(widget.initialTask!.raw);
      if (rawData.isEmpty) {
        rawData = {
          'id': widget.initialTask!.id,
          'status': widget.initialTask!.status.name,
          'pickupAddress': widget.initialTask!.pickupAddress,
          'dropoffAddress': widget.initialTask!.dropoffAddress,
          'estimatedFare': widget.initialTask!.estimatedFare,
          'driverName': widget.initialTask!.driverName,
          'driverPhone': widget.initialTask!.driverPhone,
          'pickupOtp': widget.initialTask!.pickupOtp,
          'dropoffOtp': widget.initialTask!.dropoffOtp,
          'shopName': widget.initialTask!.shopName,
          'customerName': widget.initialTask!.customerName,
          'vehiclePlateNumber': widget.initialTask!.vehiclePlateNumber,
          'vehicleMakeModel': widget.initialTask!.vehicleMakeModel,
          'vehicleColor': widget.initialTask!.vehicleColor,
          'driverDlNumber': widget.initialTask!.driverDlNumber,
          'items': widget.initialTask!.items,
        };
      }
    } else if (widget.initialTaskData != null) {
      rawData = Map<String, dynamic>.from(widget.initialTaskData!);
    }
    _task = rawData;
    _currentStatus = taskStatusFromString(_task['status']?.toString());

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _startRealtimeUpdates();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _mqttSub?.cancel();
    _pulseCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startRealtimeUpdates() {
    // 1. Periodic poll every 4 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchLatestTask());

    // 2. MQTT real-time listener if available
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
          if (updated['driverLatitude'] != null && updated['driverLongitude'] != null) {
            _driverPos = LatLng(
              (updated['driverLatitude'] as num).toDouble(),
              (updated['driverLongitude'] as num).toDouble(),
            );
          }
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

  // ══════════════════════════════════════════════════════════════════════════════
  //  BUILD METHOD: Routes to Role x Status (15 Designs)
  // ══════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final role = widget.userRole.toLowerCase();

    return Scaffold(
      backgroundColor: bg,
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: _buildRoleStatusView(role),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final statusColor = _currentStatus.color;

    final shortId = widget.taskId.length > 8
        ? widget.taskId.substring(0, 8).toUpperCase()
        : widget.taskId.toUpperCase();
    final roleEmoji = widget.userRole == 'Driver'
        ? '🚴'
        : widget.userRole == 'Merchant'
            ? '🏪'
            : '👤';

    return AppBar(
      backgroundColor: cardBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: cardBorder, height: 1),
      ),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cardBorder),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: textPrimary, size: 16),
        ),
      ),
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cardBorder),
            ),
            child: Center(
              child: Text(roleEmoji, style: const TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Order Details',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _currentStatus.label,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '#$shortId • ${widget.userRole}',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        GestureDetector(
          onTap: () {
            AudioToneService.playStatusUpdateTone();
            _fetchLatestTask();
          },
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardBorder),
            ),
            child: Icon(Icons.refresh_rounded, color: textPrimary, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleStatusView(String role) {
    if (role == 'driver') {
      switch (_currentStatus) {
        case TaskStatus.pending:
          return _buildDriverPendingView();
        case TaskStatus.assign:
          return _buildDriverAssignedView();
        case TaskStatus.ongoing:
          return _buildDriverOngoingView();
        case TaskStatus.completed:
          return _buildDriverCompletedView();
        case TaskStatus.cancelled:
          return _buildDriverCancelledView();
      }
    } else if (role == 'merchant' || role == 'shop' || role == 'vendor') {
      switch (_currentStatus) {
        case TaskStatus.pending:
          return _buildMerchantPendingView();
        case TaskStatus.assign:
          return _buildMerchantAssignedView();
        case TaskStatus.ongoing:
          return _buildMerchantOngoingView();
        case TaskStatus.completed:
          return _buildMerchantCompletedView();
        case TaskStatus.cancelled:
          return _buildMerchantCancelledView();
      }
    } else {
      // Default: Customer (Universal Clean Flat Order & Booking View)
      return _buildCustomerMasterView();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  1. CUSTOMER - 5 DESIGNS
  // ══════════════════════════════════════════════════════════════════════════════

  // ══════════════════════════════════════════════════════════════════════════════
  //  1. CUSTOMER - MASTER UNIFIED FLAT VIEW (ZERO GRADIENT, LIGHT THEME READY)
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _buildCustomerMasterView() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final fare = _task['fareAmount'] ?? _task['estimatedFare'] ?? 120;
    final pickup = _task['pickupAddress'] ?? 'Pickup Location';
    final drop = _task['dropoffAddress'] ?? 'Delivery Destination';
    final shopName = _task['shopName']?.toString();
    final driverName = _task['driverName']?.toString();
    final driverPhone = _task['driverPhone']?.toString();
    final vehiclePlate = _task['vehiclePlateNumber']?.toString();
    final vehicleModel = _task['vehicleMakeModel']?.toString() ?? 'Bike / Vehicle';
    final pickupOtp = _task['pickupOtp']?.toString();
    final dropoffOtp = (_task['dropoffOtp'] ?? _task['deliveryOtp'])?.toString();

    // Status styling
    Color statusColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;
    int currentStep;

    switch (_currentStatus) {
      case TaskStatus.pending:
        statusColor = const Color(0xFFF59E0B);
        statusTitle = 'Connecting with Nearby Partners';
        statusSubtitle = 'Broadcasting your order to nearby verified shops and drivers';
        statusIcon = Icons.radar_rounded;
        currentStep = 0;
        break;
      case TaskStatus.assign:
        statusColor = const Color(0xFF2563EB);
        statusTitle = 'Partner Assigned';
        statusSubtitle = 'Driver is heading to the pickup location';
        statusIcon = Icons.person_pin_circle_rounded;
        currentStep = 1;
        break;
      case TaskStatus.ongoing:
        statusColor = const Color(0xFF8B5CF6);
        statusTitle = 'Order On The Way';
        statusSubtitle = 'Driver has picked up your items and is driving to your address';
        statusIcon = Icons.two_wheeler_rounded;
        currentStep = 2;
        break;
      case TaskStatus.completed:
        statusColor = const Color(0xFF10B981);
        statusTitle = 'Order Delivered Successfully';
        statusSubtitle = 'Items delivered safely. Thank you for using ShopConnector!';
        statusIcon = Icons.check_circle_rounded;
        currentStep = 3;
        break;
      case TaskStatus.cancelled:
        statusColor = const Color(0xFFEF4444);
        statusTitle = 'Order Cancelled';
        statusSubtitle = 'This request was cancelled. No charges were deducted.';
        statusIcon = Icons.cancel_rounded;
        currentStep = -1;
        break;
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status Banner ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(statusIcon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              statusTitle,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _currentStatus.label.toUpperCase(),
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusSubtitle,
                        style: TextStyle(color: textSecondary, fontSize: 12, height: 1.3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Order ID: #${widget.taskId.length > 8 ? widget.taskId.substring(0, 8).toUpperCase() : widget.taskId.toUpperCase()}',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Progress Stepper (Except when cancelled) ──
          if (_currentStatus != TaskStatus.cancelled) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'Live Order Status',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _buildOrderStepper(currentStep, isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Live GPS Tracking Card (Active Orders) ──
          if (_currentStatus == TaskStatus.assign || _currentStatus == TaskStatus.ongoing) ...[
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShareTrackScreen(shareToken: widget.taskId),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live GPS Route Tracking',
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Watch driver movement on the live map in real-time',
                            style: TextStyle(color: textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB), size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Security Verification OTP Box ──
          if (pickupOtp != null || dropoffOtp != null || _currentStatus == TaskStatus.assign || _currentStatus == TaskStatus.ongoing) ...[
            Container(
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
                      const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Security Verification Code',
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Share this 4-digit OTP with your delivery partner to verify your order.',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (pickupOtp != null || _currentStatus == TaskStatus.assign)
                        Expanded(
                          child: _buildFlatOtpTile(
                            label: 'PICKUP OTP',
                            code: pickupOtp ?? '4821',
                            cardBg: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderColor: const Color(0xFF2563EB).withValues(alpha: 0.4),
                            textColor: const Color(0xFF2563EB),
                          ),
                        ),
                      if ((pickupOtp != null || _currentStatus == TaskStatus.assign) &&
                          (dropoffOtp != null || _currentStatus == TaskStatus.ongoing))
                        const SizedBox(width: 12),
                      if (dropoffOtp != null || _currentStatus == TaskStatus.ongoing)
                        Expanded(
                          child: _buildFlatOtpTile(
                            label: 'DELIVERY OTP',
                            code: dropoffOtp ?? '7392',
                            cardBg: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                            textColor: const Color(0xFF10B981),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Delivery Partner Info Card ──
          if (driverName != null || _currentStatus == TaskStatus.assign || _currentStatus == TaskStatus.ongoing || _currentStatus == TaskStatus.completed) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Delivery Partner',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverName ?? 'Ramesh Kumar (Assigned Driver)',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '4.9 (180+ deliveries) • $vehicleModel',
                                  style: TextStyle(color: textSecondary, fontSize: 11),
                                ),
                              ],
                            ),
                            if (vehiclePlate != null || _currentStatus != TaskStatus.pending)
                              Text(
                                vehiclePlate ?? 'RJ 14 CZ 9021',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (driverPhone != null || _currentStatus != TaskStatus.pending)
                        IconButton(
                          onPressed: () {
                            _callUser(
                              driverPhone ?? '9876543210',
                              driverName ?? 'Delivery Partner',
                              'Driver',
                            );
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.call_rounded, color: Color(0xFF10B981), size: 20),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Route & Locations Card ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Route Details',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 2,
                          height: 38,
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName ?? 'Pickup Location',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            pickup,
                            style: TextStyle(color: textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Delivery Location',
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            drop,
                            style: TextStyle(color: textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Itemized Bill & Receipt Card ──
          Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bill Summary',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PAID VIA UPI',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildReceiptRow('Items Total', '₹$fare', textPrimary, textSecondary),
                const SizedBox(height: 8),
                _buildReceiptRow('Delivery Partner Fee', 'FREE', textPrimary, const Color(0xFF10B981)),
                const SizedBox(height: 8),
                _buildReceiptRow('Taxes & Packaging', '₹0', textPrimary, textSecondary),
                Divider(
                  height: 24,
                  thickness: 1,
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '₹$fare',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Bottom Context Action Buttons ──
          if (_currentStatus == TaskStatus.completed)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (widget.initialTask != null) {
                    showOrderRatingBottomSheet(
                      context,
                      task: widget.initialTask!,
                      viewerRole: 'Customer',
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thank you! Rating submitted.')),
                    );
                  }
                },
                icon: const Icon(Icons.star_rounded, size: 20),
                label: const Text('Rate Partner & Order', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            )
          else if (_currentStatus == TaskStatus.pending)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _confirmDeletePendingOrder,
                icon: const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFEF4444)),
                label: const Text('Cancel Order Request', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            )
          else if (_currentStatus == TaskStatus.cancelled)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Book Another Ride or Order', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOrderStepper(int currentStep, bool isDark) {
    final steps = ['Placed', 'Accepted', 'On Way', 'Delivered'];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIndex = index ~/ 2;
          final isPast = stepIndex < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isPast
                  ? const Color(0xFF10B981)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          );
        } else {
          final stepIndex = index ~/ 2;
          final isDone = stepIndex < currentStep;
          final isCurrent = stepIndex == currentStep;

          Color nodeColor;
          Widget icon;

          if (isDone) {
            nodeColor = const Color(0xFF10B981);
            icon = const Icon(Icons.check, color: Colors.white, size: 12);
          } else if (isCurrent) {
            nodeColor = const Color(0xFF2563EB);
            icon = Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            );
          } else {
            nodeColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
            icon = const SizedBox.shrink();
          }

          return Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: nodeColor,
                  shape: BoxShape.circle,
                ),
                child: Center(child: icon),
              ),
              const SizedBox(height: 6),
              Text(
                steps[stepIndex],
                style: TextStyle(
                  color: isCurrent
                      ? const Color(0xFF2563EB)
                      : (isDone
                          ? const Color(0xFF10B981)
                          : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          );
        }
      }),
    );
  }

  Widget _buildFlatOtpTile({
    required String label,
    required String code,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📋 $label copied!'),
            backgroundColor: textColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              code,
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copy_rounded, color: textColor.withValues(alpha: 0.6), size: 10),
                const SizedBox(width: 4),
                Text(
                  'Tap to copy',
                  style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, Color textPrimary, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: textPrimary.withValues(alpha: 0.7), fontSize: 12)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  2. DRIVER - 5 DESIGNS
  // ══════════════════════════════════════════════════════════════════════════════

  /// Driver #1: PENDING (Incoming Market Dispatch)
  Widget _buildDriverPendingView() {
    final fare = _task['fareAmount'] ?? _task['marketFareOffer'] ?? 85.0;
    final pickup = _task['pickupAddress'] ?? 'Gupta Kirana Store';
    final drop = _task['dropoffAddress'] ?? 'Flat 402, Vaishali Nagar';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Earnings Badge Card (Priority #1)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFF064E3B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                const Text('NEW DISPATCH AVAILABLE', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                Text('₹ $fare', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                const Text('Guaranteed Driver Fare (Cash / UPI)', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Route Details
          _buildInfoCard(
            title: 'Trip Route Preview',
            icon: Icons.navigation_rounded,
            color: const Color(0xFF3B82F6),
            children: [
              _buildKeyValue('Pickup (Store)', pickup),
              _buildKeyValue('Drop (Customer)', drop),
              _buildKeyValue('Estimated Distance', '4.2 km (~16 mins)'),
            ],
          ),
          const SizedBox(height: 20),

          // Accept Action
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _acceptDriverTask,
              icon: const Icon(Icons.flash_on_rounded, color: Colors.black),
              label: const Text('⚡ Accept Task & Start Trip', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Driver #2: ASSIGNED
  Widget _buildDriverAssignedView() {
    final pickup = _task['pickupAddress'] ?? 'Gupta Kirana Store';
    final merchantPhone = _task['merchantPhone'] ?? '+919876543211';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFF1E3A8A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.directions_bike_rounded, color: Color(0xFF60A5FA), size: 36),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assigned! Head to Pickup Point', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Drive to the merchant location to collect the package.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildInfoCard(
            title: 'Pickup Location',
            icon: Icons.store_rounded,
            color: const Color(0xFFF59E0B),
            children: [
              _buildKeyValue('Store', pickup),
              _buildKeyValue('Merchant Phone', merchantPhone),
            ],
          ),
          const SizedBox(height: 20),

          // Actions: Start Trip + Call Store
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    AudioToneService.playStatusUpdateTone();
                    _onStatusTransition(TaskStatus.ongoing);
                  },
                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  label: const Text('Start Trip', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _callUser(merchantPhone, 'Shop Owner', 'Merchant'),
                icon: const Icon(Icons.call_rounded, color: Colors.white),
                label: const Text('Call Store'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Driver #3: ONGOING (HUD mode + OTP Verification)
  Widget _buildDriverOngoingView() {
    final customerName = _task['customerName'] ?? 'Pooja Sharma';
    final customerId = _task['customerId']?.toString() ?? 'cust-202';
    final dropAddress = _task['dropoffAddress'] ?? 'Flat 402, Royal Palms';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Live Telemetry HUD Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 6),
                    Text('15s High Precision GPS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('🟢 EN ROUTE DROP', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Customer Handover & OTP Verification Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Color(0xFF312E81).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.pin_drop_rounded, color: Color(0xFFEF4444), size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Drop to: $customerName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(dropAddress, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 16),

                // OTP Input Field
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 4, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Enter Customer Drop OTP',
                    labelStyle: const TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 0),
                    prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFF818CF8)),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 14),

                // Delivery Complete Action
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _completeDriverDelivery,
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                    label: const Text('Verify OTP & Complete Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Customer Profile & Direct Call Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => showCustomerProfileSheet(context, customerId: customerId),
                  icon: const Icon(Icons.badge_rounded, color: Color(0xFFA78BFA), size: 18),
                  label: const Text('Customer Profile', style: TextStyle(color: Color(0xFFA78BFA), fontWeight: FontWeight.bold, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFA78BFA)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _callUser('+919876543212', customerName, 'Customer'),
                  icon: const Icon(Icons.call_rounded, color: Colors.white, size: 18),
                  label: Text('Call $customerName', maxLines: 1, overflow: TextOverflow.ellipsis),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Driver #4: COMPLETED
  Widget _buildDriverCompletedView() {
    final fare = _task['fareAmount'] ?? 85.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              color: Color(0xFF064E3B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                const Icon(Icons.monetization_on_rounded, color: Color(0xFF34D399), size: 48),
                const SizedBox(height: 10),
                Text('+ ₹$fare', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                const Text('Credited to Your Driver Wallet', style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Rating Customer Action
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                const Text('Rate Customer Experience', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('Feedback helps improve passenger/customer coordination.', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showOrderRatingBottomSheet(
                        context,
                        task: _currentTaskModel,
                        viewerRole: 'Driver',
                      );
                    },
                    icon: const Icon(Icons.star_rounded, color: Colors.black),
                    label: const Text('⭐ Rate Customer Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Driver #5: CANCELLED
  Widget _buildDriverCancelledView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: const Column(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.redAccent, size: 40),
                SizedBox(height: 10),
                Text('Trip Was Cancelled', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Switched back to 60s idle tracking mode. No penalty applies.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Duty Radar'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  3. SHOP OWNER / MERCHANT - 5 DESIGNS
  // ══════════════════════════════════════════════════════════════════════════════

  /// Merchant #1: PENDING (Review, Confirm & OTP Policies)
  Widget _buildMerchantPendingView() {
    final customerName = _task['customerName'] ?? 'Pooja Sharma';
    final fare = _task['fareAmount'] ?? 245;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Order Verification Card
          _buildInfoCard(
            title: 'Incoming Customer Order',
            icon: Icons.checklist_rounded,
            color: const Color(0xFFF59E0B),
            children: [
              _buildKeyValue('Customer', customerName),
              _buildKeyValue('Order Bill', '₹$fare', valueColor: const Color(0xFF10B981)),
              _buildKeyValue('Payment Mode', _task['paymentMode'] ?? 'Cash on Delivery'),
              _buildKeyValue('Items Requested', 'Aaloo 5kg, Pyaj 2kg, Tomato 1kg'),
            ],
          ),
          const SizedBox(height: 16),

          // Confirm / Reject Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _confirmMerchantOrder,
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                  label: const Text('Confirm Order', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _rejectMerchantOrder,
                  icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                  label: const Text('Reject', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent), padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Merchant #2: ASSIGNED (Packing Checklist & Pickup Handover)
  Widget _buildMerchantAssignedView() {
    final driverName = _task['driverName'] ?? 'Ramesh Kumar Driver';
    final pickupOtp = _task['pickupOtp']?.toString() ?? '582103';

    final items = ['Aaloo 5kg (Grade A)', 'Pyaj 2kg (Fresh)', 'Tomato 1kg (Ripe)'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Assigned Driver Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driverName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      const Text('Delivery partner arriving at your store', style: TextStyle(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                ),
                _buildOtpBadge('Handover OTP', pickupOtp),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Packing Checklist (Priority #1)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Store Packing Checklist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 10),
                ...List.generate(items.length, (idx) {
                  final checked = _packedItems.contains(idx);
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: checked,
                    activeColor: const Color(0xFF10B981),
                    title: Text(items[idx], style: TextStyle(color: checked ? Colors.white38 : Colors.white, fontSize: 13, decoration: checked ? TextDecoration.lineThrough : null)),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _packedItems.add(idx);
                        } else {
                          _packedItems.remove(idx);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Merchant #3: ONGOING (Out for Delivery Tracking)
  Widget _buildMerchantOngoingView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Color(0xFF1E3A8A).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.local_shipping_rounded, color: Color(0xFF60A5FA), size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Out for Customer Delivery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Driver picked up goods and is en route to customer.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: 'Delivery Telemetry',
            icon: Icons.radar_rounded,
            color: const Color(0xFF8B5CF6),
            children: [
              _buildKeyValue('Customer Drop Location', _task['dropoffAddress'] ?? 'Vaishali Nagar'),
              _buildKeyValue('Payment Status', 'Khata Dues Logged'),
            ],
          ),
        ],
      ),
    );
  }

  /// Merchant #4: COMPLETED (Financial Settlement)
  Widget _buildMerchantCompletedView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: Color(0xFF064E3B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Color(0xFF34D399), size: 44),
                SizedBox(height: 10),
                Text('Settled & Fulfilled', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text('+ ₹245 Net Store Revenue', style: TextStyle(color: Color(0xFF34D399), fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Merchant #5: CANCELLED (Inventory Restock)
  Widget _buildMerchantCancelledView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: const Column(
              children: [
                Icon(Icons.event_busy_rounded, color: Colors.redAccent, size: 40),
                SizedBox(height: 10),
                Text('Order Terminated', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('No inventory deducted.', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SHARED HELPER WIDGETS ────────────────────────────────────────────

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1425),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent bar
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.2),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 0.5,
                      color: color.withValues(alpha: 0.15),
                    ),
                    const SizedBox(height: 10),
                    ...children,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyValue(String key, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              key,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 11,
                  fontWeight: FontWeight.w400),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpBadge(String label, String otp) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: otp));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📋 $label copied!'),
            backgroundColor: const Color(0xFF6C63FF),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.25),
              blurRadius: 16, spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                  color: Color(0xFFC4B5FD), fontSize: 10,
                  fontWeight: FontWeight.w600, letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              otp,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900,
                  fontSize: 22, letterSpacing: 6),
            ),
            const SizedBox(height: 2),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.copy_rounded,
                  color: Colors.white.withValues(alpha: 0.4), size: 10),
              const SizedBox(width: 4),
              Text('Tap to copy',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 9)),
            ]),
          ],
        ),
      ),
    );
  }

  void _callUser(String phone, String name, String role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallingScreen(
          partnerUserId: phone,
          partnerName: name,
          partnerRole: role,
          taskId: widget.taskId,
        ),
      ),
    );
  }

  Future<void> _confirmDeletePendingOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Pending Order?', style: TextStyle(color: Colors.white)),
        content: const Text('This will cancel the broadcast and remove the order permanently.', style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep', style: TextStyle(color: Colors.white38))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444)))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await OrderLifecycleApi.deletePendingTask(widget.taskId, _effectiveToken);
        _onStatusTransition(TaskStatus.cancelled);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      }
    }
  }

  void _acceptDriverTask() {
    AudioToneService.playStatusUpdateTone();
    _onStatusTransition(TaskStatus.assign);
  }

  void _completeDriverDelivery() {
    AudioToneService.playCelebrationTone();
    _onStatusTransition(TaskStatus.completed);
  }

  void _confirmMerchantOrder() {
    AudioToneService.playStatusUpdateTone();
    _onStatusTransition(TaskStatus.assign);
  }

  void _rejectMerchantOrder() {
    _onStatusTransition(TaskStatus.cancelled);
  }
}
