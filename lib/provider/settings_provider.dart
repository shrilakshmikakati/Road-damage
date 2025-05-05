// lib/provider/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  double _threshold = 2.0;
  bool _aiEnabled = true;
  bool _autoSync = false;

  SettingsProvider() {
    _loadSettings();
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _threshold = prefs.getDouble('damage_threshold') ?? 2.0;
    _aiEnabled = prefs.getBool('ai_enabled') ?? true;
    _autoSync = prefs.getBool('auto_sync') ?? false;
    notifyListeners();
  }

  // Save threshold
  Future<void> _saveThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('damage_threshold', _threshold);
  }

  // Save AI enabled setting
  Future<void> _saveAIEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_enabled', _aiEnabled);
  }

  // Save auto sync setting
  Future<void> _saveAutoSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync', _autoSync);
  }

  // Update threshold
  Future<void> updateThreshold(double value) async {
    _threshold = value;
    await _saveThreshold();
    notifyListeners();
  }

  // Toggle AI mode
  Future<void> toggleAIMode(bool enabled) async {
    _aiEnabled = enabled;
    await _saveAIEnabled();
    notifyListeners();
  }

  // Toggle auto sync
  Future<void> toggleAutoSync(bool enabled) async {
    _autoSync = enabled;
    await _saveAutoSync();
    notifyListeners();
  }

  // Getters
  double get threshold => _threshold;
  bool get aiEnabled => _aiEnabled;
  bool get autoSync => _autoSync;
}