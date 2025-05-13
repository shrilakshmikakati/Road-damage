import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  bool _backgroundTrackingEnabled = false;
  double _sensitivityThreshold = 5.0;

  SettingsProvider() {
    _loadSettings();
  }

  // Getters
  bool get darkMode => _darkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get backgroundTrackingEnabled => _backgroundTrackingEnabled;
  double get sensitivityThreshold => _sensitivityThreshold;

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _darkMode = prefs.getBool('darkMode') ?? false;
    _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    _backgroundTrackingEnabled = prefs.getBool('backgroundTrackingEnabled') ?? false;
    _sensitivityThreshold = prefs.getDouble('sensitivityThreshold') ?? 5.0;

    notifyListeners();
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('darkMode', _darkMode);
    await prefs.setBool('notificationsEnabled', _notificationsEnabled);
    await prefs.setBool('backgroundTrackingEnabled', _backgroundTrackingEnabled);
    await prefs.setDouble('sensitivityThreshold', _sensitivityThreshold);
  }

  // Toggle dark mode
  void toggleDarkMode() {
    _darkMode = !_darkMode;
    _saveSettings();
    notifyListeners();
  }

  // Toggle notifications
  void toggleNotifications() {
    _notificationsEnabled = !_notificationsEnabled;
    _saveSettings();
    notifyListeners();
  }

  // Toggle background tracking
  void toggleBackgroundTracking() {
    _backgroundTrackingEnabled = !_backgroundTrackingEnabled;
    _saveSettings();
    notifyListeners();
  }

  // Set sensitivity threshold
  void setSensitivityThreshold(double value) {
    _sensitivityThreshold = value;
    _saveSettings();
    notifyListeners();
  }

  // Add this method to fix the error
  void updateSensitivityThreshold(double value) {
    _sensitivityThreshold = value;
    _saveSettings();
    notifyListeners();
  }
}