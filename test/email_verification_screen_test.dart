import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lifelink/providers/auth_provider.dart';
import 'package:lifelink/providers/donor_provider.dart';
import 'package:lifelink/screens/auth/email_verification_screen.dart';

void main() {
  group('EmailVerificationScreen UI & Validation Tests', () {
    Widget buildScreen({String email = 'newdonor@lifelink.org', String role = 'donor'}) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ChangeNotifierProvider<DonorProvider>(create: (_) => DonorProvider()),
        ],
        child: MaterialApp(
          home: EmailVerificationScreen(email: email, role: role),
        ),
      );
    }

    testWidgets('Renders recipient email, 6 OTP fields, Verify button, timer, and resend option',
        (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text('Email Verification'), findsOneWidget);
      expect(find.text('Verify Your Email'), findsOneWidget);
      expect(find.text('newdonor@lifelink.org'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(6));
      expect(find.text('Verify & Activate Account'), findsOneWidget);
      expect(find.textContaining('Code expires in'), findsOneWidget);
      expect(find.textContaining('Resend in'), findsOneWidget);
    });

    testWidgets('Empty OTP submission triggers validation error', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify & Activate Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter the 6-digit verification code.'), findsOneWidget);
    });

    testWidgets('Incomplete OTP triggers validation error', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Enter only first 3 digits
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '1');
      await tester.enterText(textFields.at(1), '2');
      await tester.enterText(textFields.at(2), '3');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify & Activate Account'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter all 6 digits of your verification code.'), findsOneWidget);
    });
  });
}
