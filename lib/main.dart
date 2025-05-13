import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_map_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/calibration_screen.dart';
import 'provider/settings_provider.dart';
import 'services/auth_service.dart';

void main() {
  runApp(const RoadDamageApp());
}

class RoadDamageApp extends StatelessWidget {
  const RoadDamageApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => SettingsProvider()),
        Provider<AuthService>(create: (ctx) => AuthService()),
      ],
      child: MaterialApp(
        title: 'Road Damage Detection',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const LoginScreen(),
        routes: {
          HomeMapScreen.routeName: (ctx) => const HomeMapScreen(),
          SettingsScreen.routeName: (ctx) => const SettingsScreen(),
          CalibrationScreen.routeName: (ctx) => const CalibrationScreen(),
          LoginScreen.routeName: (ctx) => const LoginScreen(),
        },
      ),
    );
  }
}