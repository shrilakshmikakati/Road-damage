// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'home_map_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  static const routeName = '/Splash';
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  bool _permissionsChecked = false;
  String _statusMessage = "Initializing...";
  List<Permission> _requiredPermissions = [
    Permission.location,
    Permission.locationAlways,
    Permission.sensors,
    Permission.storage,
  ];

  @override
  void initState() {
    super.initState();

    // Setup animation
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();

    // Begin permission check after a short delay
    Timer(const Duration(seconds: 1), () {
      _checkAndRequestPermissions();
    });
  }

  Future<void> _checkAndRequestPermissions() async {
    setState(() {
      _statusMessage = "Checking permissions...";
    });

    // Check each permission status
    Map<Permission, PermissionStatus> statuses = await _requiredPermissions.request();

    bool allGranted = true;
    for (var entry in statuses.entries) {
      if (!entry.value.isGranted) {
        allGranted = false;
        break;
      }
    }

    setState(() {
      _permissionsChecked = true;
      _statusMessage = allGranted
          ? "All permissions granted. Starting app..."
          : "Some permissions were denied. App may not work properly.";
    });

    // Wait a moment before navigating
    Timer(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacementNamed(HomeMapScreen.routeName);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo with fade in animation
              FadeTransition(
                opacity: _animation,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.road,
                      size: 80,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // App name with scale animation
              ScaleTransition(
                scale: _animation,
                child: Text(
                  "Road Damage Detector",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Status message
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),

              const SizedBox(height: 40),

              // Loading indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),

              const SizedBox(height: 20),

              // Permission indicators
              if (_permissionsChecked)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _requiredPermissions.map((permission) {
                    return FutureBuilder<PermissionStatus>(
                      future: permission.status,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return SizedBox.shrink();

                        bool isGranted = snapshot.data?.isGranted ?? false;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Icon(
                            isGranted ? Icons.check_circle : Icons.cancel,
                            color: isGranted ? Colors.green : Colors.red,
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}