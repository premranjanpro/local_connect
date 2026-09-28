import 'package:flutter/material.dart';

enum AppNotificationType {
  incomingCall,
  orderUpdate,
  driverAssigned,
  orderCompleted,
  payment,
  dispatchReceived,
  subscriptionAlert,
  generalAlert,
}

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime timestamp;
  final Map<String, dynamic> payload; // Deep-link data
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.timestamp,
    this.payload = const {},
    this.isRead = false,
  });

  factory AppNotification.fromFcmData(Map<String, dynamic> data) {
    final type = _parseType(data['type']?.toString());
    return AppNotification(
      id: data['notificationId'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      title: data['title'] ?? _defaultTitle(type),
      body: data['body'] ?? '',
      timestamp: DateTime.now(),
      payload: data,
      isRead: false,
    );
  }

  static AppNotificationType _parseType(String? raw) {
    switch (raw) {
      case 'incoming_call':
        return AppNotificationType.incomingCall;
      case 'driver_assigned':
        return AppNotificationType.driverAssigned;
      case 'order_completed':
        return AppNotificationType.orderCompleted;
      case 'payment':
        return AppNotificationType.payment;
      case 'dispatch':
        return AppNotificationType.dispatchReceived;
      case 'subscription':
        return AppNotificationType.subscriptionAlert;
      case 'ongoing_order':
      case 'order_update':
        return AppNotificationType.orderUpdate;
      default:
        return AppNotificationType.generalAlert;
    }
  }

  static String _defaultTitle(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.incomingCall:
        return 'Incoming Call';
      case AppNotificationType.orderUpdate:
        return 'Order Update';
      case AppNotificationType.driverAssigned:
        return 'Driver Assigned';
      case AppNotificationType.orderCompleted:
        return 'Order Completed';
      case AppNotificationType.payment:
        return 'Payment Update';
      case AppNotificationType.dispatchReceived:
        return 'New Dispatch';
      case AppNotificationType.subscriptionAlert:
        return 'Subscription Alert';
      case AppNotificationType.generalAlert:
        return 'Notification';
    }
  }
}

class NotificationStore extends ChangeNotifier {
  final List<AppNotification> _notifications = [];

  List<AppNotification> get all => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  List<AppNotification> get today {
    final now = DateTime.now();
    return _notifications
        .where((n) =>
            n.timestamp.year == now.year &&
            n.timestamp.month == now.month &&
            n.timestamp.day == now.day)
        .toList();
  }

  List<AppNotification> get yesterday {
    final yest = DateTime.now().subtract(const Duration(days: 1));
    return _notifications
        .where((n) =>
            n.timestamp.year == yest.year &&
            n.timestamp.month == yest.month &&
            n.timestamp.day == yest.day)
        .toList();
  }

  List<AppNotification> get older {
    final yest = DateTime.now().subtract(const Duration(days: 1));
    return _notifications
        .where((n) => n.timestamp.isBefore(
            DateTime(yest.year, yest.month, yest.day)))
        .toList();
  }

  void add(AppNotification notification) {
    _notifications.insert(0, notification);
    // Keep max 100 notifications
    if (_notifications.length > 100) {
      _notifications.removeLast();
    }
    notifyListeners();
  }

  void addFromData(Map<String, dynamic> data) {
    add(AppNotification.fromFcmData(data));
  }

  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx].isRead = true;
      notifyListeners();
    }
  }

  void markAllRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void remove(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  /// Pre-populate with realistic demo notifications so the page is not empty
  void seedDemoNotifications() {
    if (_notifications.isNotEmpty) return;
    final now = DateTime.now();
    final items = [
      AppNotification(
        id: 'demo-1',
        type: AppNotificationType.driverAssigned,
        title: '🚗 Driver Assigned — ORD-9802',
        body: 'Suresh Yadav is on his way to pick up your order.',
        timestamp: now.subtract(const Duration(minutes: 12)),
        payload: {'type': 'driver_assigned', 'taskId': 'ORD-9802', 'userRole': 'Customer'},
      ),
      AppNotification(
        id: 'demo-2',
        type: AppNotificationType.orderUpdate,
        title: '📦 Order Out for Delivery',
        body: 'Your grocery order ORD-9803 has been picked up.',
        timestamp: now.subtract(const Duration(minutes: 42)),
        payload: {'type': 'ongoing_order', 'taskId': 'ORD-9803', 'userRole': 'Customer'},
      ),
      AppNotification(
        id: 'demo-3',
        type: AppNotificationType.dispatchReceived,
        title: '⚡ New Dispatch — Grocery Delivery',
        body: 'Rajesh Sharma • Vaishali Nagar → Chitrakoot • ₹140',
        timestamp: now.subtract(const Duration(hours: 1, minutes: 5)),
        payload: {'type': 'dispatch', 'taskId': 'ORD-9801', 'userRole': 'Driver'},
      ),
      AppNotification(
        id: 'demo-4',
        type: AppNotificationType.orderCompleted,
        title: '✅ Order Delivered — ORD-9804',
        body: 'Sunita Devi received her delivery. ₹160 earned.',
        timestamp: now.subtract(const Duration(hours: 2)),
        payload: {'type': 'order_completed', 'taskId': 'ORD-9804', 'userRole': 'Driver'},
        isRead: true,
      ),
      AppNotification(
        id: 'demo-5',
        type: AppNotificationType.payment,
        title: '💰 Payment Received — ₹480',
        body: 'Cash payment collected for ORD-9803 from Amit Verma.',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
        payload: {'type': 'payment', 'taskId': 'ORD-9803'},
        isRead: true,
      ),
      AppNotification(
        id: 'demo-6',
        type: AppNotificationType.subscriptionAlert,
        title: '🥛 Milk Delivery Scheduled',
        body: '2L Amul Toned Milk will be delivered tomorrow at 7 AM.',
        timestamp: now.subtract(const Duration(days: 1, hours: 5)),
        payload: {'type': 'subscription', 'subscriptionId': 'sub-001'},
        isRead: true,
      ),
    ];
    _notifications.addAll(items);
    notifyListeners();
  }
}
