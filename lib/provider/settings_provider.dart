// lib/provider/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  // Detection settings
  double _threshold = 2.0;
  bool _aiEnabled = true;

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

  Future<void> toggleAIMode(bool enabled) async {
    _aiEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_enabled', _aiEnabled);
    notifyListeners();
  }

  // Map settings methods
  Future<void> setMapStyle(String style) async {
    _mapStyle = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_style', _mapStyle);
    notifyListeners();
  }

  Future<void> setNightModeMap(bool enabled) async {
    _nightModeMap = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('night_mode_map', _nightModeMap);
    notifyListeners();
  }

  // Storage & sync settings methods
  Future<void> toggleAutoSync(bool enabled) async {
    _autoSync = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync', _autoSync);
    notifyListeners();
  }

  Future<void> setCloudSync(bool enabled) async {
    _cloudSync = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cloud_sync', _cloudSync);
    notifyListeners();
  }

  // Appearance settings methods
  Future<void> setDarkMode(bool enabled) async {
    _darkMode = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', _darkMode);
    notifyListeners();
  }

  // Getters
  double get threshold => _threshold;
  bool get aiEnabled => _aiEnabled;
  String get mapStyle => _mapStyle;
  bool get nightModeMap => _nightModeMap;
  bool get autoSync => _autoSync;
  bool get cloudSync => _cloudSync;
  bool get darkMode => _darkMode;
}