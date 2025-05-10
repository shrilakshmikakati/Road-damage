import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_map_screen.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  static const routeName = '/';

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(Duration(seconds: 2)); // Show splash for 2 seconds

    if (!mounted) return;

    // Check if user is logged in
    final user = FirebaseAuth.instance.currentUser;

    Navigator.of(context).pushReplacementNamed(
      user != null ? HomeMapScreen.routeName : AuthScreen.routeName,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              height: 150,
            ),
            SizedBox(height: 24),
            Text(
              'Road Damage Detector',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}