import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/donor_profile_model.dart';
import '../core/constants/api_constants.dart';
import 'api_service.dart';
import 'mock_data_store.dart';

class UnverifiedEmailException implements Exception {
  final String message;
  final String email;

  UnverifiedEmailException(this.message, this.email);

  @override
  String toString() => message;
}

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
    required String idNumber,
    String? bloodGroup,
    String? city,
    String? address,
    double? weightKg,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final cleanIdNumber = idNumber.trim();

    // Attempt REST backend
    final response = await _apiService.post(ApiConstants.register, {
      'name': name.trim(),
      'email': normalizedEmail,
      'phone': phone.trim(),
      'password': password,
      'role': role,
      'idNumber': cleanIdNumber,
      if (bloodGroup != null) 'bloodGroup': bloodGroup,
      if (city != null) 'city': city,
      if (address != null) 'address': address,
      if (weightKg != null) 'weightKg': weightKg,
    });

    if (response.success && response.data != null) {
      final user = UserModel.fromJson(response.data['user'] ?? response.data);
      if (response.data['profile'] != null) {
        final profile = DonorProfileModel.fromJson(response.data['profile']);
        _dataStore.donorProfiles[user.id] = profile;
      }
      if (response.data['token'] != null && user.isEmailVerified) {
        await _apiService.setAuthToken(response.data['token']);
      }
      return user;
    }

    // If server responded with a rejection error (e.g. duplicate email/id), bubble it up
    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Local Mock / Offline fallback if server is unreachable
    final existsLocal = _dataStore.users.any(
      (u) => u.email.toLowerCase() == normalizedEmail,
    );
    if (existsLocal) {
      throw Exception('An account with this email already exists.');
    }

    final existsLocalId = _dataStore.users.any(
      (u) => u.idNumber.isNotEmpty && u.idNumber.toLowerCase() == cleanIdNumber.toLowerCase(),
    );
    if (existsLocalId) {
      throw Exception('An account with this ID Number already exists.');
    }

    final newUser = UserModel(
      id: 'usr_${_uuid.v4().substring(0, 8)}',
      idNumber: cleanIdNumber,
      name: name.trim(),
      email: normalizedEmail,
      phone: phone.trim(),
      role: role,
      isActive: true,
      isEmailVerified: false,
      createdAt: DateTime.now(),
    );
    _dataStore.users.add(newUser);
    if (role == 'donor' || bloodGroup != null) {
      _dataStore.donorProfiles[newUser.id] = DonorProfileModel(
        id: 'dp_${_uuid.v4().substring(0, 8)}',
        userId: newUser.id,
        bloodGroup: bloodGroup ?? 'O+',
        city: city ?? 'Colombo',
        address: address ?? '',
        weightKg: weightKg,
        isAvailable: true,
      );
    }
    return newUser;
  }

  // Login
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    final response = await _apiService.post(ApiConstants.login, {
      'email': normalizedEmail,
      'password': password,
    });

    if (response.success && response.data != null) {
      final user = UserModel.fromJson(response.data['user'] ?? response.data);
      if (response.data['token'] != null) {
        await _apiService.setAuthToken(response.data['token']);
      }
      return user;
    }

    if (response.data != null && response.data is Map && response.data['isUnverified'] == true) {
      throw UnverifiedEmailException(
        response.message ?? 'Your email address is not verified. Please verify your email before logging in.',
        (response.data['email'] as String?) ?? normalizedEmail,
      );
    }

    // If server rejected login (e.g. 401 Invalid email or password), bubble up the error!
    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Network connection failed
    throw Exception('Unable to connect to the server. Please check your network connection.');
  }

  // Email Verification: Verify OTP
  Future<UserModel> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final cleanOtp = otp.trim();

    final response = await _apiService.post(ApiConstants.verifyEmailOtp, {
      'email': normalizedEmail,
      'otp': cleanOtp,
    });

    if (response.success && response.data != null) {
      final user = UserModel.fromJson(response.data['user'] ?? response.data);
      if (response.data['profile'] != null) {
        final profile = DonorProfileModel.fromJson(response.data['profile']);
        _dataStore.donorProfiles[user.id] = profile;
      }
      if (response.data['token'] != null) {
        await _apiService.setAuthToken(response.data['token']);
      }
      return user;
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Mock fallback if offline/disconnected
    if (cleanOtp.length != 6) {
      throw Exception('Verification code must be exactly 6 digits.');
    }
    final existingUser = _dataStore.users.firstWhere(
      (u) => u.email.toLowerCase() == normalizedEmail,
      orElse: () => throw Exception('User account not found.'),
    );
    final verifiedUser = existingUser.copyWith(isEmailVerified: true);
    final idx = _dataStore.users.indexWhere((u) => u.id == existingUser.id);
    if (idx != -1) _dataStore.users[idx] = verifiedUser;
    await _apiService.setAuthToken('mock_jwt_token_${verifiedUser.id}');
    return verifiedUser;
  }

  // Email Verification: Resend OTP
  Future<bool> resendEmailOtp({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final response = await _apiService.post(ApiConstants.resendEmailOtp, {
      'email': normalizedEmail,
    });

    if (response.success) {
      return true;
    }

    if (response.message != null && response.message!.isNotEmpty) {
      throw Exception(response.message);
    }

    throw Exception('Failed to resend verification code. Please try again.');
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
    String? idNumber,
  }) async {
    final response = await _apiService.put(ApiConstants.updateProfile, {
      'userId': userId,
      'name': name,
      'phone': phone,
      if (email != null) 'email': email,
      if (idNumber != null) 'idNumber': idNumber.trim(),
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
      if (idNumber != null && idNumber.trim().isNotEmpty) {
        final conflict = _dataStore.users.any(
          (u) => u.id != userId && u.idNumber.isNotEmpty && u.idNumber.toLowerCase() == idNumber.trim().toLowerCase(),
        );
        if (conflict) {
          throw Exception('An account with this ID Number already exists.');
        }
      }

      final updated = _dataStore.users[index].copyWith(
        name: name,
        phone: phone,
        email: email ?? _dataStore.users[index].email,
        idNumber: idNumber?.trim() ?? _dataStore.users[index].idNumber,
      );
      _dataStore.users[index] = updated;
      return updated;
    }
    throw Exception('User not found');
  }

  // CRUD #4: Deactivate/Delete User
  Future<bool> deactivateUser(String userId) async {
    if (_apiService.authToken == null) {
      final index = _dataStore.users.indexWhere((u) => u.id == userId);
      if (index != -1) {
        _dataStore.users[index] = _dataStore.users[index].copyWith(isActive: false);
      }
      await logout();
      return true;
    }

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

  // Change Password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _apiService.post(ApiConstants.changePassword, {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });

    if (response.success) {
      if (response.data != null && response.data['token'] != null) {
        await _apiService.setAuthToken(response.data['token']);
      }
      return true;
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Fallback if backend server unreachable
    if (_apiService.authToken == null) {
      throw Exception('Authentication token required');
    }
    if (newPassword.length < 6) {
      throw Exception('New password must be at least 6 characters');
    }
    if (newPassword != confirmPassword) {
      throw Exception('New password and confirmation do not match');
    }
    if (newPassword == currentPassword) {
      throw Exception('New password must be different from current password');
    }
    return true;
  }

  // Forgot Password: Send OTP
  Future<bool> forgotPassword(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final response = await _apiService.post(ApiConstants.forgotPassword, {
      'email': normalizedEmail,
    });

    if (response.success) {
      return true;
    }

    if (response.message != null && response.message!.isNotEmpty) {
      throw Exception(response.message);
    }

    throw Exception('Failed to send verification code. Please check email configuration or try again.');
  }

  // Verify OTP: returns resetToken
  Future<String> verifyOtp({required String email, required String otp}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final response = await _apiService.post(ApiConstants.verifyOtp, {
      'email': normalizedEmail,
      'otp': otp.trim(),
    });

    if (response.success && response.data != null && response.data['resetToken'] != null) {
      return response.data['resetToken'] as String;
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Mock fallback if disconnected
    if (otp.trim().length != 6) {
      throw Exception('Verification code must be exactly 6 digits.');
    }
    return 'mock_reset_token_${DateTime.now().millisecondsSinceEpoch}';
  }

  // Reset Password using resetToken
  Future<bool> resetPassword({
    required String resetToken,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _apiService.post(ApiConstants.resetPassword, {
      'resetToken': resetToken,
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    });

    if (response.success) {
      return true;
    }

    if (response.message != null && !response.message!.contains('Could not connect')) {
      throw Exception(response.message);
    }

    // Mock fallback
    if (newPassword.length < 6) {
      throw Exception('New password must be at least 6 characters');
    }
    if (newPassword != confirmPassword) {
      throw Exception('New password and confirmation do not match');
    }
    return true;
  }

  Future<void> logout() async {
    await _apiService.setAuthToken(null);
  }
}

