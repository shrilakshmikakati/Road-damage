// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:road_damage_haha/screens/training_screen.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'provider/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_map_screen.dart';
import 'screens/calibration_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/training_screen.dart';
import 'screens/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseAppCheck.instance.activate(
      // Use provider based on platform
      androidProvider: AndroidProvider.playIntegrity,
      // For iOS, use DeviceCheck in production
      appleProvider: AppleProvider.deviceCheck,
      // Use debug provider for development
      webProvider: ReCaptchaV3Provider('YOUR_RECAPTCHA_SITE_KEY'),
    );
  } catch (e) {
    print('Firebase initialization error: $e');
    // Handle initialization error appropriately
  }

  runApp(
    ChangeNotifierProvider(
      create: (context) => SettingsProvider(),
      child: const RoadDamageApp(),
    ),
  );
}

class RoadDamageApp extends StatelessWidget {
  const RoadDamageApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'Road Damage Detector',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        brightness: settings.darkMode ? Brightness.dark : Brightness.light,
      ),
      initialRoute: SplashScreen.routeName,
      routes: {
        SplashScreen.routeName: (_) => const SplashScreen(),
        HomeMapScreen.routeName: (_) => const HomeMapScreen(),
        CalibrationScreen.routeName: (_) => const CalibrationScreen(),
        HistoryScreen.routeName: (_) => const HistoryScreen(),
        SettingsScreen.routeName: (_) => const SettingsScreen(),
        TrainingScreen.routeName: (_) => const TrainingScreen(),
        AuthScreen.routeName: (_) =>  AuthScreen(),
      },
    );
  }
}