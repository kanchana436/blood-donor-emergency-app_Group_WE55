import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lifelink/core/utils/validators.dart';
import 'package:lifelink/providers/auth_provider.dart';
import 'package:lifelink/screens/profile/change_password_screen.dart';

void main() {
  group('Change Password Form Validators', () {
    test('1. Current password validation', () {
      expect(FormValidators.validateCurrentPassword(null), 'Please enter your current password');
      expect(FormValidators.validateCurrentPassword(''), 'Please enter your current password');
      expect(FormValidators.validateCurrentPassword('   '), 'Please enter your current password');
      expect(FormValidators.validateCurrentPassword('mySecretPass123'), isNull);
    });

    test('2. New password validation requirements', () {
      // Empty
      expect(FormValidators.validateNewPassword(null, 'currentPass123'), 'Please enter a new password');
      expect(FormValidators.validateNewPassword('', 'currentPass123'), 'Please enter a new password');
      expect(FormValidators.validateNewPassword('   ', 'currentPass123'), 'Please enter a new password');

      // Less than 6 characters
      expect(
        FormValidators.validateNewPassword('12345', 'currentPass123'),
        'Password must be at least 6 characters',
      );
      expect(
        FormValidators.validateNewPassword('abc', 'currentPass123'),
        'Password must be at least 6 characters',
      );

      // Must be different from current password
      expect(
        FormValidators.validateNewPassword('currentPass123', 'currentPass123'),
        'New password must be different from current password',
      );

      // Valid new password
      expect(
        FormValidators.validateNewPassword('BrandNewPass456!', 'currentPass123'),
        isNull,
      );
    });

    test('3. Confirm password validation', () {
      expect(FormValidators.validateConfirmPassword(null, 'newPass123'), 'Please confirm your password');
      expect(FormValidators.validateConfirmPassword('', 'newPass123'), 'Please confirm your password');
      expect(
        FormValidators.validateConfirmPassword('mismatchedPass', 'newPass123'),
        'Passwords do not match',
      );
      expect(
        FormValidators.validateConfirmPassword('newPass123', 'newPass123'),
        isNull,
      );
    });
  });

  group('ChangePasswordScreen UI & Interaction Tests', () {
    Widget createWidgetUnderTest() {
      return ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: const MaterialApp(
          home: ChangePasswordScreen(),
        ),
      );
    }

    testWidgets('Renders all password fields and show/hide password buttons', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Change Password'), findsOneWidget);
      expect(find.text('Current Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.text('Update Password'), findsOneWidget);

      // 3 visibility toggle icons should be rendered
      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(3));

      // Tap on the first visibility toggle icon
      await tester.tap(find.byIcon(Icons.visibility_outlined).first);
      await tester.pumpAndSettle();

      // One icon should change to visibility_off_outlined
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
    });

    testWidgets('Empty submission displays validation error messages', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap Update Password button without entering any values
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your current password'), findsOneWidget);
      expect(find.text('Please enter a new password'), findsOneWidget);
      expect(find.text('Please confirm your password'), findsOneWidget);
    });

    testWidgets('Rejects weak new password (< 6 chars)', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'oldPassword123');
      await tester.enterText(textFields.at(1), '12345');
      await tester.enterText(textFields.at(2), '12345');

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('Rejects new password identical to current password', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'samePassword123');
      await tester.enterText(textFields.at(1), 'samePassword123');
      await tester.enterText(textFields.at(2), 'samePassword123');

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('New password must be different from current password'), findsOneWidget);
    });

    testWidgets('Rejects mismatched password confirmation', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'oldPassword123');
      await tester.enterText(textFields.at(1), 'brandNewPassword456');
      await tester.enterText(textFields.at(2), 'differentConfirmation789');

      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
