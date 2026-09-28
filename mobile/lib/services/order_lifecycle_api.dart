import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';

/// Extended order lifecycle API methods — calls the new OrderLifecycleController
extension OrderLifecycleApi on ApiService {
  static String get _base => ApiService.baseUrl;

  // ── Customer ──────────────────────────────────────────────────────────────

  /// Permanently delete a PENDING/BROADCASTING order (only allowed before driver accepts)
  static Future<Map<String, dynamic>> deleteOrder(String token, String taskId) async {
    final res = await http.delete(
      Uri.parse('$_base/orders/$taskId'),
      headers: ApiService.getHeaders(token),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Cannot delete order');
  }

  static Future<Map<String, dynamic>> deletePendingTask(String taskId, String token) =>
      deleteOrder(token, taskId);

  static Future<Map<String, dynamic>> getTaskStatus(String taskId, String token) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/tasks/$taskId'),
        headers: ApiService.getHeaders(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is Map<String, dynamic> ? data : {};
      }
    } catch (_) {}
    return {};
  }

  // ── Shop Owner ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> confirmOrder(
    String token, String taskId, {
    bool requirePickupOtp = true,
    bool requireDropOtp = true,
  }) async {
    final res = await http.post(
      Uri.parse('$_base/orders/$taskId/confirm'),
      headers: ApiService.getHeaders(token),
      body: jsonEncode({
        'requirePickupOtp': requirePickupOtp,
        'requireDropOtp': requireDropOtp,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Confirm failed');
  }

  static Future<Map<String, dynamic>> rejectOrder(
      String token, String taskId, String reason) async {
    final res = await http.post(
      Uri.parse('$_base/orders/$taskId/reject'),
      headers: ApiService.getHeaders(token),
      body: jsonEncode({'reason': reason}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Reject failed');
  }

  static Future<Map<String, dynamic>> postToMarket(
      String token, String taskId, double fareOffer, {String? description}) async {
    final res = await http.post(
      Uri.parse('$_base/orders/$taskId/post-market'),
      headers: ApiService.getHeaders(token),
      body: jsonEncode({'fareOffer': fareOffer, 'description': description}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Post to market failed');
  }

  // ── Driver lifecycle ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> startTrip(
      String token, String taskId, double lat, double lng, {String? deviceId}) async {
    final res = await http.post(
      Uri.parse('$_base/orders/$taskId/start'),
      headers: ApiService.getHeaders(token),
      body: jsonEncode({'driverLat': lat, 'driverLng': lng, 'deviceId': deviceId}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Start trip failed');
  }

  static Future<Map<String, dynamic>> arrivePickup(
      String token, String taskId, double lat, double lng, {String? deviceId}) async {
    final res = await http.post(
      Uri.parse('$_base/orders/$taskId/arrive-pickup'),
      headers: ApiService.getHeaders(token),
      body: jsonEncode({'driverLat': lat, 'driverLng': lng, 'deviceId': deviceId}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Arrive pickup failed');
  }

  static Future<Map<String, dynamic>> confirmPickup(
      String token, String taskId, double lat, double lng,
      {String? otp, String? deviceId}) async {
    final res = await http.post(
      Uri.parse('$_base/orders/$taskId/pickup'),
      headers: ApiService.getHeaders(token),
      body: jsonEncode({'driverLat': lat, 'driverLng': lng, 'otp': otp, 'deviceId': deviceId}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Pickup confirm failed');
  }

  static Future<Map<String, dynamic>> arriveDrop(
      String token, String taskId, double lat, double lng, {String? deviceId}) async {
    final res = await http.post(
      Uri.parse('$_base/orders/$taskId/arrive-drop'),
      headers: ApiService.getHeaders(token),
      body: jsonEncode({'driverLat': lat, 'driverLng': lng, 'deviceId': deviceId}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Arrive drop failed');
  }

  static Future<Map<String, dynamic>> completeDelivery(
      String token, String taskId, double lat, double lng,
      {String? otp, String? deviceId}) async {
    final res = await http.post(
      Uri.parse('$_base/orders/$taskId/complete'),
      headers: ApiService.getHeaders(token),
      body: jsonEncode({'driverLat': lat, 'driverLng': lng, 'otp': otp, 'deviceId': deviceId}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Complete delivery failed');
  }

  // ── Delivery Log ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDeliveryLog(String token, String taskId) async {
    final res = await http.get(
      Uri.parse('$_base/orders/$taskId/delivery-log'),
      headers: ApiService.getHeaders(token),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to fetch delivery log');
  }

  // ── Webhook management ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> registerWebhook(
      String token, String url, {String? events}) async {
    final res = await http.post(
      Uri.parse('$_base/webhooks'),
      headers: ApiService.getHeaders(token),
      body: jsonEncode({'endpointUrl': url, 'eventFilter': events ?? '*'}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) return data;
    throw Exception(data['message'] ?? 'Register webhook failed');
  }
}
