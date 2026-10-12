import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifelink/providers/auth_provider.dart';
import 'package:lifelink/screens/auth/login_screen.dart';
import 'package:lifelink/screens/auth/role_selection_screen.dart';

void main() {
  testWidgets('blood bank selection preserves manager and opens coordinator login', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = AuthProvider();
    await tester.pumpWidget(ChangeNotifierProvider.value(value: auth, child: const MaterialApp(home: RoleSelectionScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Blood Bank / Hospital'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue as Coordinator'));
    await tester.pumpAndSettle();
    expect(auth.activeRole, 'manager');
    expect(tester.widget<LoginScreen>(find.byType(LoginScreen)).role, 'manager');
    expect(find.text('Welcome, Coordinator'), findsOneWidget);
    expect(find.text('Welcome, Caregiver'), findsNothing);
    expect(find.text('sarah.p@lifelink.org'), findsNothing);
    expect(find.text('password123'), findsNothing);
  });
}
