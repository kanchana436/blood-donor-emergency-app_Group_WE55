import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lifelink/core/utils/validators.dart';
import 'package:lifelink/providers/auth_provider.dart';
import 'package:lifelink/screens/auth/forgot_password_screen.dart';
import 'package:lifelink/screens/auth/otp_verification_screen.dart';
import 'package:lifelink/screens/auth/reset_password_screen.dart';
import 'package:lifelink/widgets/custom_button.dart';

void main() {
  group('Forgot Password & OTP Form Validators', () {
    test('1. Email validation in forgot password flow', () {
      expect(FormValidators.validateEmail(null), 'Please enter your email address');
      expect(FormValidators.validateEmail(''), 'Please enter your email address');
      expect(FormValidators.validateEmail('invalid-email'), isNotNull);
      expect(FormValidators.validateEmail('user@lifelink.org'), isNull);
    });

    test('2. Password validation in reset password flow', () {
      expect(FormValidators.validatePassword(null), 'Please enter a password');
      expect(FormValidators.validatePassword(''), 'Please enter a password');
      expect(FormValidators.validatePassword('12345'), 'Password must be at least 6 characters');
      expect(FormValidators.validatePassword('SecurePass123!'), isNull);

      expect(FormValidators.validateConfirmPassword('', 'SecurePass123!'), 'Please confirm your password');
      expect(FormValidators.validateConfirmPassword('Different123!', 'SecurePass123!'), 'Passwords do not match');
      expect(FormValidators.validateConfirmPassword('SecurePass123!', 'SecurePass123!'), isNull);
    });
  });

  group('ForgotPasswordScreen UI Tests', () {
    Widget buildScreen() {
      return ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: const MaterialApp(
          home: ForgotPasswordScreen(),
        ),
      );
    }

    testWidgets('Renders email input and Send Verification Code button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Reset Your Password'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Send Verification Code'), findsOneWidget);
    });

    testWidgets('Empty email submission triggers validation error', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email address'), findsOneWidget);
    });

    testWidgets('Invalid email format triggers validation error', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final emailField = find.byType(TextFormField);
      await tester.enterText(emailField, 'bad-email-format');
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address (e.g. name@example.com)'), findsOneWidget);
    });
  });

  group('OtpVerificationScreen UI Tests', () {
    Widget buildScreen() {
      return ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: const MaterialApp(
          home: OtpVerificationScreen(email: 'test@lifelink.org'),
        ),
      );
    }

    testWidgets('Renders recipient email, 6 OTP input boxes, expiry timer, and buttons', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Enter Verification Code'), findsOneWidget);
      expect(find.text('test@lifelink.org'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(6));
      expect(find.text('Verify OTP'), findsOneWidget);
      expect(find.textContaining('Code expires in'), findsOneWidget);
      expect(find.textContaining('Resend in'), findsOneWidget);
    });

    testWidgets('Incomplete OTP triggers validation error', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Enter only 3 digits
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '1');
      await tester.enterText(textFields.at(1), '2');
      await tester.enterText(textFields.at(2), '3');

      await tester.tap(find.text('Verify OTP'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter all 6 digits of your verification code.'), findsOneWidget);
    });
  });

  group('ResetPasswordScreen UI Tests', () {
    Widget buildScreen() {
      return ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(),
        child: const MaterialApp(
          home: ResetPasswordScreen(
            email: 'test@lifelink.org',
            resetToken: 'mock_reset_token',
          ),
        ),
      );
    }

    testWidgets('Renders New Password, Confirm Password, and Reset button', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Create New Password'), findsOneWidget);
      expect(find.text('New Password'), findsOneWidget);
      expect(find.text('Confirm New Password'), findsOneWidget);
      expect(find.widgetWithText(CustomButton, 'Reset Password'), findsOneWidget);

      // Eye toggle buttons for both password fields
      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
    });

    testWidgets('Rejects weak new password (< 6 chars)', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '123');
      await tester.enterText(fields.at(1), '123');

      await tester.tap(find.widgetWithText(CustomButton, 'Reset Password'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('Rejects mismatched password confirmation', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'BrandNewPass123!');
      await tester.enterText(fields.at(1), 'MismatchedPass456!');

      await tester.tap(find.widgetWithText(CustomButton, 'Reset Password'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });
}
