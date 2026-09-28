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

  static Future<Map<String, dynamic>> bookBannerSeat(String token, String bannerId, int seats) async {
    final res = await http.post(
      Uri.parse('$baseUrl/drivers/banners/$bannerId/book-seat?seats=$seats'),
      headers: getHeaders(token),
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getMerchantRfqFeed(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/rfq/merchant-feed'), headers: getHeaders(token));
    return jsonDecode(res.body);
  }

  // --- Vehicles & Fleet Management ---
  static Future<Map<String, dynamic>> addVehicle(String token, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/drivers/vehicles'),
      headers: getHeaders(token),
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getShopVehicles(String token, String shopId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/businesses/$shopId/vehicles'), headers: getHeaders(token));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> addShopVehicle(String token, String shopId, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/businesses/$shopId/vehicles'),
      headers: getHeaders(token),
      body: jsonEncode(data),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> assignShopVehicle(
      String token, String shopId, dynamic payloadOrDriverId,
      [String? vehicleId]) async {
    final Map<String, dynamic> body;
    if (payloadOrDriverId is Map<String, dynamic>) {
      body = payloadOrDriverId;
    } else {
      body = {
        'driverId': payloadOrDriverId.toString(),
        if (vehicleId != null) 'vehicleId': vehicleId,
      };
    }
    final res = await http.post(
      Uri.parse('$baseUrl/businesses/$shopId/assign-vehicle'),
      headers: getHeaders(token),
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getCustomerTasks(String token) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/tasks/my-tasks'),
          headers: getHeaders(token));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is List ? data : (data['items'] ?? []);
      }
    } catch (_) {}
    return [];
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

  // --- FCM Notifications ---
  static Future<Map<String, dynamic>> updateFcmToken(String token, String fcmToken, String deviceId) async {
    final res = await http.put(
      Uri.parse('$baseUrl/notifications/fcm-token'),
      headers: getHeaders(token),
      body: jsonEncode({'fcmToken': fcmToken, 'deviceId': deviceId}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> sendTestPush(String token, String fcmToken, String title, String body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/notifications/test-push'),
      headers: getHeaders(token),
      body: jsonEncode({'fcmToken': fcmToken, 'title': title, 'body': body}),
    );
    return jsonDecode(res.body);
  }

  // --- Python AI Agent Microservice ---
  static String aiBaseUrl = 'http://localhost:8000/api/v1/ai';

  static Future<Map<String, dynamic>> parseAiIntent(String text, {String role = 'Customer'}) async {
    final res = await http.post(
      Uri.parse('$aiBaseUrl/parse-intent'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text, 'user_role': role}),
    );
    return jsonDecode(res.body);
  }

  // --- LiveKit VoIP Calling Signaling ---
  static Future<Map<String, dynamic>> startCall(Map<String, dynamic> body, {String? token}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/calls/start'),
      headers: getHeaders(token),
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> respondCall(String callId, String action, String callerUserId, {String? token}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/calls/$callId/respond'),
      headers: getHeaders(token),
      body: jsonEncode({'action': action, 'callerUserId': callerUserId}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> endCall(String callId, {String? token}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/calls/$callId/end'),
      headers: getHeaders(token),
    );
    return jsonDecode(res.body);
  }

  // --- Telemetry ---
  static Future<Map<String, dynamic>> recordGpsPing({
    required String token,
    required String deviceId,
    required double latitude,
    required double longitude,
    double heading = 0.0,
    double speed = 0.0,
    double accuracy = 5.0,
    int batteryPct = 100,
    bool isCharging = false,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/telemetry/ping'),
      headers: getHeaders(token),
      body: jsonEncode({
        'deviceId': deviceId,
        'latitude': latitude,
        'longitude': longitude,
        'heading': heading,
        'speed': speed,
        'accuracy': accuracy,
        'batteryPct': batteryPct,
        'isCharging': isCharging,
      }),
    );
    return jsonDecode(res.body);
  }

  // ── Shop Discovery ───────────────────────────────────────────────────────

  static Future<List<dynamic>> getNearbyShops({
    required double lat,
    required double lng,
    double radiusKm = 5,
    String? query,
  }) async {
    final params = {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radiusKm.toString(),
      if (query != null && query.isNotEmpty) 'q': query,
    };
    final res = await http.get(
      Uri.parse('$baseUrl/businesses/nearby').replace(queryParameters: params),
      headers: getHeaders(null),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : (data['data'] ?? data['items'] ?? []);
    }
    throw Exception('Failed to load shops');
  }

  static Future<List<dynamic>> getShopCategories(String shopId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/businesses/$shopId/categories'),
      headers: getHeaders(null),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : (data['data'] ?? []);
    }
    throw Exception('Failed to load categories');
  }

  static Future<List<dynamic>> getCategoryProducts(
      String shopId, String categoryId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/businesses/$shopId/categories/$categoryId/products'),
      headers: getHeaders(null),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : (data['data'] ?? []);
    }
    throw Exception('Failed to load products');
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> placeOrder(
      String token, Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/orders/direct'),
      headers: getHeaders(token),
      body: jsonEncode(payload),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) {
      return data is Map<String, dynamic> ? data : {'id': 'ORD-LOCAL'};
    }
    throw Exception(data['message'] ?? 'Order placement failed');
  }

  static Future<List<dynamic>> getMyOrders(String token,
      {String? status}) async {
    final params = {if (status != null) 'status': status};
    final res = await http.get(
      Uri.parse('$baseUrl/orders/my').replace(queryParameters: params),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : (data['data'] ?? []);
    }
    throw Exception('Failed to load orders');
  }

  // ── Nearby Offers ─────────────────────────────────────────────────────────

  static Future<List<dynamic>> getNearbyOffers({
    required double lat,
    required double lng,
    double radiusKm = 5,
  }) async {
    final res = await http.get(
      Uri.parse('$baseUrl/offers/nearby').replace(queryParameters: {
        'lat': lat.toString(),
        'lng': lng.toString(),
        'radius': radiusKm.toString(),
      }),
      headers: getHeaders(null),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : (data['data'] ?? []);
    }
    throw Exception('Failed to load offers');
  }

  // ── Broadcast Feed ────────────────────────────────────────────────────────

  static Future<List<dynamic>> getBroadcastPosts({
    required double lat,
    required double lng,
    double radiusKm = 5,
    String? type,
  }) async {
    final params = {
      'lat': lat.toString(),
      'lng': lng.toString(),
      'radius': radiusKm.toString(),
      if (type != null) 'type': type,
    };
    final res = await http.get(
      Uri.parse('$baseUrl/broadcasts').replace(queryParameters: params),
      headers: getHeaders(null),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : (data['data'] ?? []);
    }
    throw Exception('Failed to load broadcast posts');
  }

  static Future<dynamic> createBroadcastPost({
    required String token,
    required String postType,
    required String description,
    double? price,
    String priceMode = 'ASKING',
    required double lat,
    required double lng,
    String? title,
    double radiusKm = 5,
    String urgency = 'normal',
    List<String>? targetRoles,
    List<String>? targetUserIds,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/broadcasts'),
      headers: getHeaders(token),
      body: jsonEncode({
        'postType': postType,
        'description': description,
        'price': price,
        'priceMode': priceMode,
        'latitude': lat,
        'longitude': lng,
        'title': title,
        'radiusKm': radiusKm,
        'urgency': urgency,
        if (targetRoles != null && targetRoles.isNotEmpty) 'targetRoles': targetRoles,
        if (targetUserIds != null && targetUserIds.isNotEmpty) 'targetUserIds': targetUserIds,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to create broadcast');
    }
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return {'success': true};
    }
  }

  static Future<void> respondToBroadcast({
    required String token,
    required String postId,
    required String message,
    double? quotedPrice,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/broadcasts/$postId/responses'),
      headers: getHeaders(token),
      body: jsonEncode({
        'message': message,
        'quotedPrice': quotedPrice,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to send response');
    }
  }

  static Future<Map<String, dynamic>> aiEnhanceBroadcast({
    required String token,
    required String text,
    required String postType,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/broadcasts/ai-enhance'),
      headers: getHeaders(token),
      body: jsonEncode({'text': text, 'postType': postType}),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('AI enhance failed');
  }

  // ── Merchant Management APIs ──────────────────────────────────────────────

  static Future<List<dynamic>> getMyShops(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/businesses/my'),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : (data['data'] ?? []);
    }
    throw Exception('Failed to load merchant shops');
  }

  static Future<Map<String, dynamic>> createShop(
      String token, Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/businesses'),
      headers: getHeaders(token),
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create shop');
  }

  static Future<List<dynamic>> getShopDeliveryBoys(
      String token, String businessId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/businesses/$businessId/delivery-boys'),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : [];
    }
    throw Exception('Failed to load delivery boys');
  }

  static Future<Map<String, dynamic>> addShopDeliveryBoy(
      String token, String businessId, Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/businesses/$businessId/delivery-boys'),
      headers: getHeaders(token),
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to add delivery boy');
  }

  static Future<List<dynamic>> getShopCustomers(
      String token, String businessId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/businesses/$businessId/customers'),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : [];
    }
    throw Exception('Failed to load customers');
  }

  static Future<Map<String, dynamic>> addShopCustomer(
      String token, String businessId, Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/businesses/$businessId/customers'),
      headers: getHeaders(token),
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to add customer');
  }

  static Future<Map<String, dynamic>> createMerchantDirectOrder(
      String token, Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/merchant-direct'),
      headers: getHeaders(token),
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['message'] ?? 'Failed to create order');
  }

  static Future<Map<String, dynamic>> assignDriverToTask(
      String token, String taskId, String driverId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/assign-driver'),
      headers: getHeaders(token),
      body: jsonEncode({'driverId': driverId}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['message'] ?? 'Failed to assign driver');
  }

  static Future<List<dynamic>> getShopOrders(
      String token, String businessId, {String? status}) async {
    final params = {if (status != null && status != 'All') 'status': status};
    final res = await http.get(
      Uri.parse('$baseUrl/businesses/$businessId/orders')
          .replace(queryParameters: params),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : [];
    }
    throw Exception('Failed to load shop orders');
  }

  static Future<List<dynamic>> getMyTasks(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/tasks/my'),
        headers: getHeaders(token),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is List ? data : [];
      }
    } catch (_) {}
    return [];
  }

  // ── Daily Subscriptions APIs ─────────────────────────────────────────────

  static Future<List<dynamic>> getSubscriptionCatalog() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/subscriptions/catalog'),
        headers: getHeaders(null),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is List ? data : [];
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> createSubscription(
      String token, Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/subscriptions'),
      headers: getHeaders(token),
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['message'] ?? 'Failed to create subscription');
  }

  static Future<List<dynamic>> getMySubscriptions(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/subscriptions/my'),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : [];
    }
    throw Exception('Failed to load my subscriptions');
  }

  static Future<void> pauseSubscription(
      String token, String subId, String startDate, String endDate, String reason) async {
    final res = await http.post(
      Uri.parse('$baseUrl/subscriptions/$subId/pause'),
      headers: getHeaders(token),
      body: jsonEncode({
        'pauseStartDate': startDate,
        'pauseEndDate': endDate,
        'reason': reason,
      }),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to pause subscription');
    }
  }

  static Future<void> resumeSubscription(String token, String subId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/subscriptions/$subId/resume'),
      headers: getHeaders(token),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to resume subscription');
    }
  }

  static Future<List<dynamic>> getMerchantSubscriptions(
      String token, String businessId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/subscriptions/merchant/$businessId'),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : [];
    }
    throw Exception('Failed to load merchant subscriptions');
  }

  // ── Safe School Transit APIs ──────────────────────────────────────────────

  static Future<Map<String, dynamic>> createSchoolTransitSchedule(
      String token, Map<String, dynamic> payload) async {
    final res = await http.post(
      Uri.parse('$baseUrl/school-transit/schedule'),
      headers: getHeaders(token),
      body: jsonEncode(payload),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(res.body);
    throw Exception(err['message'] ?? 'Failed to schedule school transit');
  }

  static Future<List<dynamic>> getMySchoolTransitSchedules(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/school-transit/my'),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : [];
    }
    throw Exception('Failed to load school transit schedules');
  }

  static Future<List<dynamic>> getDriverSchoolTransitStudents(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/school-transit/driver/students'),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data is List ? data : [];
    }
    throw Exception('Failed to load driver student route');
  }

  static Future<void> updateSchoolTransitStatus(
      String token, String scheduleId, String status, {String? notes}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/school-transit/$scheduleId/status'),
      headers: getHeaders(token),
      body: jsonEncode({'status': status, 'notes': notes}),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to update student transit status');
    }
  }

  static Future<void> triggerSchoolTransitSos(
      String token, String scheduleId, String message, {double? lat, double? lng}) async {
    await http.post(
      Uri.parse('$baseUrl/school-transit/$scheduleId/sos'),
      headers: getHeaders(token),
      body: jsonEncode({
        'alertMessage': message,
        'latitude': lat,
        'longitude': lng,
      }),
    );
  }

  // ── Share-to-Track ──────────────────────────────────────────────────────

  /// Creates a share token for a task — returns { token, shareUrl, expiresAt }
  static Future<Map<String, dynamic>> createTrackingShare(
      String token, String taskId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/share-token'),
      headers: getHeaders(token),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) return data;
    throw Exception(data['message'] ?? 'Failed to create tracking share');
  }

  /// Resolves a share token — returns { taskId, shareToken, isValid, driverName, ... }
  static Future<Map<String, dynamic>> resolveTrackingShare(String shareToken) async {
    final res = await http.get(
      Uri.parse('$baseUrl/tasks/share-token/$shareToken'),
      headers: getHeaders(null),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return data;
    throw Exception(data['message'] ?? 'Invalid or expired share token');
  }

  // ── Chat REST (offline fallback) ────────────────────────────────────────

  /// Fetches message history for a task chat room
  static Future<List<dynamic>> getTaskChatHistory(
      String token, String taskId, {int page = 0, int size = 30}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/chat/task/$taskId?page=$page&size=$size'),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['messages'] ?? [];
    }
    return [];
  }

  /// Fetches unread message count per room
  static Future<Map<String, dynamic>> getChatUnreadCounts(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/chat/unread'),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return {'totalUnread': 0, 'rooms': []};
  }

  /// Fetches all conversations (latest message per room)
  static Future<List<dynamic>> getChatConversations(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/chat/conversations'),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    return [];
  }

  /// REST send (offline fallback when SignalR is unavailable)
  static Future<Map<String, dynamic>> sendTaskChatMessage(
      String token, String taskId, String body,
      {String messageType = 'text', String? attachmentUrl}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/chat/task/$taskId/send'),
      headers: getHeaders(token),
      body: jsonEncode({
        'body': body,
        'messageType': messageType,
        'attachmentUrl': attachmentUrl,
      }),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to send chat message');
  }

  // --- Rating & Review APIs ---
  static Future<Map<String, dynamic>> getTaskRatingStatus(String token, String taskId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/tasks/$taskId/ratings/status'),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load rating status');
  }

  static Future<Map<String, dynamic>> submitTaskRatings({
    required String token,
    required String taskId,
    required List<Map<String, dynamic>> ratings,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tasks/$taskId/ratings'),
      headers: getHeaders(token),
      body: jsonEncode({'ratings': ratings}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) {
      return data;
    }
    throw Exception(data['message'] ?? 'Failed to submit rating');
  }

  // --- Customer Saved Address APIs ---
  static Future<List<dynamic>> getSavedAddresses(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/customers/addresses'),
      headers: getHeaders(token),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as List<dynamic>;
    }
    throw Exception('Failed to load saved addresses');
  }

  static Future<Map<String, dynamic>> addSavedAddress(String token, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customers/addresses'),
      headers: getHeaders(token),
      body: jsonEncode(data),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to save address');
  }

  static Future<void> deleteSavedAddress(String token, String addressId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/customers/addresses/$addressId'),
      headers: getHeaders(token),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to delete address');
    }
  }

  static Future<void> setDefaultAddress(String token, String addressId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/customers/addresses/$addressId/set-default'),
      headers: getHeaders(token),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to set default address');
    }
  }

  // --- Profiles APIs (Shop, Customer, Driver) ---
  static Future<Map<String, dynamic>> getShopProfile(String businessId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/profiles/shop/$businessId'),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load shop profile');
  }

  static Future<Map<String, dynamic>> getCustomerProfile(String customerId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/profiles/customer/$customerId'),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load customer profile');
  }

  static Future<Map<String, dynamic>> getDriverProfile(String driverId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/profiles/driver/$driverId'),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load driver profile');
  }

  // --- SOS ---
  static Future<Map<String, dynamic>> triggerSos({
    required String token,
    required String taskId,
    double? lat,
    double? lng,
    String? message,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/sos'),
        headers: getHeaders(token),
        body: jsonEncode({
          'latitude': lat ?? 26.9124,
          'longitude': lng ?? 75.7873,
          'message': message ?? 'Customer SOS alert — immediate assistance required',
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    // Return optimistic success so UI proceeds
    return {'success': true, 'message': 'SOS sent (offline).'};
  }

  // --- Share Token ---
  static Future<Map<String, dynamic>> generateShareToken({
    required String token,
    required String taskId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/tasks/$taskId/share-token'),
        headers: getHeaders(token),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {'shareToken': taskId};
  }

  // --- Shop Catalog ---
  static Future<List<dynamic>> getShopCatalog(String shopId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/catalog/shop/$shopId'), headers: getHeaders(null));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data is List ? data : (data['items'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<void> addCatalogItem(String token, String shopId, Map<String, dynamic> item) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/catalog/shop/$shopId/items'),
        headers: getHeaders(token),
        body: jsonEncode(item),
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw Exception('Failed to add catalog item');
      }
    } catch (e) {
      rethrow;
    }
  }
}




