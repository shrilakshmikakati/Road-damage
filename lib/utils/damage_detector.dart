// lib/utils/damage_detector.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart'; // Add this for device ID

class DamageDetector {
  // Singleton instance
  static final DamageDetector _instance = DamageDetector._internal();
  factory DamageDetector() => _instance;
  DamageDetector._internal();

  // Sensor streams
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<LocationData>? _locationSubscription;

  // Current location
  LocationData? _currentLocation;
  final Location _locationService = Location();

  // Detection thresholds
  final double _gyroThreshold = 0.3; // Radians per second
  final double _accelThreshold = 15.0; // m/s^2

  // Time window for detection to avoid duplicates
  final int _cooldownPeriod = 5000; // milliseconds
  int _lastDetectionTime = 0;

  // Listeners
  final List<Function(RoadDamageEvent)> _listeners = [];

  // Local storage for road data
  List<RoadDamageEvent> _roadData = [];
  bool _isRunning = false;
  bool _initialized = false;

  // Device ID for cloud storage
  String _deviceId = 'unknown_device';

  // Initialize the detector
  Future<void> initialize() async {
    if (_initialized) return;

    // Get device ID
    await _getDeviceId();

    // Load saved data from SharedPreferences
    await _loadSavedData();

    // Setup location service
    await _setupLocationService();

    _initialized = true;
  }

  // Get unique device ID
  Future<void> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Theme.of(null).platform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'unknown_ios_device';
      } else if (Theme.of(null).platform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        _deviceId = androidInfo.id;
      }
    } catch (e) {
      print('Failed to get device ID: $e');
      _deviceId = 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getStringList('road_damage_data') ?? [];

    _roadData = savedData.map((data) {
      final parts = data.split('|');
      return RoadDamageEvent(
        latitude: double.parse(parts[0]),
        longitude: double.parse(parts[1]),
        severity: double.parse(parts[2]),
        timestamp: int.parse(parts[3]),
        isDamaged: parts[4] == 'true',
      );
    }).toList();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataToSave = _roadData.map((event) =>
    '${event.latitude}|${event.longitude}|${event.severity}|${event.timestamp}|${event.isDamaged}'
    ).toList();

    await prefs.setStringList('road_damage_data', dataToSave);
  }

  Future<void> _setupLocationService() async {
    bool serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) {
        throw Exception('Location service not enabled');
      }
    }

    PermissionStatus permissionStatus = await _locationService.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await _locationService.requestPermission();
      if (permissionStatus != PermissionStatus.granted) {
        throw Exception('Location permission not granted');
      }
    }

    // Configure location settings
    await _locationService.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 5000, // 5 seconds
      distanceFilter: 10, // 10 meters
    );
  }

  // Start monitoring
  void startMonitoring() {
    if (_isRunning) return;
    _isRunning = true;

    // Setup gyroscope stream
    _gyroscopeSubscription = gyroscopeEvents.listen((GyroscopeEvent event) {
      _processGyroscopeData(event);
    });

    // Setup accelerometer stream
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
      _processAccelerometerData(event);
    });

    // Setup location stream
    _locationSubscription = _locationService.onLocationChanged.listen((LocationData location) {
      _currentLocation = location;
      // Log smooth road segments periodically
      _logSmoothRoad();
    });
  }

  // Stop monitoring
  void stopMonitoring() {
    _isRunning = false;
    _gyroscopeSubscription?.cancel();
    _accelerometerSubscription?.cancel();
    _locationSubscription?.cancel();
    _saveData();
  }

  // Process gyroscope data
  void _processGyroscopeData(GyroscopeEvent event) {
    if (_currentLocation == null) return;

    // Calculate magnitude of rotation
    final magnitude = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z, 2));

    // Check against threshold
    if (magnitude > _gyroThreshold) {
      _checkAndLogDamage(magnitude);
    }
  }

  // Process accelerometer data
  void _processAccelerometerData(AccelerometerEvent event) {
    if (_currentLocation == null) return;

    // Calculate magnitude of acceleration (excluding gravity)
    final double gForce = sqrt(pow(event.x, 2) + pow(event.y, 2) + pow(event.z - 9.8, 2));

    // Check against threshold
    if (gForce > _accelThreshold) {
      _checkAndLogDamage(gForce);
    }
  }

  // Check cooldown period and log damage if appropriate
  void _checkAndLogDamage(double severity) {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Check if we're still in cooldown period
    if (now - _lastDetectionTime < _cooldownPeriod) {
      return;
    }

    _lastDetectionTime = now;
    final event = RoadDamageEvent(
      latitude: _currentLocation!.latitude!,
      longitude: _currentLocation!.longitude!,
      severity: severity,
      timestamp: now,
      isDamaged: true,
    );

    // Add to local data
    _roadData.add(event);

    // Notify listeners
    for (var listener in _listeners) {
      listener(event);
    }

    // Save to cloud if enabled
    _saveToCloud(event);

    // Save locally
    _saveData();
  }

  // Log smooth road periodically
  void _logSmoothRoad() {
    if (_currentLocation == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;

    // Log smooth road every 30 seconds
    if (now - _lastDetectionTime > 30000) {
      final event = RoadDamageEvent(
        latitude: _currentLocation!.latitude!,
        longitude: _currentLocation!.longitude!,
        severity: 0.0,
        timestamp: now,
        isDamaged: false,
      );

      // Add to local data
      _roadData.add(event);

      // Notify listeners
      for (var listener in _listeners) {
        listener(event);
      }
    }
  }

  // Save data to Firebase
  void _saveToCloud(RoadDamageEvent event) {
    try {
      FirebaseFirestore.instance.collection('road_damage').add({
        'latitude': event.latitude,
        'longitude': event.longitude,
        'severity': event.severity,
        'timestamp': event.timestamp,
        'isDamaged': event.isDamaged,
        'device_id': _deviceId,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Failed to save to cloud: $e');
    }
  }

  // Add listener for road damage events
  void addListener(Function(RoadDamageEvent) listener) {
    _listeners.add(listener);
  }

  // Remove listener
  void removeListener(Function(RoadDamageEvent) listener) {
    _listeners.remove(listener);
  }

  // Get all road data
  List<RoadDamageEvent> getRoadData() {
    return _roadData;
  }

  // Clear all saved data
  Future<void> clearData() async {
    _roadData.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('road_damage_data');
  }
}

// Road damage event model
class RoadDamageEvent {
  final double latitude;
  final double longitude;
  final double severity;
  final int timestamp;
  final bool isDamaged;

  RoadDamageEvent({
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.timestamp,
    required this.isDamaged,
  });
}