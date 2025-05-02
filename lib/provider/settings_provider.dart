// lib/providers/settings_provider.dart
import 'package:flutter/foundation.dart';

class SettingsProvider extends ChangeNotifier {
  double _threshold = 3.5;
  bool _cloudSync = false;
  bool _recordingActive = false;
  String _mapStyle = 'standard'; // standard, satellite, terrain
  bool _darkMode = false;

  double get threshold => _threshold;
  bool get cloudSync => _cloudSync;
  bool get recordingActive => _recordingActive;
  String get mapStyle => _mapStyle;
  bool get darkMode => _darkMode;

  void updateThreshold(double value) {
    _threshold = value;
    notifyListeners();
  }

  void toggleCloudSync(bool value) {
    _cloudSync = value;
    notifyListeners();
  }

  void toggleRecording(bool value) {
    _recordingActive = value;
    notifyListeners();
  }

  void setMapStyle(String style) {
    _mapStyle = style;
    notifyListeners();
  }

  void toggleDarkMode(bool value) {
    _darkMode = value;
    notifyListeners();
  }
}