import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifelink/models/notification_model.dart';
import 'package:lifelink/models/user_model.dart';
import 'package:lifelink/providers/auth_provider.dart';
import 'package:lifelink/providers/notification_provider.dart';
import 'package:lifelink/providers/request_provider.dart';
import 'package:lifelink/screens/notifications/notifications_screen.dart';
import 'package:lifelink/services/notification_service.dart';

class TestAuth extends AuthProvider {
  TestAuth(this.role);
  final String role;
  @override
  UserModel get currentUser => UserModel(
    id: 'local-user',
    name: 'Test User',
    email: 'test@example.invalid',
    phone: '0770000000',
    role: role,
  );
}

class TestNotifications extends NotificationService {
  final List<String> requestedUsers = [];
  @override
  Future<List<NotificationModel>> getNotifications(String userId) async {
    requestedUsers.add(userId);
    return [
      NotificationModel.fromJson({
        'id': 'stock-alert',
        'userId': userId,
        'type': 'BLOOD_STOCK_UPDATE',
        'title': 'O+ Blood Stock Update',
        'message': 'O+ blood is now Available at National Blood Bank - Colombo. 15 units currently available.',
        'timestamp': DateTime.now()
            .subtract(const Duration(minutes: 2))
            .toIso8601String(),
        'isRead': false,
      }),
    ];
  }
}

void main() {
  for (final role in ['donor', 'recipient']) {
    testWidgets(
      '$role sees local blood stock notification through existing screen',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final service = TestNotifications();
        final provider = NotificationProvider(service: service);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>(
                create: (_) => TestAuth(role),
              ),
              ChangeNotifierProvider<NotificationProvider>.value(
                value: provider,
              ),
              ChangeNotifierProvider<RequestProvider>(
                create: (_) => RequestProvider(),
              ),
            ],
            child: const MaterialApp(home: NotificationsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(service.requestedUsers, ['local-user']);
        expect(find.text('O+ Blood Stock Update'), findsOneWidget);
        expect(
          find.text(
            'O+ blood is now Available at National Blood Bank - Colombo. 15 units currently available.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('2'), findsWidgets);
        expect(provider.unreadCount, 1);
        provider.setFilter('Unread');
        await tester.pumpAndSettle();
        expect(find.text('O+ Blood Stock Update'), findsOneWidget);
        provider.setFilter('Emergency');
        await tester.pumpAndSettle();
        expect(find.text('O+ Blood Stock Update'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
