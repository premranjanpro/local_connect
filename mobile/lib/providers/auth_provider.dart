import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  String? _phone;
  String? _fullName;
  String? _role;
  String _deviceId = '';

  bool _isLoading = false;
  String? _errorMessage;

  String? get token => _token;
  String? get userId => _userId;
  String? get phone => _phone;
  String? get fullName => _fullName;
  String? get role => _role;
  String get deviceId => _deviceId;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _initDevice();
  }

  Future<void> _initDevice() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedId = prefs.getString('hardware_device_id');
    if (storedId == null || storedId.isEmpty) {
      storedId = 'DEV_${const Uuid().v4().substring(0, 8).toUpperCase()}';
      await prefs.setString('hardware_device_id', storedId);
    }
    _deviceId = storedId;
    _token = prefs.getString('jwt_token');
    _userId = prefs.getString('user_id');
    _phone = prefs.getString('user_phone');
    _fullName = prefs.getString('user_name');
    _role = prefs.getString('user_role');
    notifyListeners();
  }

  Future<bool> login(String phone, String pin) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.loginWithPin(
        phone: phone,
        pin: pin,
        deviceId: _deviceId,
      );

      _token = res['token'];
      _userId = res['userId'];
      _phone = res['phone'];
      _fullName = res['fullName'];
      _role = res['role'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _token!);
      await prefs.setString('user_id', _userId!);
      await prefs.setString('user_phone', _phone!);
      await prefs.setString('user_name', _fullName!);
      await prefs.setString('user_role', _role!);

      // Auto-register FCM Push Notification token for this device session
      try {
        final fcmToken = 'FCM_${_deviceId}_${const Uuid().v4().substring(0, 8)}';
        await ApiService.updateFcmToken(_token!, fcmToken, _deviceId);
      } catch (_) {}

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String phone, String name, String pin, String role) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await ApiService.register(
        phone: phone,
        fullName: name,
        pin: pin,
        role: role,
        deviceId: _deviceId,
      );

      _token = res['token'];
      _userId = res['userId'];
      _phone = res['phone'];
      _fullName = res['fullName'];
      _role = res['role'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', _token!);
      await prefs.setString('user_id', _userId!);
      await prefs.setString('user_phone', _phone!);
      await prefs.setString('user_name', _fullName!);
      await prefs.setString('user_role', _role!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void switchRoleLocally(String newRole) {
    _role = newRole;
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _phone = null;
    _fullName = null;
    _role = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_id');
    await prefs.remove('user_phone');
    await prefs.remove('user_name');
    await prefs.remove('user_role');
    notifyListeners();
  }
}
