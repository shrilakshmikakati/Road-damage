// lib/services/damage_ai_service.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/damage_record.dart';

enum RoadFeatureType {
  pothole,
  speedBreaker,
  railwayCrossing,
  roughPatch,
  smooth
}

class MotionData {
  final double accelerationX;
  final double accelerationY;
  final double accelerationZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final DateTime timestamp;

  MotionData({
    required this.accelerationX,
    required this.accelerationY,
    required this.accelerationZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.timestamp,
  });

  // Calculate the magnitude of acceleration
  double get accelerationMagnitude {
    return sqrt(pow(accelerationX, 2) + pow(accelerationY, 2) + pow(accelerationZ, 2));
  }

  // Calculate the magnitude of gyroscope reading
  double get gyroscopeMagnitude {
    return sqrt(pow(gyroX, 2) + pow(gyroY, 2) + pow(gyroZ, 2));
  }

  Map<String, dynamic> toJson() {
    return {
      'accelerationX': accelerationX,
      'accelerationY': accelerationY,
      'accelerationZ': accelerationZ,
      'gyroX': gyroX,
      'gyroY': gyroY,
      'gyroZ': gyroZ,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory MotionData.fromJson(Map<String, dynamic> json) {
    return MotionData(
      accelerationX: json['accelerationX'],
      accelerationY: json['accelerationY'],
      accelerationZ: json['accelerationZ'],
      gyroX: json['gyroX'],
      gyroY: json['gyroY'],
      gyroZ: json['gyroZ'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    );
  }
}

class TrainingExample {
  final List<MotionData> motionSequence;
  final RoadFeatureType featureType;
  final LatLng location;

  TrainingExample({
    required this.motionSequence,
    required this.featureType,
    required this.location,
  });

  Map<String, dynamic> toJson() {
    return {
      'motionSequence': motionSequence.map((e) => e.toJson()).toList(),
      'featureType': featureType.toString(),
      'lat': location.latitude,
      'lng': location.longitude,
    };
  }

  factory TrainingExample.fromJson(Map<String, dynamic> json) {
    List<dynamic> motionList = json['motionSequence'];
    return TrainingExample(
      motionSequence: motionList.map((e) => MotionData.fromJson(e)).toList(),
      featureType: RoadFeatureType.values.firstWhere(
            (e) => e.toString() == json['featureType'],
        orElse: () => RoadFeatureType.smooth,
      ),
      location: LatLng(json['lat'], json['lng']),
    );
  }
}

class DamageAIService extends ChangeNotifier {
  static const String _trainingDataKey = 'ai_training_data';
  List<TrainingExample> _trainingData = [];
  List<MotionData> _currentMotionBuffer = [];
  static const int _bufferSize = 50; // Store last 50 motion readings

  // Thresholds for different types of road features
  // These will be adjusted as AI learns
  double _potholeThreshold = 2.0;
  double _speedBreakerThreshold = 1.5;
  double _railwayCrossingThreshold = 1.8;
  double _roughPatchThreshold = 1.2;

  // Patterns for different road features
  // Will be refined with machine learning
  bool _isInitialized = false;

  // Initialize the service
  Future<void> initialize() async {
    if (!_isInitialized) {
      await _loadTrainingData();
      await _loadThresholds();
      _isInitialized = true;
    }
  }

  // Load saved training data
  Future<void> _loadTrainingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trainingJsonList = prefs.getStringList(_trainingDataKey) ?? [];

      _trainingData = trainingJsonList
          .map((json) => TrainingExample.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();

      if (kDebugMode) {
        print('Loaded ${_trainingData.length} training examples');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading training data: $e');
      }
      _trainingData = [];
    }
  }

  // Save current thresholds
  Future<void> _saveThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pothole_threshold', _potholeThreshold);
    await prefs.setDouble('speedbreaker_threshold', _speedBreakerThreshold);
    await prefs.setDouble('railway_threshold', _railwayCrossingThreshold);
    await prefs.setDouble('roughpatch_threshold', _roughPatchThreshold);
  }

  // Load saved thresholds
  Future<void> _loadThresholds() async {
    final prefs = await SharedPreferences.getInstance();
    _potholeThreshold = prefs.getDouble('pothole_threshold') ?? 2.0;
    _speedBreakerThreshold = prefs.getDouble('speedbreaker_threshold') ?? 1.5;
    _railwayCrossingThreshold = prefs.getDouble('railway_threshold') ?? 1.8;
    _roughPatchThreshold = prefs.getDouble('roughpatch_threshold') ?? 1.2;
  }

  // Save training data
  Future<void> _saveTrainingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _trainingData.map((example) => example.toJson()).toList();
      await prefs.setStringList(_trainingDataKey,
          jsonList.map((json) => json.toString()).toList());
    } catch (e) {
      if (kDebugMode) {
        print('Error saving training data: $e');
      }
    }
  }

  // Add motion data to buffer
  void addMotionData(MotionData data) {
    _currentMotionBuffer.add(data);

    // Keep buffer at max size
    if (_currentMotionBuffer.length > _bufferSize) {
      _currentMotionBuffer.removeAt(0);
    }
  }

  // Add a training example
  Future<void> addTrainingExample(RoadFeatureType featureType, LatLng location) async {
    if (_currentMotionBuffer.isEmpty) return;

    // Create a copy of the current buffer to use as training data
    final trainingExample = TrainingExample(
      motionSequence: List.from(_currentMotionBuffer),
      featureType: featureType,
      location: location,
    );

    _trainingData.add(trainingExample);
    await _saveTrainingData();

    // Adjust thresholds based on new training data
    _adjustThresholds();

    notifyListeners();
  }

  // Clear all training data
  Future<void> clearTrainingData() async {
    _trainingData = [];
    await _saveTrainingData();

    // Reset thresholds to defaults
    _potholeThreshold = 2.0;
    _speedBreakerThreshold = 1.5;
    _railwayCrossingThreshold = 1.8;
    _roughPatchThreshold = 1.2;
    await _saveThresholds();

    notifyListeners();
  }

  // Adjust thresholds based on training data
  void _adjustThresholds() {
    // Simple threshold adjustment based on averages
    // A more sophisticated ML model would replace this

    Map<RoadFeatureType, List<double>> magnitudes = {};

    // Initialize the map
    for (var type in RoadFeatureType.values) {
      magnitudes[type] = [];
    }

    // Collect magnitudes for each type
    for (var example in _trainingData) {
      double avgMagnitude = 0;
      for (var motion in example.motionSequence) {
        avgMagnitude += motion.accelerationMagnitude;
      }
      avgMagnitude /= example.motionSequence.length;

      magnitudes[example.featureType]!.add(avgMagnitude);
    }

    // Calculate new thresholds based on average magnitudes
    void updateThreshold(RoadFeatureType type, double defaultValue) {
      if (magnitudes[type]!.isNotEmpty) {
        double sum = magnitudes[type]!.reduce((a, b) => a + b);
        double avg = sum / magnitudes[type]!.length;

        // Update corresponding threshold
        switch (type) {
          case RoadFeatureType.pothole:
            _potholeThreshold = avg * 0.9; // 90% of average
            break;
          case RoadFeatureType.speedBreaker:
            _speedBreakerThreshold = avg * 0.85;
            break;
          case RoadFeatureType.railwayCrossing:
            _railwayCrossingThreshold = avg * 0.9;
            break;
          case RoadFeatureType.roughPatch:
            _roughPatchThreshold = avg * 0.8;
            break;
          default:
            break;
        }
      }
    }

    // Update all thresholds
    updateThreshold(RoadFeatureType.pothole, _potholeThreshold);
    updateThreshold(RoadFeatureType.speedBreaker, _speedBreakerThreshold);
    updateThreshold(RoadFeatureType.railwayCrossing, _railwayCrossingThreshold);
    updateThreshold(RoadFeatureType.roughPatch, _roughPatchThreshold);

    _saveThresholds();
  }

  // Analyze motion data to detect road feature
  RoadFeatureType analyzeRoadFeature(List<MotionData> motionSequence) {
    if (motionSequence.isEmpty) return RoadFeatureType.smooth;

    // Calculate average and peak magnitudes
    double avgAccelMagnitude = 0;
    double maxAccelMagnitude = 0;
    double avgGyroMagnitude = 0;
    double maxGyroMagnitude = 0;

    for (var motion in motionSequence) {
      double accelMag = motion.accelerationMagnitude;
      double gyroMag = motion.gyroscopeMagnitude;

      avgAccelMagnitude += accelMag;
      avgGyroMagnitude += gyroMag;

      if (accelMag > maxAccelMagnitude) maxAccelMagnitude = accelMag;
      if (gyroMag > maxGyroMagnitude) maxGyroMagnitude = gyroMag;
    }

    avgAccelMagnitude /= motionSequence.length;
    avgGyroMagnitude /= motionSequence.length;

    // Calculate pattern features
    // 1. Duration of event
    int durationMs = motionSequence.last.timestamp.difference(motionSequence.first.timestamp).inMilliseconds;

    // 2. Symmetry of impact (important for distinguishing potholes from speed breakers)
    List<double> accelerationProfile = motionSequence.map((m) => m.accelerationMagnitude).toList();
    double symmetryScore = _calculateSymmetry(accelerationProfile);

    // Classification logic
    // This is where a trained ML model would be better
    if (maxAccelMagnitude > _potholeThreshold && symmetryScore < 0.6 && durationMs < 500) {
      return RoadFeatureType.pothole;
    } else if (maxAccelMagnitude > _speedBreakerThreshold && symmetryScore > 0.7 && durationMs > 800) {
      return RoadFeatureType.speedBreaker;
    } else if (maxAccelMagnitude > _railwayCrossingThreshold && durationMs > 1200) {
      return RoadFeatureType.railwayCrossing;
    } else if (avgAccelMagnitude > _roughPatchThreshold && durationMs > 2000) {
      return RoadFeatureType.roughPatch;
    }

    return RoadFeatureType.smooth;
  }

  // Calculate symmetry of signal (0 = asymmetric, 1 = symmetric)
  double _calculateSymmetry(List<double> signal) {
    if (signal.length < 2) return 1.0;

    int midpoint = signal.length ~/ 2;
    int compareLength = min(midpoint, signal.length - midpoint);

    double totalDiff = 0;
    double maxPossibleDiff = 0;

    for (int i = 0; i < compareLength; i++) {
      double left = signal[midpoint - i - 1];
      double right = signal[midpoint + i];
      totalDiff += (left - right).abs();
      maxPossibleDiff += max(left, right);
    }

    if (maxPossibleDiff == 0) return 1.0;
    return 1.0 - (totalDiff / maxPossibleDiff);
  }

  // Analyze current buffer and determine if it contains a road feature
  RoadFeatureResult analyzeCurrentBuffer(LatLng currentPosition) {
    if (_currentMotionBuffer.length < 10) {
      return RoadFeatureResult(
        featureType: RoadFeatureType.smooth,
        severity: 0.0,
        confidence: 0.0,
        isDamaged: false,
        position: currentPosition,
        timestamp: DateTime.now(),
      );
    }

    RoadFeatureType detectedFeature = analyzeRoadFeature(_currentMotionBuffer);

    // Calculate average acceleration magnitude as severity
    double severity = 0;
    for (var motion in _currentMotionBuffer) {
      severity += motion.accelerationMagnitude;
    }
    severity /= _currentMotionBuffer.length;

    // Calculate confidence based on amount of training data
    double confidence = min(1.0, _trainingData.length / 20); // Max confidence after 20 examples

    // Determine if it's considered damaged
    bool isDamaged = detectedFeature == RoadFeatureType.pothole ||
        detectedFeature == RoadFeatureType.roughPatch;

    return RoadFeatureResult(
      featureType: detectedFeature,
      severity: severity,
      confidence: confidence,
      isDamaged: isDamaged,
      position: currentPosition,
      timestamp: DateTime.now(),
    );
  }

  // Get training data count
  int get trainingExampleCount => _trainingData.length;

  // Get current thresholds
  Map<String, double> get currentThresholds => {
    'pothole': _potholeThreshold,
    'speedBreaker': _speedBreakerThreshold,
    'railwayCrossing': _railwayCrossingThreshold,
    'roughPatch': _roughPatchThreshold,
  };
}

class RoadFeatureResult {
  final RoadFeatureType featureType;
  final double severity;
  final double confidence;
  final bool isDamaged;
  final LatLng position;
  final DateTime timestamp;

  RoadFeatureResult({
    required this.featureType,
    required this.severity,
    required this.confidence,
    required this.isDamaged,
    required this.position,
    required this.timestamp,
  });

  DamageRecord toDamageRecord() {
    String id = '${position.latitude}_${position.longitude}_${timestamp.millisecondsSinceEpoch}';
    return DamageRecord(
      id: id,
      position: position,
      timestamp: timestamp,
      severity: severity,
      isDamaged: isDamaged,
    );
  }
}