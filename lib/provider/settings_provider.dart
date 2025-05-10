// lib/provider/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  // Detection settings
  double _threshold = 2.0;
  bool _aiEnabled = true;
  bool _isCalibrated = false;

  // Map settings
  String _mapStyle = 'standard';
  bool _nightModeMap = false;

  // Storage & sync settings
  bool _autoSync = false;
  bool _cloudSync = false;

  // Appearance settings
  bool _darkMode = false;

  SettingsProvider() {
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Detection settings
    _threshold = prefs.getDouble('damage_threshold') ?? 2.0;
    _aiEnabled = prefs.getBool('ai_enabled') ?? true;
    _isCalibrated = prefs.getBool('is_calibrated') ?? false;

    // Map settings
    _mapStyle = prefs.getString('map_style') ?? 'standard';
    _nightModeMap = prefs.getBool('night_mode_map') ?? false;

    // Storage & sync settings
    _autoSync = prefs.getBool('auto_sync') ?? false;
    _cloudSync = prefs.getBool('cloud_sync') ?? false;

    // Appearance settings
    _darkMode = prefs.getBool('dark_mode') ?? false;

    notifyListeners();
  }

  // Detection settings methods
  Future<void> updateThreshold(double value) async {
    _threshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('damage_threshold', _threshold);
    notifyListeners();
  }

  Future<void> toggleAI(bool value) async {
    _aiEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_enabled', _aiEnabled);
    notifyListeners();
  }

  Future<void> setCalibrated(bool value) async {
    _isCalibrated = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_calibrated', _isCalibrated);
    notifyListeners();
  }

  // Map settings methods
  Future<void> updateMapStyle(String style) async {
    _mapStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_style', _mapStyle);
    notifyListeners();
  }

  Future<void> toggleNightModeMap(bool value) async {
    _nightModeMap = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('night_mode_map', _nightModeMap);
    notifyListeners();
  }

  // Storage & sync settings methods
  Future<void> toggleAutoSync(bool value) async {
    _autoSync = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync', _autoSync);
    notifyListeners();
  }

  Future<void> toggleCloudSync(bool value) async {
    _cloudSync = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cloud_sync', _cloudSync);
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Detection settings
    await prefs.setDouble('damage_threshold', _threshold);
    await prefs.setBool('ai_enabled', _aiEnabled);
    await prefs.setBool('is_calibrated', _isCalibrated);

    // Map settings
    await prefs.setString('map_style', _mapStyle);
    await prefs.setBool('night_mode_map', _nightModeMap);

    // Storage & sync settings
    await prefs.setBool('auto_sync', _autoSync);
    await prefs.setBool('cloud_sync', _cloudSync);

    // Appearance settings
    await prefs.setBool('dark_mode', _darkMode);

    notifyListeners();
  }


  // Appearance settings methods
  Future<void> toggleDarkMode(bool value) async {
    _darkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
    notifyListeners();
  }
  void setMapStyle(String style) {
    _mapStyle = style;
    _saveSettings();
    notifyListeners();
  }

  void setNightModeMap(bool value) {
    _nightModeMap = value;
    _saveSettings();
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _darkMode = value;
    _saveSettings();
    notifyListeners();
  }

  void setCloudSync(bool value) {
    _cloudSync = value;
    _saveSettings();
    notifyListeners();
  }
  // Getters
  double get threshold => _threshold;
  bool get aiEnabled => _aiEnabled;
  bool get isCalibrated => _isCalibrated;
  String get mapStyle => _mapStyle;
  bool get nightModeMap => _nightModeMap;
  bool get autoSync => _autoSync;
  bool get cloudSync => _cloudSync;
  bool get darkMode => _darkMode;
}