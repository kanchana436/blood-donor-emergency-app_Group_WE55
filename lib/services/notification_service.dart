import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import '../core/constants/api_constants.dart';
import 'api_service.dart';
import 'mock_data_store.dart';

class NotificationService {
  final ApiService _apiService = ApiService();
  final MockDataStore _dataStore = MockDataStore();
  final Uuid _uuid = const Uuid();

  // CRUD #16: Read Notifications
  Future<List<NotificationModel>> getNotifications(String userId) async {
    final endpoint = userId.isNotEmpty
        ? '${ApiConstants.notifications}?userId=$userId'
        : ApiConstants.notifications;

    final response = await _apiService.get(endpoint);
    if (response.success && response.data != null && response.data is List) {
      return (response.data as List)
          .map((item) => NotificationModel.fromJson(item))
          .toList();
    }

    // Fallback try
    final fallback = await _apiService.get(ApiConstants.notifications);
    if (fallback.success && fallback.data != null && fallback.data is List) {
      return (fallback.data as List)
          .map((item) => NotificationModel.fromJson(item))
          .toList();
    }

    // Mock fallback: return user's notifications or all seeded notifications
    final userNotifs = _dataStore.notifications
        .where((n) => n.userId == userId)
        .toList();
    if (userNotifs.isNotEmpty) return userNotifs;
    return _dataStore.notifications;
  }

  // Get Unread Count
  Future<int> getUnreadCount(String userId) async {
    final endpoint = '${ApiConstants.notifications}/unread-count?userId=$userId';
    final response = await _apiService.get(endpoint);
    if (response.success && response.data != null && response.data['count'] != null) {
      return response.data['count'] as int;
    }

    final notifs = await getNotifications(userId);
    return notifs.where((n) => !n.isRead).length;
  }

  // Create Notification in Backend / Database
  Future<NotificationModel> createNotification({
    required String userId,
    required String title,
    required String message,
    String type = 'emergency',
    String? relatedRequestId,
  }) async {
    final body = {
      'userId': userId,
      'title': title,
      'message': message,
      'type': type,
      if (relatedRequestId != null) 'relatedRequestId': relatedRequestId,
    };

    final response = await _apiService.post(ApiConstants.notifications, body);
    if (response.success && response.data != null) {
      return NotificationModel.fromJson(response.data);
    }

    return sendLocalNotification(
      userId: userId,
      title: title,
      message: message,
      type: type,
      relatedRequestId: relatedRequestId,
    );
  }

  // CRUD #17: Update Notification as Read
  Future<bool> markAsRead(String notificationId) async {
    final endpoint = ApiConstants.markNotificationRead.replaceAll('{id}', notificationId);
    final response = await _apiService.patch(endpoint, {'isRead': true});
    if (response.success) {
      return true;
    }

    // Mock fallback
    final index = _dataStore.notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      _dataStore.notifications[index] = _dataStore.notifications[index].copyWith(isRead: true);
      return true;
    }
    return false;
  }

  // Mark all notifications as read
  Future<bool> markAllAsRead(String userId) async {
    final response = await _apiService.post(ApiConstants.markAllNotificationsRead, {'userId': userId});
    if (response.success) {
      return true;
    }

    // Mock fallback
    for (int i = 0; i < _dataStore.notifications.length; i++) {
      if (_dataStore.notifications[i].userId == userId || userId.isEmpty) {
        _dataStore.notifications[i] = _dataStore.notifications[i].copyWith(isRead: true);
      }
    }
    return true;
  }

  // CRUD #18: Delete/Remove Notification
  Future<bool> deleteNotification(String notificationId) async {
    final response = await _apiService.delete('${ApiConstants.notifications}/$notificationId');
    if (response.success) {
      return true;
    }

    // Mock fallback
    _dataStore.notifications.removeWhere((n) => n.id == notificationId);
    return true;
  }

  // Local push notification / fallback simulation
  Future<NotificationModel> sendLocalNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedRequestId,
  }) async {
    final newNotif = NotificationModel(
      id: 'notif_${_uuid.v4().substring(0, 8)}',
      userId: userId,
      title: title,
      message: message,
      type: type,
      timestamp: DateTime.now(),
      isRead: false,
      relatedRequestId: relatedRequestId,
    );
    _dataStore.notifications.insert(0, newNotif);
    return newNotif;
  }
}
