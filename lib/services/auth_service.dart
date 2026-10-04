import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../core/constants/api_constants.dart';
import 'api_service.dart';
import 'mock_data_store.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final MockDataStore _dataStore = MockDataStore();
  final Uuid _uuid = const Uuid();

  // CRUD #1: Create User (Registration)
  Future<UserModel> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role, // 'donor' or 'recipient'
  }) async {
    // Attempt REST backend
    final response = await _apiService.post(ApiConstants.register, {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
      'role': role,
    });

    if (response.success && response.data != null) {
      final user = UserModel.fromJson(response.data['user'] ?? response.data);
      if (response.data['token'] != null) {
        await _apiService.setAuthToken(response.data['token']);
      }
      return user;
    }

    // If server responded with a rejection error (e.g. duplicate email), bubble it up
    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Local Mock / Offline fallback if server is unreachable
    final newUser = UserModel(
      id: 'usr_${_uuid.v4().substring(0, 8)}',
      name: name,
      email: email,
      phone: phone,
      role: role,
      isActive: true,
      createdAt: DateTime.now(),
    );
    _dataStore.users.add(newUser);
    await _apiService.setAuthToken('mock_jwt_token_${newUser.id}');
    return newUser;
  }

  // Login
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiService.post(ApiConstants.login, {
      'email': email,
      'password': password,
    });

    if (response.success && response.data != null) {
      final user = UserModel.fromJson(response.data['user'] ?? response.data);
      if (response.data['token'] != null) {
        await _apiService.setAuthToken(response.data['token']);
      }
      return user;
    }

    // If server rejected login (wrong credentials), bubble up the error!
    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Local Mock fallback only if backend server is unreachable
    final existing = _dataStore.users.firstWhere(
      (u) => u.email.toLowerCase() == email.toLowerCase(),
      orElse: () {
        final defaultUser = UserModel(
          id: 'usr_${_uuid.v4().substring(0, 8)}',
          name: email.split('@').first,
          email: email,
          phone: '+94 77 123 4567',
          role: email.contains('recip') ? 'recipient' : 'donor',
          isActive: true,
        );
        _dataStore.users.add(defaultUser);
        return defaultUser;
      },
    );

    await _apiService.setAuthToken('mock_jwt_token_${existing.id}');
    return existing;
  }

  // CRUD #2: Read User Profile
  Future<UserModel?> getCurrentUser(String userId) async {
    final response = await _apiService.get(ApiConstants.userProfile);
    if (response.success && response.data != null) {
      return UserModel.fromJson(response.data);
    }

    // Mock fallback
    try {
      return _dataStore.users.firstWhere((u) => u.id == userId);
    } catch (_) {
      return _dataStore.users.isNotEmpty ? _dataStore.users.first : null;
    }
  }

  // CRUD #3: Update User Profile
  Future<UserModel> updateUserProfile({
    required String userId,
    required String name,
    required String phone,
    String? email,
  }) async {
    final response = await _apiService.put(ApiConstants.updateProfile, {
      'userId': userId,
      'name': name,
      'phone': phone,
      if (email != null) 'email': email,
    });

    if (response.success && response.data != null) {
      return UserModel.fromJson(response.data);
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Mock fallback
    final index = _dataStore.users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final updated = _dataStore.users[index].copyWith(
        name: name,
        phone: phone,
        email: email ?? _dataStore.users[index].email,
      );
      _dataStore.users[index] = updated;
      return updated;
    }
    throw Exception('User not found');
  }

  // CRUD #4: Deactivate/Delete User
  Future<bool> deactivateUser(String userId) async {
    final response = await _apiService.post(ApiConstants.deactivateAccount, {
      'userId': userId,
    });

    if (response.success) {
      await logout();
      return true;
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Mock fallback
    final index = _dataStore.users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      _dataStore.users[index] = _dataStore.users[index].copyWith(isActive: false);
      await logout();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _apiService.setAuthToken(null);
  }
}
