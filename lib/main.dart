import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/verification_queue_provider.dart';
import 'providers/emergency_contact_provider.dart';
import 'providers/blood_stock_provider.dart';
import 'providers/donor_availability_provider.dart';
import 'providers/donor_provider.dart';
import 'providers/request_provider.dart';
import 'providers/notification_provider.dart';
import 'services/api_service.dart';
import 'screens/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations & status bar appearance
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize API service and storage
  await ApiService().init();

  runApp(const LifeLinkApp());
}

class LifeLinkApp extends StatelessWidget {
  const LifeLinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, BloodStockProvider>(
          create: (_) => BloodStockProvider(),
          update: (_, auth, stock) => stock!..setUser(auth.currentUser?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, EmergencyContactProvider>(
          create: (_) => EmergencyContactProvider(),
          update: (_, auth, contacts) => contacts!..setUser(auth.currentUser?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, VerificationQueueProvider>(
          create: (_) => VerificationQueueProvider(),
          update: (_, auth, queue) => queue!..setUser(auth.currentUser?.id),
        ),
        ChangeNotifierProxyProvider<AuthProvider, DonorAvailabilityProvider>(
          create: (_) => DonorAvailabilityProvider(),
          update: (_, auth, avail) => avail!..setUser(auth.currentUser?.id),
        ),
        ChangeNotifierProvider(create: (_) => DonorProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return MaterialApp(
            title: 'LifeLink',
            debugShowCheckedModeBanner: false,
            theme: authProvider.isDonor
                ? AppTheme.donorTheme
                : AppTheme.recipientTheme,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
