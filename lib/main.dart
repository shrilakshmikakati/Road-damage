// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core/firebase_core.dart';
import 'provider/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/home_map_screen.dart';
import 'screens/calibration_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';

void main() async{

  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(
    ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
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
      },
    );
  }
}