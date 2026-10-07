import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../core/constants/api_constants.dart';
import '../services/auth_service.dart';
import '../services/mock_data_store.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  String _activeRole = 'donor'; // 'donor' or 'recipient'
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  String get activeRole => _activeRole;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isDonor => _activeRole == 'donor';

  AuthProvider() {
    _initSession();
  }

  Future<void> _initSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(ApiConstants.userKey);
      final role = prefs.getString(ApiConstants.roleKey);
      if (userJson != null && userJson.isNotEmpty) {
        _currentUser = UserModel.fromJson(jsonDecode(userJson));
        if (role != null) _activeRole = role;
        notifyListeners();
        return;
      }
    } catch (_) {}
    _initDefaultSession();
  }

  void _initDefaultSession() {
    final mockUsers = MockDataStore().users;
    if (mockUsers.isNotEmpty) {
      _currentUser = mockUsers.first;
      _activeRole = _currentUser!.role;
    }
  }

  Future<void> _saveSession(UserModel user, String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.userKey, jsonEncode(user.toJson()));
      await prefs.setString(ApiConstants.roleKey, role);
    } catch (_) {}
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(ApiConstants.userKey);
      await prefs.remove(ApiConstants.roleKey);
    } catch (_) {}
  }

  void setActiveRole(String role) {
    _activeRole = role;
    _persistRole(role);
    notifyListeners();
  }

  Future<void> _persistRole(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(ApiConstants.roleKey, role);
    } catch (_) {}
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
    required String idNumber,
    String? bloodGroup,
    String? city,
    String? address,
    double? weightKg,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.register(
        name: name,
        email: email,
        phone: phone,
        password: password,
        role: role,
        idNumber: idNumber,
        bloodGroup: bloodGroup,
        city: city,
        address: address,
        weightKg: weightKg,
      );
      _currentUser = user;
      _activeRole = role;
      await _saveSession(user, role);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      _errorMessage = msg.isNotEmpty ? msg : 'Registration failed.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.login(
        email: email,
        password: password,
      );
      _currentUser = user;
      _activeRole = user.role;
      await _saveSession(user, user.role);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      _errorMessage = msg.isNotEmpty ? msg : 'Login failed.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String phone,
    String? email,
    String? idNumber,
  }) async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _authService.updateUserProfile(
        userId: _currentUser!.id,
        name: name,
        phone: phone,
        email: email,
        idNumber: idNumber,
      );
      _currentUser = updated;
      await _saveSession(updated, _activeRole);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      _errorMessage = msg.isNotEmpty ? msg : 'Failed to update profile.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deactivateAccount() async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _authService.deactivateUser(_currentUser!.id);
      if (success) {
        _currentUser = null;
        await _clearSession();
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      _errorMessage = msg.isNotEmpty ? msg : 'Failed to deactivate account.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    await _clearSession();
    _currentUser = null;
    notifyListeners();
  }
}
