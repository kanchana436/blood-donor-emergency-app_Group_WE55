import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _activeFilter = 'All'; // 'All', 'Unread', 'Emergency'

  List<NotificationModel> get notifications {
    if (_activeFilter == 'Unread') {
      return _notifications.where((n) => !n.isRead).toList();
    } else if (_activeFilter == 'Emergency') {
      return _notifications.where((n) => n.type == 'emergency').toList();
    }
    return _notifications;
  }

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get activeFilter => _activeFilter;

  void setFilter(String filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  Future<void> loadNotifications(String userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notifications = await _notificationService.getNotifications(userId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> markAsRead(String id) async {
    final success = await _notificationService.markAsRead(id);
    if (success) {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        notifyListeners();
      }
    }
  }

  Future<void> markAllAsRead(String userId) async {
    final success = await _notificationService.markAllAsRead(userId);
    if (success) {
      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
      notifyListeners();
    }
  }

  Future<void> deleteNotification(String id) async {
    final success = await _notificationService.deleteNotification(id);
    if (success) {
      _notifications.removeWhere((n) => n.id == id);
      notifyListeners();
    }
  }

  Future<void> simulateEmergencyPush(String userId, String bloodGroup, String hospital) async {
    final newNotif = await _notificationService.sendLocalNotification(
      userId: userId,
      title: 'CRITICAL: $bloodGroup Blood Needed!',
      message: 'Urgent donor needed at $hospital right now. Tap to respond.',
      type: 'emergency',
    );
    _notifications.insert(0, newNotif);
    notifyListeners();
  }
}
