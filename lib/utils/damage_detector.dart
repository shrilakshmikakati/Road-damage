// lib/utils/damage_detector.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/damage_record.dart';
import '../services/damage_ai_service.dart';

class RoadDamageEvent {
  final double latitude;
  final double longitude;
  final double severity;
  final bool isDamaged;
  final DateTime timestamp;
  final RoadFeatureType featureType;

  RoadDamageEvent({
    required this.latitude,
    required this.longitude,
    required this.severity,
    required this.isDamaged,
    required this.timestamp,
    required this.featureType,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'severity': severity,
      'isDamaged': isDamaged,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'featureType': featureType.toString(),
    };
  }

  factory RoadDamageEvent.fromJson(Map<String, dynamic> json) {
    return RoadDamageEvent(
      latitude: json['latitude'],
      longitude: json['longitude'],
      severity: json['severity'],
      isDamaged: json['isDamaged'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      featureType: RoadFeatureType.values.firstWhere(
            (e) => e.toString() == json['featureType'],
        orElse: () => RoadFeatureType.smooth,
      ),
    );
  }
}

class DamageDetector extends ChangeNotifier {
  static const String _storageKey = 'road_damage_events';

  // Location service
  final Location _locationService = Location();
  LocationData? _currentLocation;

  // AI service
  final DamageAIService _aiService = DamageAIService();

  // List of detected road damage events
  List<RoadDamageEvent> _events = [];

  // Streaming subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<LocationData>? _locationSubscription;

  // Tracking state
  bool _isMonitoring = false;
  bool _isInitialized = false;

  // Settings
  double _damageThreshold = 2.0; // Default threshold

  // AI mode
  bool _isAIEnabled = true;

  // Training mode
  bool _isTrainingMode = false;

  // Initialize the detector
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load settings
    final prefs = await SharedPreferences.getInstance();
    _damageThreshold = prefs.getDouble('damage_threshold') ?? 2.0;
    _isAIEnabled = prefs.getBool('ai_enabled') ?? true;

    // Initialize location service
    await _locationService.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,
      distanceFilter: 5,
    );

    // Request permission
    bool serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    var permissionStatus = await _locationService.hasPermission();
    if (permissionStatus == PermissionStatus.denied) {
      permissionStatus = await _locationService.requestPermission();
      if (permissionStatus != PermissionStatus.granted) {
        return;
      }
    }

    // Initialize AI service
    await _aiService.initialize();

    // Load saved events
    await _loadEvents();

    _isInitialized = true;
  }

  // Load saved events
  Future<void> _loadEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_storageKey) ?? [];

      _events = jsonList.map((str) =>
          RoadDamageEvent.fromJson(jsonDecode(str))
      ).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading road damage events: $e');
      }
      _events = [];
    }
  }

  // Save events
  Future<void> _saveEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _events.map((event) =>
          jsonEncode(event.toJson())
      ).toList();

      await prefs.setStringList(_storageKey, jsonList);
    } catch (e) {
      if (kDebugMode) {
        print('Error saving road damage events: $e');
      }
    }
  }

  // Start monitoring for road damage
  void startMonitoring() {
    if (_isMonitoring) return;

    // Subscribe to sensor events
    const samplingPeriod = Duration(milliseconds: 200); // 5 Hz sampling

    _accelerometerSubscription = userAccelerometerEvents.listen(
          (AccelerometerEvent event) {
        _processAccelerometerData(event);
      },
    );

    _gyroscopeSubscription = gyroscopeEvents.listen(
          (GyroscopeEvent event) {
        _processGyroscopeData(event);
      },
    );

    // Subscribe to location updates
    _locationSubscription = _locationService.onLocationChanged.listen(
          (LocationData location) {
        _currentLocation = location;
      },
    );

    _isMonitoring = true;
    notifyListeners();
  }

  // Stop monitoring
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _locationSubscription?.cancel();

    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _locationSubscription = null;

    _isMonitoring = false;
    notifyListeners();
  }

  // Process accelerometer data
  void _processAccelerometerData(AccelerometerEvent event) {
    if (_currentLocation == null) return;

    // Add data to AI service
    final motionData = MotionData(
      accelerationX: event.x,
      accelerationY: event.y,
      accelerationZ: event.z,
      gyroX: 0, // Will be updated from gyroscope event
      gyroY: 0,
      gyroZ: 0,
      timestamp: DateTime.now(),
    );

    _aiService.addMotionData(motionData);

    // Analyze data
    if (_isAIEnabled) {
      _analyzeWithAI();
    } else {
      _analyzeWithSimpleThreshold(event);
    }
  }

  // Process gyroscope data
  void _processGyroscopeData(GyroscopeEvent event) {
    // The gyroscope data is used by the AI service
    // It doesn't directly trigger damage detection
  }

  // Analyze with simple threshold (legacy method)
  void _analyzeWithSimpleThreshold(AccelerometerEvent event) {
    if (_currentLocation == null) return;

    // Calculate magnitude of acceleration
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

    // Check if magnitude exceeds threshold
    if (magnitude > _damageThreshold) {
      // Create damage event
      final damageEvent = RoadDamageEvent(
        latitude: _currentLocation!.latitude!,
        longitude: _currentLocation!.longitude!,
        severity: magnitude,
        isDamaged: true,
        timestamp: DateTime.now(),
        featureType: RoadFeatureType.pothole, // Default classification
      );

      // Add to list and notify listeners
      _events.add(damageEvent);
      _saveEvents();
      notifyListeners();
    }
  }

  // Analyze with AI
  void _analyzeWithAI() {
    if (_currentLocation == null) return;

    // Get current position
    final position = LatLng(
      _currentLocation!.latitude!,
      _currentLocation!.longitude!,
    );

    // Analyze current buffer
    final result = _aiService.analyzeCurrentBuffer(position);

    // Check if it's a significant road feature
    if (result.featureType != RoadFeatureType.smooth || result.severity > _damageThreshold) {
      // If in training mode, don't add to events
      if (_isTrainingMode) return;

      // Create damage event
      final damageEvent = RoadDamageEvent(
        latitude: position.latitude,
        longitude: position.longitude,
        severity: result.severity,
        isDamaged: result.isDamaged,
        timestamp: DateTime.now(),
        featureType: result.featureType,
      );

      // Add to list and notify listeners
      _events.add(damageEvent);
      _saveEvents();
      notifyListeners();
    }
  }

  // Add training example
  Future<void> addTrainingExample(RoadFeatureType featureType) async {
    if (_currentLocation == null) return;

    final position = LatLng(
      _currentLocation!.latitude!,
      _currentLocation!.longitude!,
    );

    await _aiService.addTrainingExample(featureType, position);
  }

  // Clear all data
  Future<void> clearData() async {
    _events = [];
    await _saveEvents();
    notifyListeners();
  }

  // Update damage threshold
  Future<void> updateThreshold(double threshold) async {
    _damageThreshold = threshold;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('damage_threshold', threshold);
    notifyListeners();
  }

  // Toggle AI mode
  Future<void> toggleAIMode(bool enabled) async {
    _isAIEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_enabled', enabled);
    notifyListeners();
  }

  // Toggle training mode
  void toggleTrainingMode(bool enabled) {
    _isTrainingMode = enabled;
    notifyListeners();
  }

  // Get all road damage events
  List<RoadDamageEvent> getRoadData() {
    return List.unmodifiable(_events);
  }

  // Get damage threshold
  double get damageThreshold => _damageThreshold;

  // Get AI mode status
  bool get isAIEnabled => _isAIEnabled;

  // Get training mode status
  bool get isTrainingMode => _isTrainingMode;

  // Get monitoring status
  bool get isMonitoring => _isMonitoring;

  // Get AI training data count
  int get trainingExampleCount => _aiService.trainingExampleCount;

  // Helper function to generate square root
  double sqrt(double value) {
    return value <= 0 ? 0 : math.sqrt(value);
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}