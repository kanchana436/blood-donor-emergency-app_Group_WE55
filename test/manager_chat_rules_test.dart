import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifelink/core/constants/api_constants.dart';
import 'package:lifelink/models/user_model.dart';
import 'package:lifelink/models/donor_profile_model.dart';
import 'package:lifelink/models/chat_model.dart';
import 'package:lifelink/providers/auth_provider.dart';
import 'package:lifelink/providers/chat_provider.dart';
import 'package:lifelink/providers/donor_provider.dart';
import 'package:lifelink/providers/notification_provider.dart';
import 'package:lifelink/providers/request_provider.dart';
import 'package:lifelink/providers/verification_queue_provider.dart';
import 'package:lifelink/services/auth_service.dart';
import 'package:lifelink/services/chat_service.dart';
import 'package:lifelink/screens/auth/login_screen.dart';
import 'package:lifelink/screens/auth/email_verification_screen.dart';
import 'package:lifelink/screens/manager/manager_rules_screen.dart';
import 'package:lifelink/screens/manager/manager_main_navigation.dart';
import 'package:lifelink/screens/manager/manager_chat_reauth_screen.dart';
import 'package:lifelink/screens/manager/manager_donor_chat_screen.dart';
import 'package:lifelink/screens/donor/donor_main_navigation.dart';
import 'package:lifelink/screens/recipient/recipient_main_navigation.dart';
import 'package:lifelink/screens/chat/private_chat_screen.dart';

UserModel account(String role) => UserModel(
  id: role,
  name: 'Test User',
  email: '$role@example.com',
  phone: '0770000000',
  role: role,
  isEmailVerified: true,
);

class FakeAuthService extends AuthService {
  String role;
  FakeAuthService(this.role);
  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async => account(role);
  @override
  Future<UserModel> verifyEmailOtp({
    required String email,
    required String otp,
  }) async => account(role);
}

class FakeAuth extends AuthProvider {
  bool accepted = false, fail = false;
  int accepts = 0;
  FakeAuth(String role) : super(service: FakeAuthService(role));
  @override
  bool get managerRulesAccepted => accepted;
  @override
  Future<void> acceptManagerRules() async {
    accepts++;
    if (fail) throw Exception('Acceptance could not be saved');
    accepted = true;
    notifyListeners();
  }
}

class FakeDonor extends DonorProvider {
  @override
  DonorProfileModel get profile => DonorProfileModel(
    id: 'profile',
    userId: 'donor',
    bloodGroup: 'O+',
    city: 'Colombo',
  );
  @override
  Future<void> loadDonorData(String userId) async {}
}

class FakeRequests extends RequestProvider {
  @override
  Future<void> loadAllRequests() async {}
  @override
  Future<void> loadMyRequests(String requesterId) async {}
}

class FakeNotifications extends NotificationProvider {
  @override
  Future<void> loadNotifications(String userId) async {}
}

class FakeChat extends ChatService {
  String? email, password, sent;
  int opens = 0;
  bool expired = false;
  Completer<List<ChatDonor>>? pending;
  ChatConversation get conversation => ChatConversation.fromJson({
    'id': 'c',
    'managerId': 'manager',
    'donorId': 'donor',
    'managerName': 'Manager',
    'donorName': 'Donor',
    'branchName': 'Colombo Bank',
    'city': 'Colombo',
  });
  @override
  Future<void> verify(String email, String password) async {
    this.email = email;
    this.password = password;
  }

  @override
  Future<List<ChatDonor>> donors() async {
    if (expired) throw ChatAccessException('Verify again');
    return pending == null
        ? [
            ChatDonor.fromJson({
              'userId': 'donor',
              'name': 'Donor',
              'city': 'Colombo',
              'bloodGroup': 'O+',
            }),
          ]
        : pending!.future;
  }

  @override
  Future<ChatConversation> open({String? donorId}) async {
    opens++;
    return conversation;
  }

  @override
  Future<List<ChatMessage>> messages(String id, {String? before}) async => [];
  @override
  Future<void> send(String id, String text) async {
    sent = text;
  }
}

Widget app(AuthProvider auth, ChatProvider chat, Widget home) => MultiProvider(
  providers: [
    ChangeNotifierProvider<AuthProvider>.value(value: auth),
    ChangeNotifierProvider<ChatProvider>.value(value: chat),
    ChangeNotifierProvider<DonorProvider>(create: (_) => FakeDonor()),
    ChangeNotifierProvider<RequestProvider>(create: (_) => FakeRequests()),
    ChangeNotifierProvider<NotificationProvider>(
      create: (_) => FakeNotifications(),
    ),
    ChangeNotifierProvider<VerificationQueueProvider>(
      create: (_) => VerificationQueueProvider(),
    ),
  ],
  child: MaterialApp(home: home),
);
Future<void> size(WidgetTester t) async {
  t.view.physicalSize = const Size(900, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final role in ['manager', 'admin', 'donor', 'recipient']) {
    testWidgets('$role login reaches the correct destination', (t) async {
      await size(t);
      final auth = FakeAuth(role);
      await t.pumpWidget(
        app(auth, ChatProvider(service: FakeChat()), LoginScreen(role: role)),
      );
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).at(0), '$role@example.com');
      await t.enterText(find.byType(TextFormField).at(1), 'password');
      await t.tap(find.text('Sign In'));
      await t.pumpAndSettle();
      if (['manager', 'admin'].contains(role)) {
        expect(find.byType(ManagerRulesScreen), findsOneWidget);
        expect(find.text('Manager Dashboard'), findsNothing);
        expect(
          t.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          false,
        );
        expect(
          t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
      } else {
        expect(find.byType(ManagerRulesScreen), findsNothing);
        expect(
          find.byType(
            role == 'donor' ? DonorMainNavigation : RecipientMainNavigation,
          ),
          findsOneWidget,
        );
      }
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'acceptance required, backend failure stays on rules, success opens dashboard',
    (t) async {
      await size(t);
      final auth = FakeAuth('manager')..fail = true;
      await t.pump();
      await auth.login(email: 'manager@example.com', password: 'password');
      await t.pumpWidget(app(auth, ChatProvider(), const ManagerRulesScreen()));
      await t.pumpAndSettle();
      expect(auth.accepts, 0);
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      expect(
        t.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await t.tap(find.text('Accept & Continue'));
      await t.pumpAndSettle();
      expect(find.text('Acceptance could not be saved'), findsOneWidget);
      expect(find.text('Manager Dashboard'), findsNothing);
      auth.fail = false;
      await t.tap(find.text('Accept & Continue'));
      await t.pumpAndSettle();
      expect(auth.accepts, 2);
      expect(find.text('Manager Dashboard'), findsOneWidget);
      expect(find.text('Donor Chat'), findsOneWidget);
    },
  );
  testWidgets('email verification manager path leads to rules', (t) async {
    await size(t);
    final auth = FakeAuth('manager');
    await t.pumpWidget(
      app(
        auth,
        ChatProvider(),
        const EmailVerificationScreen(
          email: 'manager@example.com',
          role: 'manager',
        ),
      ),
    );
    await t.pumpAndSettle();
    for (var i = 0; i < 6; i++) {
      await t.enterText(find.byType(TextFormField).at(i), '${i + 1}');
    }
    await t.tap(find.text('Verify & Activate Account'));
    await t.pumpAndSettle();
    expect(find.byType(ManagerRulesScreen), findsOneWidget);
    expect(find.text('Manager Dashboard'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('saved manager session and direct dashboard cannot skip rules', (
    t,
  ) async {
    final data = account('manager').toJson()
      ..addAll({
        'managerRulesVersion': '1.0',
        'managerRulesAcceptedAt': DateTime.now().toIso8601String(),
      });
    SharedPreferences.setMockInitialValues({
      ApiConstants.userKey: jsonEncode(data),
      ApiConstants.roleKey: 'manager',
    });
    final auth = AuthProvider();
    await t.pumpWidget(
      app(auth, ChatProvider(), const ManagerMainNavigation()),
    );
    await t.pumpAndSettle();
    expect(find.byType(ManagerRulesScreen), findsOneWidget);
    expect(auth.managerRulesAccepted, false);
  });
  testWidgets('manager chat requires manual credentials before donor list', (
    t,
  ) async {
    await size(t);
    final service = FakeChat();
    final p = ChatProvider(service: service);
    await t.pumpWidget(
      app(FakeAuth('manager'), p, const ManagerChatReauthScreen()),
    );
    await t.pumpAndSettle();
    expect(find.byType(ManagerDonorChatScreen), findsNothing);
    for (final f in t.widgetList<TextFormField>(find.byType(TextFormField))) {
      expect(f.controller!.text, isEmpty);
    }
    await t.enterText(find.byType(TextFormField).at(0), 'manager@example.com');
    await t.enterText(find.byType(TextFormField).at(1), 'private password');
    await t.tap(find.text('Verify & Continue'));
    await t.pumpAndSettle();
    expect(service.email, 'manager@example.com');
    expect(service.password, 'private password');
    expect(find.byType(ManagerDonorChatScreen), findsOneWidget);
    expect(find.text('Donor'), findsOneWidget);
  });
  testWidgets('donor entry opens server-resolved chat and sends a message', (
    t,
  ) async {
    await size(t);
    final service = FakeChat();
    final p = ChatProvider(service: service)..setSession('donor:1');
    final auth = FakeAuth('donor');
    await t.pump();
    await auth.login(email: 'donor@example.com', password: 'x');
    await t.pumpWidget(app(auth, p, const PrivateChatScreen(donorEntry: true)));
    await t.pumpAndSettle();
    expect(service.opens, 1);
    expect(find.text('Blood Bank Chat'), findsOneWidget);
    await t.enterText(find.byType(TextField), ' Hello manager ');
    await t.tap(find.byTooltip('Send'));
    await t.pumpAndSettle();
    expect(service.sent, 'Hello manager');
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });
  test('session changes discard late chat responses and expired access clears private data', () async {
    final service = FakeChat()..pending = Completer<List<ChatDonor>>();
    final p = ChatProvider(service: service)..setSession('manager:1');
    final future = p.loadDonors();
    p.setSession('other:2');
    service.pending!.complete([
      ChatDonor.fromJson({
        'userId': 'donor',
        'name': 'Private',
        'city': 'Colombo',
        'bloodGroup': 'O+',
      }),
    ]);
    expect(await future, false);
    expect(p.donors, isEmpty);
    service.pending = null;
    await p.loadDonors();
    expect(p.donors, isNotEmpty);
    service.expired = true;
    expect(await p.loadDonors(), false);
    expect(p.needsVerification, true);
    expect(p.donors, isEmpty);
  });
  test('fresh login and email verification reset session acceptance', () async {
    final auth = AuthProvider(service: FakeAuthService('manager'));
    await Future<void>.delayed(Duration.zero);
    await auth.login(email: 'manager@example.com', password: 'x');
    final first = auth.sessionVersion;
    expect(auth.managerRulesAccepted, false);
    await auth.verifyEmailOtp(email: 'manager@example.com', otp: '123456');
    expect(auth.sessionVersion, greaterThan(first));
    expect(auth.managerRulesAccepted, false);
  });
}
