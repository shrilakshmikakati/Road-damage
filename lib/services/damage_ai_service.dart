// lib/services/damage_ai_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/road_feature_type.dart';

// Motion data class for sensor readings
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
    return math.sqrt(
        math.pow(accelerationX, 2) +
            math.pow(accelerationY, 2) +
            math.pow(accelerationZ, 2)
    );
  }

  // Calculate the magnitude of gyroscope reading
  double get gyroscopeMagnitude {
    return math.sqrt(
        math.pow(gyroX, 2) +
            math.pow(gyroY, 2) +
            math.pow(gyroZ, 2)
    );
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

// Training example class for ML model
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
      'featureType': featureType.toString().split('.').last,
      'lat': location.latitude,
      'lng': location.longitude,
    };
  }

  factory TrainingExample.fromJson(Map<String, dynamic> json) {
    List<dynamic> motionList = json['motionSequence'];
    return TrainingExample(
      motionSequence: motionList.map((e) => MotionData.fromJson(e)).toList(),
      featureType: RoadFeatureTypeExtension.fromString(json['featureType']),
      location: LatLng(json['lat'], json['lng']),
    );
  }

  // Extract features from this training example
  List<double> extractFeatures() {
    if (motionSequence.isEmpty) return List.filled(10, 0.0);

    // Calculate features
    double avgAccel = _calculateAverage(
        motionSequence.map((m) => m.accelerationMagnitude).toList()
    );
    double peakAccel = _calculatePeak(
        motionSequence.map((m) => m.accelerationMagnitude).toList()
    );
    double avgGyro = _calculateAverage(
        motionSequence.map((m) => m.gyroscopeMagnitude).toList()
    );
    double peakGyro = _calculatePeak(
        motionSequence.map((m) => m.gyroscopeMagnitude).toList()
    );
    double symmetry = _calculateSymmetry(
        motionSequence.map((m) => m.accelerationMagnitude).toList()
    );
    int durationMs = motionSequence.last.timestamp
        .difference(motionSequence.first.timestamp).inMilliseconds;
    double durationSec = durationMs / 1000.0;

    // Return feature vector
    return [
      avgAccel,
      peakAccel,
      avgGyro,
      peakGyro,
      symmetry,
      durationSec,
      peakAccel / avgAccel, // peak-to-average ratio
      avgGyro / avgAccel,   // gyro-to-accel ratio
      durationSec * avgAccel, // energy proxy
      motionSequence.length.toDouble() // sample count
    ];
  }

  // Helper methods for feature extraction
  double _calculateAverage(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculatePeak(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce(math.max);
  }

  double _calculateSymmetry(List<double> signal) {
    if (signal.length < 2) return 1.0;

    int midpoint = signal.length ~/ 2;
    int compareLength = math.min(midpoint, signal.length - midpoint);

    double totalDiff = 0;
    double maxPossibleDiff = 0;

    for (int i = 0; i < compareLength; i++) {
      double left = signal[midpoint - i - 1];
      double right = signal[midpoint + i];
      totalDiff += (left - right).abs();
      maxPossibleDiff += math.max(left, right);
    }

    if (maxPossibleDiff == 0) return 1.0;
    return 1.0 - (totalDiff / maxPossibleDiff);
  }
}

// Classification result
class ClassificationResult {
  final RoadFeatureType featureType;
  final double confidence;
  final double severity;
  final Map<RoadFeatureType, double> probabilities;

  ClassificationResult({
    required this.featureType,
    required this.confidence,
    required this.severity,
    required this.probabilities,
  });
}

// Feature extractor interface
abstract class FeatureExtractor {
  List<double> extractFeatures(List<MotionData> motionData);
}

// Simple feature extractor implementation
class SimpleFeatureExtractor implements FeatureExtractor {
  @override
  List<double> extractFeatures(List<MotionData> motionData) {
    if (motionData.isEmpty) return List.filled(10, 0.0);

    // Calculate average and peak magnitudes
    double avgAccel = 0;
    double maxAccel = 0;
    double avgGyro = 0;
    double maxGyro = 0;

    for (var motion in motionData) {
      double accelMag = motion.accelerationMagnitude;
      double gyroMag = motion.gyroscopeMagnitude;

      avgAccel += accelMag;
      avgGyro += gyroMag;

      if (accelMag > maxAccel) maxAccel = accelMag;
      if (gyroMag > maxGyro) maxGyro = gyroMag;
    }

    avgAccel /= motionData.length;
    avgGyro /= motionData.length;

    // Calculate pattern features
    int durationMs = motionData.last.timestamp
        .difference(motionData.first.timestamp).inMilliseconds;
    double durationSec = durationMs / 1000.0;

    // Calculate symmetry
    List<double> accelProfile = motionData.map((m) => m.accelerationMagnitude).toList();
    double symmetry = _calculateSymmetry(accelProfile);

    // Return feature vector
    return [
      avgAccel,
      maxAccel,
      avgGyro,
      maxGyro,
      symmetry,
      durationSec,
      maxAccel / (avgAccel > 0 ? avgAccel : 1.0), // peak-to-average ratio
      avgGyro / (avgAccel > 0 ? avgAccel : 1.0),  // gyro-to-accel ratio
      durationSec * avgAccel, // energy proxy
      motionData.length.toDouble() // sample count
    ];
  }

  // Calculate symmetry of signal (0 = asymmetric, 1 = symmetric)
  double _calculateSymmetry(List<double> signal) {
    if (signal.length < 2) return 1.0;

    int midpoint = signal.length ~/ 2;
    int compareLength = math.min(midpoint, signal.length - midpoint);

    double totalDiff = 0;
    double maxPossibleDiff = 0;

    for (int i = 0; i < compareLength; i++) {
      double left = signal[midpoint - i - 1];
      double right = signal[midpoint + i];
      totalDiff += (left - right).abs();
      maxPossibleDiff += math.max(left, right);
    }

    if (maxPossibleDiff == 0) return 1.0;
    return 1.0 - (totalDiff / maxPossibleDiff);
  }
}

// Classifier interface
abstract class Classifier {
  Future<ClassificationResult> classify(List<double> features);
  Future<void> train(List<TrainingExample> examples);
}

// Threshold-based classifier implementation
class ThresholdClassifier implements Classifier {
  // Thresholds for different types of road features
  Map<RoadFeatureType, double> _thresholds = {
    RoadFeatureType.pothole: 2.0,
    RoadFeatureType.speedBreaker: 1.5,
    RoadFeatureType.railwayCrossing: 1.8,
    RoadFeatureType.roughPatch: 1.2,
    RoadFeatureType.smooth: 0.0,
  };

  // Classification weights for each feature
  final List<double> _weights = [0.3, 0.5, 0.1, 0.1, 0.7, 0.3, 0.4, 0.2, 0.3, 0.1];

  @override
  Future<ClassificationResult> classify(List<double> features) async {
    if (features.isEmpty || features.length < 10) {
      return ClassificationResult(
        featureType: RoadFeatureType.smooth,
        confidence: 0.0,
        severity: 0.0,
        probabilities: {
          for (var type in RoadFeatureType.values) type: type == RoadFeatureType.smooth ? 1.0 : 0.0
        },
      );
    }

    // Weighted score for acceleration magnitude (most important feature)
    double severity = features[1]; // Using peak acceleration as severity

    // Calculate scores for each road feature type
    Map<RoadFeatureType, double> scores = {};

    // Pothole scoring (high peak accel, low symmetry, short duration)
    scores[RoadFeatureType.pothole] =
        features[1] * 0.5 + // peak accel
            (1.0 - features[4]) * 0.3 + // asymmetry (1 - symmetry)
            (1.0 - math.min(features[5] / 0.5, 1.0)) * 0.2; // short duration

    // Speed breaker scoring (high avg accel, high symmetry, medium duration)
    scores[RoadFeatureType.speedBreaker] =
        features[0] * 0.4 + // avg accel
            features[4] * 0.4 + // symmetry
            math.min(features[5] / 1.0, 1.0) * 0.2; // medium duration

    // Railway crossing scoring (medium peak, high duration, medium symmetry)
    scores[RoadFeatureType.railwayCrossing] =
        features[1] * 0.3 + // peak accel
            math.min(features[5] / 1.5, 1.0) * 0.5 + // longer duration
            features[4] * 0.2; // symmetry

    // Rough patch scoring (low peak, long duration, low symmetry)
    scores[RoadFeatureType.roughPatch] =
        math.min(features[0] / 1.0, 1.0) * 0.3 + // moderate avg accel
            math.min(features[5] / 2.0, 1.0) * 0.5 + // long duration
            (1.0 - features[4]) * 0.2; // asymmetry

    // Smooth road scoring (low everything)
    scores[RoadFeatureType.smooth] =
        (1.0 - math.min(features[0] / 0.5, 1.0)) * 0.5 + // low avg accel
            (1.0 - math.min(features[1] / 1.0, 1.0)) * 0.5; // low peak accel

    // Normalize scores to sum to 1.0 (probabilities)
    double totalScore = scores.values.reduce((a, b) => a + b);
    Map<RoadFeatureType, double> probabilities = {};

    if (totalScore > 0) {
      for (var type in RoadFeatureType.values) {
        probabilities[type] = scores[type]! / totalScore;
      }
    } else {
      // Default to smooth if all scores are 0
      for (var type in RoadFeatureType.values) {
        probabilities[type] = type == RoadFeatureType.smooth ? 1.0 : 0.0;
      }
    }

    // Find the highest scoring feature type
    RoadFeatureType bestType = RoadFeatureType.smooth;
    double bestScore = 0.0;

    for (var entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestType = entry.key;
      }
    }

    // Calculate confidence (normalized score)
    double confidence = probabilities[bestType] ?? 0.0;

    return ClassificationResult(
      featureType: bestType,
      confidence: confidence,
      severity: severity,
      probabilities: probabilities,
    );
  }

  @override
  Future<void> train(List<TrainingExample> examples) async {
    if (examples.isEmpty) return;

    // Group examples by feature type
    Map<RoadFeatureType, List<List<double>>> featuresByType = {};

    for (var type in RoadFeatureType.values) {
      featuresByType[type] = [];
    }

    // Extract features for each example
    for (var example in examples) {
      List<double> features = example.extractFeatures();
      featuresByType[example.featureType]!.add(features);
    }

    // Update thresholds based on average peak acceleration (feature index 1)
    for (var type in RoadFeatureType.values) {
      if (type == RoadFeatureType.smooth || featuresByType[type]!.isEmpty) continue;

      // Calculate average peak acceleration for this type
      double sum = 0.0;
      for (var features in featuresByType[type]!) {
        sum += features[1]; // peak acceleration
      }
      double avg = sum / featuresByType[type]!.length;

      // Update threshold with some margin
      _thresholds[type] = avg * 0.9; // 90% of average peak
    }
  }
}

// Main DamageAIService class
class DamageAIService extends ChangeNotifier {
  static const String _trainingDataKey = 'ai_training_data';

  // Components
  final FeatureExtractor _featureExtractor = SimpleFeatureExtractor();
  late final Classifier _classifier;

  // Data
  List<TrainingExample> _trainingData = [];
  List<MotionData> _currentMotionBuffer = [];
  static const int _bufferSize = 50; // Store last 50