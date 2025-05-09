// lib/services/damage_ai_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/road_feature_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class AnalysisResult {
  final double severity;
  final bool isDamaged;
  final RoadFeatureType featureType;

  AnalysisResult({
    required this.severity,
    required this.isDamaged,
    required this.featureType,
  });
}

class DamageAIService implements AIService {
  static const String _trainingDataKey = 'ai_training_data';
  static const String _modelDataKey = 'ai_model_data';
  static const int _bufferSize = 50; // Number of motion samples to keep


  final List<MotionData> _motionBuffer = [];

  List<Map<String, dynamic>> _trainingExamples = [];


  bool _isModelTrained = false;
  int _trainingExampleCount = 0;

  @override
  Future<void> initialize() async {
    await _loadTrainingData();
    await _loadModelData();


  }

  Future<void> _loadTrainingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(_trainingDataKey);

      if (jsonData != null) {
        final data = jsonDecode(jsonData) as Map<String, dynamic>;
        _trainingExampleCount = data['count'] ?? 0;
        _trainingExamples = List<Map<String, dynamic>>.from(data['examples'] ?? []);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading training data: $e');
      }
      _trainingExampleCount = 0;
      _trainingExamples = [];
    }
  }

  Future<void> _loadModelData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonData = prefs.getString(_modelDataKey);

      if (jsonData != null) {
        _isModelTrained = true;
        // In a real app, you would load model weights or parameters here
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading model data: $e');
      }
      _isModelTrained = false;
    }
  }

  Future<void> _saveTrainingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'count': _trainingExampleCount,
        'examples': _trainingExamples,
      };
      await prefs.setString(_trainingDataKey, jsonEncode(data));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving training data: $e');
      }
    }
  }

  Future<void> _saveModelData(Map<String, dynamic> modelData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modelDataKey, jsonEncode(modelData));
      _isModelTrained = true;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving model data: $e');
      }
    }
  }

  @override
  void addMotionData(MotionData data) {
    _motionBuffer.add(data);

    // Keep buffer at the right size
    if (_motionBuffer.length > _bufferSize) {
      _motionBuffer.removeAt(0);
    }
  }

  @override
  AnalysisResult analyzeCurrentBuffer(LatLng position) {
    if (_motionBuffer.isEmpty) {
      return AnalysisResult(
        severity: 0.0,
        isDamaged: false,
        featureType: RoadFeatureType.smooth,
      );
    }

    final features = _calculateFeatures();

    // If model is trained, use it
    if (_isModelTrained && _trainingExampleCount >= 10) {
      return _predictWithModel(features);
    }

    return _simpleAnalysis(features);
  }


  Map<String, dynamic> _calculateFeatures() {
    if (_motionBuffer.isEmpty) {
      return {
        'mean_accel_x': 0.0,
        'mean_accel_y': 0.0,
        'mean_accel_z': 0.0,
        'std_accel_x': 0.0,
        'std_accel_y': 0.0,
        'std_accel_z': 0.0,
        'max_accel_magnitude': 0.0,
      };
    }

    double sumX = 0, sumY = 0, sumZ = 0;
    double maxMag = 0;

    for (var data in _motionBuffer) {
      sumX += data.accelerationX;
      sumY += data.accelerationY;
      sumZ += data.accelerationZ;

      double mag = math.sqrt(
          data.accelerationX * data.accelerationX +
              data.accelerationY * data.accelerationY +
              data.accelerationZ * data.accelerationZ
      );

      if (mag > maxMag) maxMag = mag;
    }

    double meanX = sumX / _motionBuffer.length;
    double meanY = sumY / _motionBuffer.length;
    double meanZ = sumZ / _motionBuffer.length;


    double varX = 0, varY = 0, varZ = 0;

    for (var data in _motionBuffer) {
      varX += (data.accelerationX - meanX) * (data.accelerationX - meanX);
      varY += (data.accelerationY - meanY) * (data.accelerationY - meanY);
      varZ += (data.accelerationZ - meanZ) * (data.accelerationZ - meanZ);
    }

    double stdX = math.sqrt(varX / _motionBuffer.length);
    double stdY = math.sqrt(varY / _motionBuffer.length);
    double stdZ = math.sqrt(varZ / _motionBuffer.length);

    return {
      'mean_accel_x': meanX,
      'mean_accel_y': meanY,
      'mean_accel_z': meanZ,
      'std_accel_x': stdX,
      'std_accel_y': stdY,
      'std_accel_z': stdZ,
      'max_accel_magnitude': maxMag,
    };
  }

  AnalysisResult _simpleAnalysis(Map<String, dynamic> features) {
    final maxMag = features['max_accel_magnitude'];
    final stdZ = features['std_accel_z'];

    // Simple thresholds
    if (maxMag > 5.0) {
      return AnalysisResult(
        severity: maxMag,
        isDamaged: true,
        featureType: RoadFeatureType.pothole,
      );
    } else if (maxMag > 3.0) {
      return AnalysisResult(
        severity: maxMag,
        isDamaged: true,
        featureType: RoadFeatureType.roughPatch,
      );
    } else if (stdZ > 1.5) {
      return AnalysisResult(
        severity: stdZ,
        isDamaged: false,
        featureType: RoadFeatureType.speedBreaker,
      );
    }

    return AnalysisResult(
      severity: maxMag,
      isDamaged: false,
      featureType: RoadFeatureType.smooth,
    );
  }


  AnalysisResult _predictWithModel(Map<String, dynamic> features) {


    final maxMag = features['max_accel_magnitude'];
    final stdZ = features['std_accel_z'];
    final stdY = features['std_accel_y'];

    // Simplified logic - in a real app would use the actual model
    if (maxMag > 4.0 && stdZ > 2.0) {
      return AnalysisResult(
        severity: maxMag * 1.2,
        isDamaged: true,
        featureType: RoadFeatureType.pothole,
      );
    } else if (maxMag > 3.0 && stdY > 1.0) {
      return AnalysisResult(
        severity: maxMag,
        isDamaged: true,
        featureType: RoadFeatureType.roughPatch,
      );
    } else if (stdZ > 1.2 && stdY < 0.8) {
      return AnalysisResult(
        severity: stdZ * 1.5,
        isDamaged: false,
        featureType: RoadFeatureType.speedBreaker,
      );
    } else if (stdZ > 0.9 && stdY > 0.9) {
      return AnalysisResult(
        severity: stdZ + stdY,
        isDamaged: false,
        featureType: RoadFeatureType.railwayCrossing,
      );
    }

    return AnalysisResult(
      severity: maxMag * 0.5,
      isDamaged: false,
      featureType: RoadFeatureType.smooth,
    );
  }

  @override
  Future<void> addTrainingExample(RoadFeatureType type, LatLng position) async {
    final features = _calculateFeatures();

    _trainingExamples.add({
      'type': type.toString().split('.').last,
      'features': features,
      'position': {
        'latitude': position.latitude,
        'longitude': position.longitude,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    _trainingExampleCount++;
    await _saveTrainingData();
  }

  @override
  Future<Map<String, dynamic>> getMotionFeatures() async {
    return _calculateFeatures();
  }

  @override
  void updateTrainingExampleCount(int count) {
    _trainingExampleCount = count;
    _saveTrainingData();
  }

  @override
  Future<bool> trainModel(List<Map<String, dynamic>> examples) async {
    try {
      // In a real app, this would train a ML model
      // For now, just simulate training
      await Future.delayed(const Duration(seconds: 2));

      _trainingExamples = List.from(examples);
      _trainingExampleCount = examples.length;
      await _saveTrainingData();

      final modelData = {
        'version': '1.0',
        'trained_at': DateTime.now().millisecondsSinceEpoch,
        'example_count': examples.length,
        'model_type': 'simple_classifier',
        // In a real app, this would contain model weights or parameters
      };

      await _saveModelData(modelData);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error training model: $e');
      }
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> exportModelData() async {
    // In a real app, this would export model weights or parameters
    return {
      'version': '1.0',
      'exported_at': DateTime.now().millisecondsSinceEpoch,
      'example_count': _trainingExampleCount,
      'model_type': 'simple_classifier',
      // Model parameters would go here
    };
  }


  @override
  Future<void> clearTrainingData() async {
    _trainingExamples = [];
    _trainingExampleCount = 0;
    _isModelTrained = false;

    // Clear storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_trainingDataKey);
    await prefs.remove(_modelDataKey);
  }

  int get trainingExampleCount => _trainingExampleCount;
}

abstract class AIService {
  void addMotionData(MotionData data);
  AnalysisResult analyzeCurrentBuffer(LatLng position);
  Future<void> addTrainingExample(RoadFeatureType type, LatLng position);
  Future<Map<String, dynamic>> getMotionFeatures();
  void updateTrainingExampleCount(int count);
  Future<bool> trainModel(List<Map<String, dynamic>> examples);
  Future<Map<String, dynamic>> exportModelData();
  Future<void> clearTrainingData();
  Future<void> initialize() async {}
}