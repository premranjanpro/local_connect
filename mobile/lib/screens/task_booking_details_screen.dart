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
    final role = widget.userRole.toLowerCase();
    return Scaffold(
      backgroundColor: const Color(0xFF050A15),
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: _buildRoleStatusView(role),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
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
      backgroundColor: const Color(0xFF050A15),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              statusColor.withValues(alpha: 0.12),
              const Color(0xFF050A15),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(
            bottom: BorderSide(
                color: statusColor.withValues(alpha: 0.2), width: 0.8),
          ),
        ),
      ),
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 16),
        ),
      ),
      title: Row(
        children: [
          // Role emoji badge
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [statusColor.withValues(alpha: 0.3),
                    statusColor.withValues(alpha: 0.1)]),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Center(child: Text(roleEmoji,
                style: const TextStyle(fontSize: 14))),
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
                        '${widget.userRole} View',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700,
                            fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Animated status pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_currentStatus.icon,
                              color: statusColor, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            _currentStatus.label,
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  'Order #$shortId',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 10,
                      letterSpacing: 0.5),
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
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.refresh_rounded,
                color: Colors.white70, size: 18),
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
      // Default: Customer
      switch (_currentStatus) {
        case TaskStatus.pending:
          return _buildCustomerPendingView();
        case TaskStatus.assign:
          return _buildCustomerAssignedView();
        case TaskStatus.ongoing:
          return _buildCustomerOngoingView();
        case TaskStatus.completed:
          return _buildCustomerCompletedView();
        case TaskStatus.cancelled:
          return _buildCustomerCancelledView();
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════════
  //  1. CUSTOMER - 5 DESIGNS
  // ══════════════════════════════════════════════════════════════════════════════

  /// Customer #1: PENDING
  Widget _buildCustomerPendingView() {
    final fare = _task['fareAmount'] ?? _task['estimatedFare'] ?? 150;
    final pickup = _task['pickupAddress'] ?? 'Nearby Store';
    final drop = _task['dropoffAddress'] ?? 'Your Location';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Radar Pulse Animation Card
          ScaleTransition(
            scale: _pulseAnim,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFFF59E0B).withValues(alpha: 0.15), const Color(0xFF1E293B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.radar_rounded, color: Color(0xFFF59E0B), size: 48),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Searching Nearby Drivers & Stores',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Broadcasting within 5 km radius. Your order is pending acceptance.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Order Summary Card
          _buildInfoCard(
            title: 'Order Overview',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFF3B82F6),
            children: [
              _buildKeyValue('Estimated Fare', '₹$fare', valueColor: const Color(0xFF10B981)),
              _buildKeyValue('Pickup Point', pickup),
              _buildKeyValue('Delivery Point', drop),
              _buildKeyValue('Payment Mode', _task['paymentMode'] ?? 'Cash on Delivery'),
            ],
          ),
          const SizedBox(height: 20),

          // Priority Action: Customer can delete/cancel pending orders
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmDeletePendingOrder,
              icon: const Icon(Icons.delete_forever_rounded, color: Colors.white),
              label: const Text('Cancel & Permanently Delete', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Customer #2: ASSIGNED
  Widget _buildCustomerAssignedView() {
    final driverName = _task['driverName'] ?? _task['driver']?['fullName'] ?? 'Ramesh Kumar Driver';
    final driverPhone = _task['driverPhone'] ?? _task['driver']?['phone'] ?? '+919876543210';
    final vehiclePlate = _task['vehiclePlateNumber'] ?? 'RJ14-AB-1234';
    final vehicleColor = _task['vehicleColor'] ?? 'Flame Red';
    final vehicleModel = _task['vehicleMakeModel'] ?? 'Hero Splendor Plus';
    final driverId = _task['assignedDriverId']?.toString() ?? 'd2daea1b-32dc-4bef-89db-fab0a1de7976';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF1E293B)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Color(0xFF60A5FA), size: 36),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Driver Partner Assigned!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Driver is preparing and on way to pickup point.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Driver Profile Card (Tap opens Driver Profile Sheet)
          GestureDetector(
            onTap: () => showDriverProfileSheet(context, driverId: driverId),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: NetworkImage(
                          _task['driverAvatarUrl'] ?? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(driverName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 2),
                            const Text('⭐⭐⭐⭐⭐ 5.0 (87 Trips)', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('$vehiclePlate • $vehicleColor $vehicleModel', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () => _callUser(driverPhone, driverName, 'Driver'),
                        icon: const Icon(Icons.call_rounded, color: Color(0xFF10B981)),
                        label: const Text('Call Driver', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                      ),
                      TextButton.icon(
                        onPressed: () => showDriverProfileSheet(context, driverId: driverId),
                        icon: const Icon(Icons.badge_rounded, color: Color(0xFF60A5FA)),
                        label: const Text('View Profile', style: TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Route Details
          _buildInfoCard(
            title: 'Trip Route',
            icon: Icons.alt_route_rounded,
            color: const Color(0xFF8B5CF6),
            children: [
              _buildKeyValue('Pickup Address', _task['pickupAddress'] ?? 'Store'),
              _buildKeyValue('Delivery Address', _task['dropoffAddress'] ?? 'Home'),
              _buildKeyValue('ETA to Pickup', '~8 mins', valueColor: const Color(0xFF38BDF8)),
            ],
          ),
        ],
      ),
    );
  }

  /// Customer #3: ONGOING
  Widget _buildCustomerOngoingView() {
    final pickupOtp = _task['pickupOtp']?.toString() ?? '582103';
    final dropOtp = _task['dropoffOtp']?.toString() ?? '924185';
    final isDropOtpRequired = _task['isDropOtpRequired'] ?? true;
    final driverName = _task['driverName'] ?? 'Ramesh Kumar Driver';

    return Column(
      children: [
        // Live GPS Map View (Top 40%)
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.38,
          child: FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _driverPos,
              initialZoom: 14.5,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.shopconnector.app',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _driverPos,
                    width: 50,
                    height: 50,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Color(0x663B82F6), blurRadius: 10, spreadRadius: 3)],
                      ),
                      child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Live Ongoing Bottom Panel
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // MASTER OTP CARD (Priority #1)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF312E81), Color(0xFF1E293B)]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF818CF8).withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock_rounded, color: Color(0xFFA5B4FC), size: 18),
                          SizedBox(width: 8),
                          Text('Delivery Verification Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_task['pickupOtp'] != null) ...[
                            _buildOtpBadge('Pickup OTP', pickupOtp),
                            const SizedBox(width: 14),
                          ],
                          if (isDropOtpRequired)
                            _buildOtpBadge('Drop OTP', dropOtp),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Share this OTP with driver only when your order is delivered to you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Driver Action Bar
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _callUser('+919876543210', driverName, 'Driver'),
                        icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white),
                        label: const Text('Call Driver'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => AudioToneService.playStatusUpdateTone(),
                        icon: const Icon(Icons.share_location_rounded, color: Color(0xFF38BDF8)),
                        label: const Text('Share Track', style: TextStyle(color: Color(0xFF38BDF8))),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF38BDF8))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Customer #4: COMPLETED
  Widget _buildCustomerCompletedView() {
    final fare = _task['fareAmount'] ?? 245;
    final driverName = _task['driverName'] ?? 'Ramesh Kumar Driver';
    final shopName = _task['businessName'] ?? 'Gupta Super Store';
    final shopId = _task['businessId']?.toString() ?? 'shop-101';
    final driverId = _task['assignedDriverId']?.toString() ?? 'drv-301';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Celebration Card
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF1E293B)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 14),
                const Text('Delivered & Completed!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Thank you for ordering with ShopConnector.', style: TextStyle(color: Colors.white60, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Rating Banner (Priority #1 on completed)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.stars_rounded, color: Color(0xFFF59E0B), size: 24),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('How was your trip and store items?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showOrderRatingBottomSheet(
                        context,
                        task: _currentTaskModel,
                        viewerRole: 'Customer',
                      );
                    },
                    icon: const Icon(Icons.rate_review_rounded, color: Colors.black),
                    label: const Text('⭐ Rate Driver & Shop Now', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Receipt Breakdown
          _buildInfoCard(
            title: 'Bill & Receipt',
            icon: Icons.receipt_rounded,
            color: const Color(0xFF10B981),
            children: [
              _buildKeyValue('Total Amount Paid', '₹$fare', valueColor: const Color(0xFF34D399)),
              _buildKeyValue('Delivery Mode', 'Zero Commission Direct Handover'),
              _buildKeyValue('Completed At', 'Today at 1:15 PM'),
            ],
          ),
          const SizedBox(height: 16),

          // Store & Driver Quick Profiles
          _buildInfoCard(
            title: 'Store & Partner Profiles',
            icon: Icons.storefront_rounded,
            color: const Color(0xFF38BDF8),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(shopName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: () => showShopProfileSheet(context, businessId: shopId),
                    icon: const Icon(Icons.storefront_rounded, size: 14, color: Color(0xFF10B981)),
                    label: const Text('Store Profile', style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(driverName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: () => showDriverProfileSheet(context, driverId: driverId),
                    icon: const Icon(Icons.person_pin_rounded, size: 14, color: Color(0xFF3B82F6)),
                    label: const Text('Driver Profile', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Customer #5: CANCELLED
  Widget _buildCustomerCancelledView() {
    final reason = _task['shopRejectionReason'] ?? 'Cancelled by customer before dispatch';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7F1D1D), Color(0xFF1E293B)]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 48),
                const SizedBox(height: 14),
                const Text('Order Cancelled', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Reason: $reason', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoCard(
            title: 'Khata / Payment Status',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF38BDF8),
            children: [
              _buildKeyValue('Deduction', '₹ 0.00 (No penalty charged)'),
              _buildKeyValue('Status', 'Refunded / Neutral Khata'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Book Another Ride or Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
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
              gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF1E293B)]),
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
              gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF1E293B)]),
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
              gradient: const LinearGradient(colors: [Color(0xFF312E81), Color(0xFF1E293B)]),
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
              gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF1E293B)]),
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
              gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF1E293B)]),
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
              gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF1E293B)]),
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
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.3)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
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
          gradient: const LinearGradient(
            colors: [Color(0xFF2D1F7F), Color(0xFF1A1060)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
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
