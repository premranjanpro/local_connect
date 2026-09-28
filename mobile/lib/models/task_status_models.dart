import 'dart:convert';
import 'package:flutter/material.dart';

// ──────────────────────────────────────────────
//  5-Status System
// ──────────────────────────────────────────────
enum TaskStatus {
  pending,
  assign,
  ongoing,
  completed,
  cancelled,
}

extension TaskStatusExt on TaskStatus {
  String get label {
    switch (this) {
      case TaskStatus.pending:
        return 'PENDING';
      case TaskStatus.assign:
        return 'ASSIGNED';
      case TaskStatus.ongoing:
        return 'ONGOING';
      case TaskStatus.completed:
        return 'COMPLETED';
      case TaskStatus.cancelled:
        return 'CANCELLED';
    }
  }

  Color get color {
    switch (this) {
      case TaskStatus.pending:
        return const Color(0xFFF59E0B);
      case TaskStatus.assign:
        return const Color(0xFF3B82F6);
      case TaskStatus.ongoing:
        return const Color(0xFF8B5CF6);
      case TaskStatus.completed:
        return const Color(0xFF10B981);
      case TaskStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  Color get bgColor {
    switch (this) {
      case TaskStatus.pending:
        return const Color(0xFFF59E0B).withValues(alpha: 0.15);
      case TaskStatus.assign:
        return const Color(0xFF3B82F6).withValues(alpha: 0.15);
      case TaskStatus.ongoing:
        return const Color(0xFF8B5CF6).withValues(alpha: 0.15);
      case TaskStatus.completed:
        return const Color(0xFF10B981).withValues(alpha: 0.15);
      case TaskStatus.cancelled:
        return const Color(0xFFEF4444).withValues(alpha: 0.15);
    }
  }

  IconData get icon {
    switch (this) {
      case TaskStatus.pending:
        return Icons.hourglass_empty_rounded;
      case TaskStatus.assign:
        return Icons.assignment_ind_rounded;
      case TaskStatus.ongoing:
        return Icons.local_shipping_rounded;
      case TaskStatus.completed:
        return Icons.check_circle_rounded;
      case TaskStatus.cancelled:
        return Icons.cancel_rounded;
    }
  }
}

TaskStatus taskStatusFromString(String? s) {
  switch ((s ?? '').toLowerCase()) {
    case 'pending':
      return TaskStatus.pending;
    case 'assign':
    case 'assigned':
    case 'en_route_pickup':
    case 'at_pickup':
      return TaskStatus.assign;
    case 'ongoing':
    case 'picked_up':
    case 'at_drop':
    case 'intransit':
      return TaskStatus.ongoing;
    case 'completed':
    case 'delivered':
      return TaskStatus.completed;
    case 'cancel':
    case 'cancelled':
    case 'rejected':
      return TaskStatus.cancelled;
    default:
      return TaskStatus.pending;
  }
}

// ──────────────────────────────────────────────
//  Task / Booking Model
// ──────────────────────────────────────────────
class TaskModel {
  final String id;
  final String taskType;
  final TaskStatus status;
  final String pickupAddress;
  final String dropoffAddress;
  final double? estimatedFare;
  final String? driverName;
  final String? driverPhone;
  final String? pickupOtp;
  final String? dropoffOtp;
  final DateTime createdAt;
  final DateTime? assignedAt;
  final DateTime? completedAt;
  final String? paymentMode;
  final double? distanceKm;
  final String? vehicleType;
  final String? shopName;
  final String? customerName;
  final String? customerPhone;
  final String? assignedDriverId;
  final String? driverAvatarUrl;
  final String? driverDlNumber;
  final double? driverRating;
  final String? vehiclePlateNumber;
  final String? vehicleColor;
  final String? vehiclePhotoUrl;
  final String? vehicleMakeModel;
  final List<dynamic> items;
  final Map<String, dynamic> raw;

  const TaskModel({
    required this.id,
    required this.taskType,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddress,
    this.estimatedFare,
    this.driverName,
    this.driverPhone,
    this.pickupOtp,
    this.dropoffOtp,
    required this.createdAt,
    this.assignedAt,
    this.completedAt,
    this.paymentMode,
    this.distanceKm,
    this.vehicleType,
    this.shopName,
    this.customerName,
    this.customerPhone,
    this.assignedDriverId,
    this.driverAvatarUrl,
    this.driverDlNumber,
    this.driverRating,
    this.vehiclePlateNumber,
    this.vehicleColor,
    this.vehiclePhotoUrl,
    this.vehicleMakeModel,
    this.items = const [],
    this.raw = const {},
  });

  factory TaskModel.fromJson(Map<String, dynamic> j) {
    final driverObj = j['driver'] is Map<String, dynamic> ? j['driver'] as Map<String, dynamic> : null;
    final vehicleObj = driverObj != null && driverObj['vehicle'] is Map<String, dynamic>
        ? driverObj['vehicle'] as Map<String, dynamic>
        : (j['activeVehicle'] is Map<String, dynamic> ? j['activeVehicle'] as Map<String, dynamic> : null);

    return TaskModel(
      id: j['id']?.toString() ?? '',
      taskType: j['taskType']?.toString() ?? 'Delivery',
      status: taskStatusFromString(j['status']?.toString()),
      pickupAddress: j['pickupAddress']?.toString() ?? 'Pickup Location',
      dropoffAddress: j['dropoffAddress']?.toString() ??
          j['deliveryAddress']?.toString() ??
          'Drop Location',
      estimatedFare: (j['estimatedFare'] as num?)?.toDouble() ??
          (j['totalAmount'] as num?)?.toDouble(),
      driverName: j['driverName']?.toString() ??
          j['assignedDriverName']?.toString() ??
          driverObj?['fullName']?.toString(),
      driverPhone: j['driverPhone']?.toString() ?? driverObj?['phone']?.toString(),
      pickupOtp: j['pickupOtp']?.toString(),
      dropoffOtp: j['dropoffOtp']?.toString(),
      createdAt:
          DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
      assignedAt:
          DateTime.tryParse(j['assignedAt']?.toString() ?? ''),
      completedAt:
          DateTime.tryParse(j['completedAt']?.toString() ?? ''),
      paymentMode: j['paymentMode']?.toString() ??
          j['payment_mode']?.toString(),
      distanceKm: (j['distanceKm'] as num?)?.toDouble(),
      vehicleType: j['vehicleType']?.toString() ?? vehicleObj?['vehicleType']?.toString(),
      shopName: j['businessName']?.toString() ?? j['shopName']?.toString(),
      customerName: j['customerName']?.toString(),
      customerPhone: j['customerPhone']?.toString() ?? j['customer_phone']?.toString(),
      assignedDriverId: j['assignedDriverId']?.toString() ?? driverObj?['id']?.toString(),
      driverAvatarUrl: j['driverAvatarUrl']?.toString() ?? driverObj?['avatarUrl']?.toString(),
      driverDlNumber: j['driverDlNumber']?.toString() ?? driverObj?['dlNumber']?.toString(),
      driverRating: (j['driverRating'] as num?)?.toDouble() ?? (driverObj?['rating'] as num?)?.toDouble(),
      vehiclePlateNumber: j['vehiclePlateNumber']?.toString() ?? vehicleObj?['plateNumber']?.toString(),
      vehicleColor: j['vehicleColor']?.toString() ?? vehicleObj?['color']?.toString(),
      vehiclePhotoUrl: j['vehiclePhotoUrl']?.toString() ?? vehicleObj?['photoUrl']?.toString(),
      vehicleMakeModel: j['vehicleMakeModel']?.toString() ??
          (vehicleObj != null ? '${vehicleObj['make']} ${vehicleObj['model']}' : null),
      items: (j['items'] as List?) ?? [],
      raw: j,
    );
  }

  String get shortId =>
      id.length > 8 ? '#${id.substring(0, 8).toUpperCase()}' : '#$id';

  String get taskTypeLabel {
    switch (taskType) {
      case 'MobilityRide':
        return 'Cab Ride';
      case 'GroceryDelivery':
        return 'Grocery';
      case 'CourierPickup':
        return 'Courier';
      case 'FoodDelivery':
        return 'Food';
      case 'MorningMilk':
        return 'Morning Run';
      case 'SchoolTransport':
      case 'SchoolService':
        return 'School Ride';
      default:
        return taskType;
    }
  }

  IconData get taskIcon {
    switch (taskType) {
      case 'MobilityRide':
        return Icons.local_taxi_rounded;
      case 'GroceryDelivery':
        return Icons.shopping_basket_rounded;
      case 'CourierPickup':
        return Icons.inventory_2_rounded;
      case 'FoodDelivery':
        return Icons.fastfood_rounded;
      case 'MorningMilk':
        return Icons.breakfast_dining_rounded;
      case 'SchoolTransport':
      case 'SchoolService':
        return Icons.directions_bus_rounded;
      default:
        return Icons.delivery_dining_rounded;
    }
  }

  String? get businessPhone => raw['businessPhone']?.toString();
  String? get businessAddress => raw['businessAddress']?.toString();
  String? get businessCategory => raw['businessCategory']?.toString();
  double get businessRating => (raw['businessRating'] as num?)?.toDouble() ?? 5.0;
  bool get requiresShopConfirm => raw['requiresShopConfirm'] == true;
  DateTime? get shopConfirmedAt => DateTime.tryParse(raw['shopConfirmedAt']?.toString() ?? '');
  String? get shopRejectionReason => raw['shopRejectionReason']?.toString();
  bool get isMarketPosted => raw['isMarketPosted'] == true;
  double? get marketFareOffer => (raw['marketFareOffer'] as num?)?.toDouble();
  bool get isPickupOtpRequired => raw['isPickupOtpRequired'] != false;
  bool get isDropOtpRequired => raw['isDropOtpRequired'] != false;
  DateTime? get cancelledAt => DateTime.tryParse(raw['cancelledAt']?.toString() ?? '');
  double? get driverLatitude => (raw['driverLatitude'] as num?)?.toDouble();
  double? get driverLongitude => (raw['driverLongitude'] as num?)?.toDouble();
  double? get driverHeading => (raw['driverHeading'] as num?)?.toDouble();
  double? get driverSpeedKmph => (raw['driverSpeedKmph'] as num?)?.toDouble();
  List<dynamic> get deliveryLogs => (raw['deliveryLogs'] as List?) ?? [];
  List<dynamic> get stops => (raw['stops'] as List?) ?? [];

  List<Map<String, dynamic>> get parsedOrderItems {
    final rawItems = raw['orderItems'] ?? raw['items'];
    if (rawItems == null) return [];
    if (rawItems is List) {
      return rawItems.map((e) {
        if (e is Map<String, dynamic>) return e;
        return {'name': e.toString(), 'quantity': 1, 'price': 0.0};
      }).toList();
    }
    if (rawItems is String && rawItems.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawItems);
        if (decoded is List) {
          return decoded.map((e) {
            if (e is Map<String, dynamic>) return e;
            return {'name': e.toString(), 'quantity': 1, 'price': 0.0};
          }).toList();
        }
      } catch (_) {
        return [
          {'name': rawItems, 'quantity': 1, 'price': estimatedFare ?? 0.0}
        ];
      }
    }
    return [];
  }
}

// ──────────────────────────────────────────────
//  Dashboard Stats Model
// ──────────────────────────────────────────────
class DashboardStats {
  final int pending;
  final int assigned;
  final int ongoing;
  final int completed;
  final int cancelled;
  final double totalEarnings;
  final int totalTasks;

  const DashboardStats({
    this.pending = 0,
    this.assigned = 0,
    this.ongoing = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.totalEarnings = 0,
    this.totalTasks = 0,
  });

  factory DashboardStats.fromTasks(List<TaskModel> tasks) {
    int p = 0, a = 0, o = 0, c = 0, x = 0;
    double earn = 0;
    for (final t in tasks) {
      switch (t.status) {
        case TaskStatus.pending:
          p++;
        case TaskStatus.assign:
          a++;
        case TaskStatus.ongoing:
          o++;
        case TaskStatus.completed:
          c++;
          earn += t.estimatedFare ?? 0;
        case TaskStatus.cancelled:
          x++;
      }
    }
    return DashboardStats(
      pending: p,
      assigned: a,
      ongoing: o,
      completed: c,
      cancelled: x,
      totalEarnings: earn,
      totalTasks: tasks.length,
    );
  }
}
