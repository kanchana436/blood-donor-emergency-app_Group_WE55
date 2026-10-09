import 'package:flutter/foundation.dart';

class ApiConstants {
  // Default Node.js + Express backend URL port
  static const int serverPort = 5000;

  // Dynamically resolve base URL depending on platform (Web, Android emulator, Desktop/iOS)
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return 'http://localhost:$serverPort/api';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$serverPort/api';
    } else {
      return 'http://localhost:$serverPort/api';
    }
  }

  // Current active backend URL
  static String baseUrl = defaultBaseUrl;

  // Fallbacks for explicit platform targets
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:5000/api';
  static const String webBaseUrl = 'http://localhost:5000/api';

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String userProfile = '/auth/me';
  static const String updateProfile = '/auth/profile';
  static const String deactivateAccount = '/auth/deactivate';
  static const String changePassword = '/auth/change-password';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resetPassword = '/auth/reset-password';
  static const String verifyEmailOtp = '/auth/verify-email-otp';
  static const String resendEmailOtp = '/auth/resend-verification-otp';

  // Donor endpoints
  static const String searchDonors = '/donors';
  static const String donorProfile = '/donors/profile';
  static const String updateDonorProfile = '/donors/profile';
  static const String donorCompatibleRequests = '/donors/requests/compatible';
  static const String donorResponses = '/donors/responses';
  static const String respondToRequest = '/donors/requests/respond';
  static const String donationRecords = '/donations';

  static const String emergencyContacts = '/emergency-contacts';

  static const String donorAvailability = '/donor-availability';

  static const String verificationQueue = '/verification-queue';

  // Blood stock endpoints
  static const String bloodStock = '/blood-stock';

  // Blood Request endpoints
  static const String requests = '/requests';
  static const String myRequests = '/requests/me';
  static const String matchingDonors = '/requests/{id}/matching-donors';
  static const String cancelRequest = '/requests/{id}/cancel';
  static const String fulfillRequest = '/requests/{id}/fulfill';

  // Notification endpoints
  static const String notifications = '/notifications';
  static const String markNotificationRead = '/notifications/{id}/read';
  static const String markAllNotificationsRead = '/notifications/read-all';

  // Storage Keys
  static const String tokenKey = 'lifelink_auth_token';
  static const String userKey = 'lifelink_user_data';
  static const String roleKey = 'lifelink_user_role';
  static const String baseUrlKey = 'lifelink_api_base_url';
}
