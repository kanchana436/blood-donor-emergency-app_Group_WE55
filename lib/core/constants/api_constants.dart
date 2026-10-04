class ApiConstants {
  // Default Node.js + Express backend URL
  // Can be adjusted from settings screen in the app
  static String baseUrl = 'http://localhost:5000/api';

  // For Android emulator testing, localhost is 10.0.2.2
  static const String androidEmulatorBaseUrl = 'http://10.0.2.2:5000/api';

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String userProfile = '/auth/me';
  static const String updateProfile = '/auth/profile';
  static const String deactivateAccount = '/auth/deactivate';

  // Donor endpoints
  static const String donorProfile = '/donors/profile';
  static const String updateDonorProfile = '/donors/profile';
  static const String donorCompatibleRequests = '/donors/requests/compatible';
  static const String donorResponses = '/donors/responses';
  static const String respondToRequest = '/donors/requests/respond';
  static const String donationRecords = '/donations';

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
