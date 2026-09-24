import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Use localhost for Windows desktop or 10.0.2.2 for Android emulator
  static String baseUrl = 'http://localhost:5000/api/v1';

  static Map<String, String> getHeaders(String? token) {
    final headers = {'Content-Type': 'application/json'};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // --- Auth ---
  static Future<Map<String, dynamic>> loginWithPin({
    required String phone,
    required String pin,
    required String deviceId,
    String? deviceModel,
    String? osVersion,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login-pin'),
      headers: getHeaders(null),
      body: jsonEncode({
        'phone': phone,
        'pin': pin,
        'deviceId': deviceId,
        'deviceModel': deviceModel ?? 'MobileClient',
        'osVersion': osVersion ?? 'Flutter 3.44',
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return data;
    } else if (res.statusCode == 409) {
      throw Exception('409: ${data['message']} (Active Task on ${data['activeDeviceId']})');
    } else {
      throw Exception(data['message'] ?? 'Authentication failed');
    }
  }

  static Future<Map<String, dynamic>> register({
    required String phone,
    required String fullName,
    required String pin,
    required String role,
    required String deviceId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: getHeaders(null),
      body: jsonEncode({
        'phone': phone,
        'fullName': fullName,
        'pin': pin,
        'role': role,
        'deviceId': deviceId,
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return data;
    }
    throw Exception(data['message'] ?? 'Registration failed');
  }

  // --- Driver APIs ---
  static Future<Map<String, dynamic>> updateDutyStatus(String token, String status, String deviceId) async {
    final res = await http.put(
      Uri.parse('$baseUrl/drivers/duty-status'),
      headers: getHeaders(token),
      body: jsonEncode({'status': status, 'deviceId': deviceId}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateRadius(String token, double acceptKm, double deliverKm) async {
    final res = await http.put(
      Uri.parse('$baseUrl/drivers/radius'),
      headers: getHeaders(token),
      body: jsonEncode({'acceptanceRadiusKm': acceptKm, 'deliveryRadiusKm': deliverKm}),
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getVehicles(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/drivers/vehicles'), headers: getHeaders(token));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> selectActiveVehicle(String token, String vehicleId) async {
    final res = await http.put(Uri.parse('$baseUrl/drivers/vehicles/$vehicleId/select-active'), headers: getHeaders(token));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createIntercityBanner(
      String token, String from, String to, DateTime time, int seats, double price) async {
    final res = await http.post(
      Uri.parse('$baseUrl/drivers/banners'),
      headers: getHeaders(token),
      body: jsonEncode({
        'fromCity': from,
        'toCity': to,
        'departureTime': time.toIso8601String(),
        'seatsAvailable': seats,
        'expectedPrice': price,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getIntercityBanners({String? from, String? to}) async {
    String url = '$baseUrl/drivers/banners';
    if (from != null || to != null) {
      url += '?fromCity=${from ?? ''}&toCity=${to ?? ''}';
    }
    final res = await http.get(Uri.parse(url));
    return jsonDecode(res.body);
  }

  // --- Tasks & Mobility ---
  static Future<Map<String, dynamic>> estimateTask(
      String token, double pLat, double pLng, double dLat, double dLng, String taskType) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/estimate'),
      headers: getHeaders(token),
      body: jsonEncode({
        'pickupLatitude': pLat,
        'pickupLongitude': pLng,
        'dropoffLatitude': dLat,
        'dropoffLongitude': dLng,
        'taskType': taskType,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createTask(String token, Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks'),
      headers: getHeaders(token),
      body: jsonEncode(payload),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getTask(String token, String taskId) async {
    final res = await http.get(Uri.parse('$baseUrl/tasks/$taskId'), headers: getHeaders(token));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> acceptTask(String token, String taskId, String deviceId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/accept'),
      headers: getHeaders(token),
      body: jsonEncode({'deviceId': deviceId}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> verifyPickupOtp(String token, String taskId, String otp, String deviceId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/verify-pickup-otp'),
      headers: getHeaders(token),
      body: jsonEncode({'otp': otp, 'deviceId': deviceId}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> verifyDropoffOtp(String token, String taskId, String otp, String deviceId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/verify-dropoff-otp'),
      headers: getHeaders(token),
      body: jsonEncode({'otp': otp, 'deviceId': deviceId}),
    );
    return jsonDecode(res.body);
  }

  // --- RFQ & Grocery Quoting ---
  static Future<Map<String, dynamic>> createRfq(String token, Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/rfq'),
      headers: getHeaders(token),
      body: jsonEncode(payload),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getRfq(String token, String rfqId) async {
    final res = await http.get(Uri.parse('$baseUrl/rfq/$rfqId'), headers: getHeaders(token));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> submitRfqQuote(
      String token, String rfqId, String businessId, double price, String quoteDetails, int prepMinutes) async {
    final res = await http.post(
      Uri.parse('$baseUrl/rfq/$rfqId/quote?businessId=$businessId'),
      headers: getHeaders(token),
      body: jsonEncode({
        'quotedTotalPrice': price,
        'quoteDetailsJson': quoteDetails,
        'estimatedPrepMinutes': prepMinutes,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> acceptRfqQuote(String token, String rfqId, String quoteId, String paymentMode) async {
    final res = await http.post(
      Uri.parse('$baseUrl/rfq/$rfqId/quotes/$quoteId/accept?paymentMode=$paymentMode'),
      headers: getHeaders(token),
    );
    return jsonDecode(res.body);
  }

  // --- Subscriptions & Vacation Mode ---
  static Future<List<dynamic>> getMySubscriptions(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/subscriptions/my'), headers: getHeaders(token));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> pauseSubscription(
      String token, String subId, String startDate, String endDate, String reason) async {
    final res = await http.post(
      Uri.parse('$baseUrl/subscriptions/$subId/pause'),
      headers: getHeaders(token),
      body: jsonEncode({'pauseStartDate': startDate, 'pauseEndDate': endDate, 'reason': reason}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> resumeSubscription(String token, String subId) async {
    final res = await http.post(Uri.parse('$baseUrl/subscriptions/$subId/resume'), headers: getHeaders(token));
    return jsonDecode(res.body);
  }

  // --- Digital Khata ---
  static Future<Map<String, dynamic>> getKhataCustomer(String token, String businessId, String customerId) async {
    final res = await http.get(Uri.parse('$baseUrl/khata/$businessId/customers/$customerId'), headers: getHeaders(token));
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateKhataPermission(
      String token, String businessId, String customerId, bool isDuesAllowed, double creditLimit) async {
    final res = await http.put(
      Uri.parse('$baseUrl/khata/$businessId/customers/$customerId/permission'),
      headers: getHeaders(token),
      body: jsonEncode({'isDuesAllowed': isDuesAllowed, 'creditLimit': creditLimit}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> recordKhataTransaction(String token, Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/khata/transactions'),
      headers: getHeaders(token),
      body: jsonEncode(payload),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getKhataLedger(String token, String businessId) async {
    final res = await http.get(Uri.parse('$baseUrl/khata/$businessId/ledger'), headers: getHeaders(token));
    return jsonDecode(res.body);
  }

  // --- Social & Classifieds ---
  static Future<List<dynamic>> getSocialMeetups() async {
    final res = await http.get(Uri.parse('$baseUrl/social/meetups'));
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getClassifieds() async {
    final res = await http.get(Uri.parse('$baseUrl/community/classifieds'));
    return jsonDecode(res.body);
  }
}
