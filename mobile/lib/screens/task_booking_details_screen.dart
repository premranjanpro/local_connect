import 'package:flutter/material.dart';
import '../models/task_status_models.dart';
import 'order_details/customer_order_detail_screen.dart';
import 'order_details/driver_order_detail_screen.dart';
import 'order_details/shop_owner_order_detail_screen.dart';

/// ══════════════════════════════════════════════════════════════════════════════
///  Task / Booking Details Router Screen
///  Cleanly delegates to role-tailored dedicated order details modules:
///    - Customer: CustomerOrderDetailScreen (5 statuses, live map, OTP, bills)
///    - Driver: DriverOrderDetailScreen (5 statuses, navigation, checklist, OTP)
///    - Shop Owner: ShopOwnerOrderDetailScreen (5 statuses, review, KOT, market)
/// ══════════════════════════════════════════════════════════════════════════════
class TaskBookingDetailsScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final role = userRole.toLowerCase().trim();

    if (role == 'driver') {
      return DriverOrderDetailScreen(
        taskId: taskId,
        token: token,
        initialTaskData: initialTaskData,
        initialTask: initialTask,
      );
    } else if (role == 'merchant' || role == 'shop' || role == 'vendor' || role == 'shopowner') {
      return ShopOwnerOrderDetailScreen(
        taskId: taskId,
        token: token,
        initialTaskData: initialTaskData,
        initialTask: initialTask,
      );
    } else {
      return CustomerOrderDetailScreen(
        taskId: taskId,
        token: token,
        initialTaskData: initialTaskData,
        initialTask: initialTask,
      );
    }
  }
}
