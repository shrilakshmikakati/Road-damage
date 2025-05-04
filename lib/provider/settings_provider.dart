// lib/provider/settings_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  // App settings
  bool _darkMode = false;
  bool _recordingActive = false;
  double _threshold = 5.0; // Default threshold for damage detection
  String _mapStyle = 'standard'; // standard, satellite, terrain
  bool _nightModeMap = true;
  bool _cloudSync = false;
  bool _autoSync = false;

  // Getters
  bool get darkMode => _darkMode;
  bool get recordingActive => _recordingActive;
  double get threshold => _threshold;
  String get mapStyle => _mapStyle;
  bool get nightModeMap => _nightModeMap;
  bool get cloudSync => _cloudSync;
  bool get autoSync => _autoSync;

  // Load settings from SharedPreferences
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _darkMode = prefs.getBool('darkMode') ?? false;
      _threshold = prefs.getDouble('threshold') ?? 5.0;
      _mapStyle = prefs.getString('mapStyle') ?? 'standard';
      _nightModeMap = prefs.getBool('nightModeMap') ?? true;
      _cloudSync = prefs.getBool('cloudSync') ?? false;
      _autoSync = prefs.getBool('autoSync') ?? false;
      _recordingActive = false; // Always start with recording off

      notifyListeners();
    } catch (e) {
      print('Failed to load settings: $e');
    }
  }

  // Save a single setting
  Future<void> _saveSetting(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is String) {
        await prefs.setString(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      }
    } catch (e) {
      print('Failed to save setting $key: $e');
    }
  }

  // Setting updaters
  void setDarkMode(bool value) {
    _darkMode = value;
    _saveSetting('darkMode', value);
    notifyListeners();
  }

  void toggleRecording(bool value) {
    _recordingActive = value;
    // We don't save this to SharedPreferences as it's a temporary state
    notifyListeners();
  }

  void updateThreshold(double value) {
    _threshold = value;
    _saveSetting('threshold', value);
    notifyListeners();
  }

  void setMapStyle(String value) {
    _mapStyle = value;
    _saveSetting('mapStyle', value);
    notifyListeners();
  }

  void setNightModeMap(bool value) {
    _nightModeMap = value;
    _saveSetting('nightModeMap', value);
    notifyListeners();
  }

  void setCloudSync(bool value) {
    _cloudSync = value;
    _saveSetting('cloudSync', value);
    notifyListeners();
  }

  void setAutoSync(bool value) {
    _autoSync = value;
    _saveSetting('autoSync', value);
    notifyListeners();
  }
}