// lib/utils/damage_detector.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/road_feature_type.dart';
import '../models/custom_location_data.dart';
import '../services/damage_ai_service.dart';


class RoadFeatureEvent {
  final RoadFeatureType type;
  final double latitude;
  final double longitude;
  final int timestamp;

  RoadFeatureEvent({
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
    };
  }
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

  double get accelerationMagnitude {
    return math.sqrt(
        math.pow(accelerationX, 2) +
            math.pow(accelerationY, 2) +
            math.pow(accelerationZ, 2)
    );
  }


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


  List<double> extractFeatures() {
    if (motionSequence.isEmpty) return List.filled(10, 0.0);

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


    return [
      avgAccel,
      peakAccel,
      avgGyro,
      peakGyro,
      symmetry,
      durationSec,
      peakAccel / avgAccel,
      avgGyro / avgAccel,
      durationSec * avgAccel,
      motionSequence.length.toDouble()
    ];
  }


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


class ClassificationResult {
  final RoadFeatureType featureType;
  final double confidence;
  final double severity;
  final bool isDamaged;
  final Map<RoadFeatureType, double> probabilities;

  ClassificationResult({
    required this.featureType,
    required this.confidence,
    required this.severity,
    required this.probabilities,
    this.isDamaged = true,
  });
}


abstract class FeatureExtractor {
  List<double> extractFeatures(List<MotionData> motionData);
}

class SimpleFeatureExtractor implements FeatureExtractor {
  @override
  List<double> extractFeatures(List<MotionData> motionData) {
    if (motionData.isEmpty) return List.filled(10, 0.0);

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

    int durationMs = motionData.last.timestamp
        .difference(motionData.first.timestamp).inMilliseconds;
    double durationSec = durationMs / 1000.0;


    List<double> accelProfile = motionData.map((m) => m.accelerationMagnitude).toList();
    double symmetry = _calculateSymmetry(accelProfile);


    return [
      avgAccel,
      maxAccel,
      avgGyro,
      maxGyro,
      symmetry,
      durationSec,
      maxAccel / (avgAccel > 0 ? avgAccel : 1.0),
      avgGyro / (avgAccel > 0 ? avgAccel : 1.0),
      durationSec * avgAccel,
      motionData.length.toDouble()
    ];
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


abstract class Classifier {
  Future<ClassificationResult> classify(List<double> features);
  Future<void> train(List<TrainingExample> examples);
}

class ThresholdClassifier implements Classifier {

  Map<RoadFeatureType, double> _thresholds = {
    RoadFeatureType.pothole: 2.0,
    RoadFeatureType.speedBreaker: 1.5,
    RoadFeatureType.railwayCrossing: 1.8,
    RoadFeatureType.roughPatch: 1.2,
    RoadFeatureType.smooth: 0.0,
  };




  @override
  Future<ClassificationResult> classify(List<double> features) async {
    if (features.isEmpty || features.length < 10) {
      return ClassificationResult(
        featureType: RoadFeatureType.smooth,
        confidence: 0.0,
        severity: 0.0,
        isDamaged: false,
        probabilities: {
          for (var type in RoadFeatureType.values) type: type == RoadFeatureType.smooth ? 1.0 : 0.0
        },
      );
    }


    double severity = features[1];


    Map<RoadFeatureType, double> scores = {};

    scores[RoadFeatureType.pothole] =
        features[1] * 0.5 + // peak accel
            (1.0 - features[4]) * 0.3 + // asymmetry (1 - symmetry)
            (1.0 - math.min(features[5] / 0.5, 1.0)) * 0.2; // short duration

    scores[RoadFeatureType.speedBreaker] =
        features[0] * 0.4 + // avg accel
            features[4] * 0.4 + // symmetry
            math.min(features[5] / 1.0, 1.0) * 0.2; // medium duration

    scores[RoadFeatureType.railwayCrossing] =
        features[1] * 0.3 + // peak accel
            math.min(features[5] / 1.5, 1.0) * 0.5 + // longer duration
            features[4] * 0.2; // symmetry

    scores[RoadFeatureType.roughPatch] =
        math.min(features[0] / 1.0, 1.0) * 0.3 + // moderate avg accel
            math.min(features[5] / 2.0, 1.0) * 0.5 + // long duration
            (1.0 - features[4]) * 0.2; // asymmetry

    scores[RoadFeatureType.smooth] =
        (1.0 - math.min(features[0] / 0.5, 1.0)) * 0.5 + // low avg accel
            (1.0 - math.min(features[1] / 1.0, 1.0)) * 0.5; // low peak accel

    double totalScore = scores.values.reduce((a, b) => a + b);
    Map<RoadFeatureType, double> probabilities = {};

    if (totalScore > 0) {
      for (var type in RoadFeatureType.values) {
        probabilities[type] = scores[type]! / totalScore;
      }
    } else {

      for (var type in RoadFeatureType.values) {
        probabilities[type] = type == RoadFeatureType.smooth ? 1.0 : 0.0;
      }
    }

    RoadFeatureType bestType = RoadFeatureType.smooth;
    double bestScore = 0.0;

    for (var entry in scores.entries) {
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestType = entry.key;
      }
    }

    double confidence = probabilities[bestType] ?? 0.0;

    bool isDamaged = bestType != RoadFeatureType.smooth;

    return ClassificationResult(
      featureType: bestType,
      confidence: confidence,
      severity: severity,
      isDamaged: isDamaged,
      probabilities: probabilities,
    );
  }

  @override
  Future<void> train(List<TrainingExample> examples) async {
    if (examples.isEmpty) return;

    Map<RoadFeatureType, List<List<double>>> featuresByType = {};

    for (var type in RoadFeatureType.values) {
      featuresByType[type] = [];
    }

    for (var example in examples) {
      List<double> features = example.extractFeatures();
      featuresByType[example.featureType]!.add(features);
    }

    for (var type in RoadFeatureType.values) {
      if (type == RoadFeatureType.smooth || featuresByType[type]!.isEmpty) continue;

      double sum = 0.0;
      for (var features in featuresByType[type]!) {
        sum += features[1];
      }
      double avg = sum / featuresByType[type]!.length;

      _thresholds[type] = avg * 0.9;
    }
  }
}



abstract class LocationService {
  Future<CustomLocationData> getLocation();
}

CustomLocationData? _currentLocation;

void setCurrentLocation(CustomLocationData location) {
  _currentLocation = location;
}

typedef RoadFeatureEventCallback = void Function(RoadFeatureEvent event);

class DamageDetector extends ChangeNotifier {

  final AIService _aiService;
  final LocationService _locationService;

  MotionData? _latestAccelData;
  MotionData? _latestGyroData;
  final List<MotionData> _currentMotionBuffer = [];
  final int _bufferSize = 100;
  int _minEventSamplesRequired = 10;
  double _eventThreshold = 10.0;
  final int _eventTimeoutMs = 2000;
  final int _maxRecentDetections = 50;
  bool _isEventInProgress = false;
  DateTime? _eventStartTime;
  Timer? _eventTimeout;
  final List<ClassificationResult> _recentDetections = [];
  final List<TrainingExample> _trainingData = [];
  final _trainingDataKey = 'training_data_key';
  final FeatureExtractor _featureExtractor = SimpleFeatureExtractor();
  final Classifier _classifier = ThresholdClassifier();
  bool _useAI = true;
  bool _isDetecting = false;
  bool _isAIEnabled = true;
  bool _isMonitoring = false;
  List<Function(RoadFeatureEvent)> _roadFeatureEventListeners = [];
  CustomLocationData? _currentLocation;

  DamageDetector({
    required AIService aiService,
    required LocationService locationService,
  }) : _aiService = aiService,
        _locationService = locationService;

  int get trainingExampleCount => _trainingData.length;
  List<ClassificationResult> get recentDetections => List.unmodifiable(_recentDetections);
  List<TrainingExample> get trainingData => List.unmodifiable(_trainingData);
  bool get isEventInProgress => _isEventInProgress;
  DateTime? get eventStartTime => _eventStartTime;
  bool get isAIEnabled => _isAIEnabled;
  bool get isMonitoring => _isMonitoring;

  Future<void> initialize() async {
    await _loadTrainingData();
  }

  void startDetection() {
    _isDetecting = true;
    debugPrint('Road damage detection started');
    notifyListeners();
  }

  void stopDetection() {
    _isDetecting = false;
    debugPrint('Road damage detection stopped');
    notifyListeners();
  }

  void startMonitoring() {
    _isMonitoring = true;
    debugPrint('Motion monitoring started');
    notifyListeners();
  }

  void stopMonitoring() {
    _isMonitoring = false;
    debugPrint('Motion monitoring stopped');
    notifyListeners();
  }

  void setAIMode(bool enabled) {
    _isAIEnabled = enabled;
    debugPrint('AI mode set to: $enabled');
    notifyListeners();
  }

  void setCurrentLocation(CustomLocationData location) {
    _currentLocation = location;
  }

  void addRoadFeatureEventListener(Function(RoadFeatureEvent) listener) {
    _roadFeatureEventListeners.add(listener);
  }

  void removeRoadFeatureEventListener(Function(RoadFeatureEvent) listener) {
    _roadFeatureEventListeners.remove(listener);
  }

  void _notifyRoadDamageEvent(RoadFeatureEvent event) {
    for (var listener in _roadFeatureEventListeners) {
      listener(event);
    }
  }

  void updateAccelerometerData(MotionData data) {
    _latestAccelData = data;

    if (_latestGyroData != null) {
      final combinedData = MotionData(
        accelerationX: data.accelerationX,
        accelerationY: data.accelerationY,
        accelerationZ: data.accelerationZ,
        gyroX: _latestGyroData!.gyroX,
        gyroY: _latestGyroData!.gyroY,
        gyroZ: _latestGyroData!.gyroZ,
        timestamp: data.timestamp,
      );
      _processMotionData(combinedData);
    }
  }

  void updateGyroscopeData(MotionData data) {
    _latestGyroData = data;

    if (_latestAccelData != null) {
      final combinedData = MotionData(
        accelerationX: _latestAccelData!.accelerationX,
        accelerationY: _latestAccelData!.accelerationY,
        accelerationZ: _latestAccelData!.accelerationZ,
        gyroX: data.gyroX,
        gyroY: data.gyroY,
        gyroZ: data.gyroZ,
        timestamp: data.timestamp,
      );
      _processMotionData(combinedData);
    }
  }

  void _processMotionData(MotionData data) {
    _currentMotionBuffer.add(data);
    if (_currentMotionBuffer.length > _bufferSize) {
      _currentMotionBuffer.removeAt(0);
    }

    if (!_isEventInProgress && data.accelerationMagnitude > _eventThreshold) {
      _startEvent();
    }

    if (_isEventInProgress) {
      _resetEventTimeout();
    }
  }

  void updateThreshold(double threshold) {
    _eventThreshold = threshold;
    notifyListeners();
  }

  void toggleAIMode(bool enabled) {
    _useAI = enabled;
    notifyListeners();
  }

  ClassificationResult analyzeCurrentBuffer(LatLng position) {
    if (_currentMotionBuffer.length < _minEventSamplesRequired) {
      return _defaultSmoothResult();
    }

    List<double> features = _featureExtractor.extractFeatures(_currentMotionBuffer);


    return _defaultSmoothResult();
  }

  Future<ClassificationResult> analyzeCurrentBufferAsync() async {
    try {
      if (_currentMotionBuffer.length < _minEventSamplesRequired) {
        return _defaultSmoothResult();
      }

      List<double> features = _featureExtractor.extractFeatures(_currentMotionBuffer);

      return await _classifier.classify(features).timeout(
        Duration(milliseconds: 100),
        onTimeout: () => _defaultSmoothResult(),
      );
    } catch (e) {
      debugPrint('Error classifying road feature: $e');
      return _defaultSmoothResult();
    }
  }

  ClassificationResult _defaultSmoothResult() {
    return ClassificationResult(
      featureType: RoadFeatureType.smooth,
      confidence: 0.0,
      severity: 0.0,
      isDamaged: false,
      probabilities: {
        for (var type in RoadFeatureType.values)
          type: type == RoadFeatureType.smooth ? 1.0 : 0.0
      },
    );
  }

  void _startEvent() {
    _isEventInProgress = true;
    _eventStartTime = DateTime.now();
    _resetEventTimeout();
    notifyListeners();
  }

  void _resetEventTimeout() {
    _eventTimeout?.cancel();
    _eventTimeout = Timer(
      Duration(milliseconds: _eventTimeoutMs),
      _onEventTimeout,
    );
  }

  void _onEventTimeout() {
    if (!_isEventInProgress) return;
    _processEvent();
    _isEventInProgress = false;
    _eventStartTime = null;
    notifyListeners();
  }

  Future<void> _processEvent() async {
    if (_currentMotionBuffer.length < _minEventSamplesRequired) return;

    DateTime cutoffTime = DateTime.now().subtract(Duration(milliseconds: _eventTimeoutMs * 2));
    List<MotionData> eventData = _currentMotionBuffer
        .where((data) => data.timestamp.isAfter(cutoffTime))
        .toList();

    if (eventData.length < _minEventSamplesRequired) return;

    List<double> features = _featureExtractor.extractFeatures(eventData);
    ClassificationResult result = await _classifier.classify(features);

    if (result.confidence > 0.6) {
      _recentDetections.add(result);
      if (_recentDetections.length > _maxRecentDetections) {
        _recentDetections.removeAt(0);
      }


      if (_currentLocation != null) {
        final event = RoadFeatureEvent(
          type: result.featureType,
          latitude: _currentLocation!.latitude,
          longitude: _currentLocation!.longitude,
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );

        _notifyRoadDamageEvent(event);
      }
      notifyListeners();
    }
  }

  Future<void> addTrainingExample(RoadFeatureType featureType, LatLng location) async {
    if (_currentMotionBuffer.length < _minEventSamplesRequired) return;

    TrainingExample example = TrainingExample(
      motionSequence: List.from(_currentMotionBuffer),
      featureType: featureType,
      location: location,
    );

    _trainingData.add(example);
    await _classifier.train(_trainingData);
    await _saveTrainingData();
    notifyListeners();
  }

  Future<void> removeTrainingExample(int index) async {
    if (index < 0 || index >= _trainingData.length) return;

    _trainingData.removeAt(index);
    await _classifier.train(_trainingData);
    await _saveTrainingData();
    notifyListeners();
  }

  Future<void> clearTrainingData() async {
    _trainingData.clear();
    await _classifier.train(_trainingData);
    await _saveTrainingData();
    notifyListeners();
  }

  Future<void> _loadTrainingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? jsonData = prefs.getString(_trainingDataKey);

      if (jsonData != null) {
        List<dynamic> jsonList = jsonDecode(jsonData);
        _trainingData.clear();
        for (var json in jsonList) {
          _trainingData.add(TrainingExample.fromJson(json));
        }
        await _classifier.train(_trainingData);
      }
    } catch (e) {
      debugPrint('Error loading training data: $e');
    }
  }

  Future<void> _saveTrainingData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<Map<String, dynamic>> jsonList =
      _trainingData.map((example) => example.toJson()).toList();
      String jsonData = jsonEncode(jsonList);
      await prefs.setString(_trainingDataKey, jsonData);
    } catch (e) {
      debugPrint('Error saving training data: $e');
    }
  }

  Future<ClassificationResult> testClassify(List<MotionData> motionData) async {
    List<double> features = _featureExtractor.extractFeatures(motionData);
    return await _classifier.classify(features);
  }

  void updateTrainingExampleCount(int count) {
    _aiService.updateTrainingExampleCount(count);
    notifyListeners();
  }

  Future<Map<String, dynamic>> collectTrainingExample() async {
    if (_currentLocation == null) {
      await _locationService.getLocation().then((location) {
        _currentLocation = location;
      });
    }

    if (!_isMonitoring) {
      // Collect a brief sample of motion data
      await _startBriefSampling();
    }

    final features = await _aiService.getMotionFeatures();

    return features;
  }

  Future<void> _startBriefSampling() async {
    final wasMonitoring = _isMonitoring;

    if (!_isMonitoring) {
      startMonitoring();
    }

    await Future.delayed(const Duration(seconds: 2));


    if (!wasMonitoring) {
      stopMonitoring();
    }
  }


  Future<bool> trainModelWithData(List<Map<String, dynamic>> examples) async {
    try {

      final success = await _aiService.trainModel(examples);
      return success;
    } catch (e) {
      if (kDebugMode) {
        print('Error training model: $e');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>> exportTrainedModelData() async {
    try {

      final modelData = await _aiService.exportModelData();
      return modelData;
    } catch (e) {
      if (kDebugMode) {
        print('Error exporting model data: $e');
      }
      return {'error': 'Failed to export model data: ${e.toString()}'};
    }
  }

  Future<void> clearExistingTrainingData() async {
    try {
      await _aiService.clearTrainingData();
      await clearTrainingData(); // Clear local training data as well
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing training data: $e');
      }
    }
  }


  Future<CustomLocationData> getCurrentLocation() async {
    if (_currentLocation == null) {
      _currentLocation = await _locationService.getLocation();
    }
    return _currentLocation!;
  }


  bool hasEnoughDataForClassification() {
    return _currentMotionBuffer.length >= _minEventSamplesRequired;
  }

  // Force classification even without event trigger
  Future<RoadFeatureEvent?> forceClassification() async {
    if (!hasEnoughDataForClassification()) {
      return null;
    }

    ClassificationResult result = await analyzeCurrentBufferAsync();

    if (result.confidence > 0.4) {
      _recentDetections.add(result);
      if (_recentDetections.length > _maxRecentDetections) {
        _recentDetections.removeAt(0);
      }


      if (_currentLocation == null) {
        _currentLocation = await _locationService.getLocation();
      }

      final event = RoadFeatureEvent(
        type: result.featureType,
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      _notifyRoadDamageEvent(event);
      notifyListeners();
      return event;
    }

    return null;
  }


  Map<String, dynamic> getDetectionStatistics() {
    // Count detections by type
    Map<RoadFeatureType, int> countByType = {};
    for (var type in RoadFeatureType.values) {
      countByType[type] = 0;
    }

    for (var detection in _recentDetections) {
      countByType[detection.featureType] = (countByType[detection.featureType] ?? 0) + 1;
    }


    Map<RoadFeatureType, double> avgSeverityByType = {};
    Map<RoadFeatureType, List<double>> severitiesByType = {};

    for (var type in RoadFeatureType.values) {
      severitiesByType[type] = [];
    }

    for (var detection in _recentDetections) {
      severitiesByType[detection.featureType]!.add(detection.severity);
    }

    for (var type in RoadFeatureType.values) {
      if (severitiesByType[type]!.isEmpty) {
        avgSeverityByType[type] = 0.0;
      } else {
        double sum = severitiesByType[type]!.reduce((a, b) => a + b);
        avgSeverityByType[type] = sum / severitiesByType[type]!.length;
      }
    }

    return {
      'totalDetections': _recentDetections.length,
      'countByType': countByType,
      'avgSeverityByType': avgSeverityByType,
      'trainingExampleCount': _trainingData.length,
    };
  }


  void updateSettings({double? threshold, int? bufferSize, int? minSamples, int? eventTimeout}) {
    if (threshold != null) _eventThreshold = threshold;
    if (bufferSize != null && bufferSize > 0) {
      int oldSize = _bufferSize;
      int newSize = bufferSize;


      if (newSize < oldSize && _currentMotionBuffer.length > newSize) {

        _currentMotionBuffer.removeRange(0, _currentMotionBuffer.length - newSize);
      }
    }

    if (minSamples != null && minSamples > 0) {
      _minEventSamplesRequired = minSamples;
    }

    if (eventTimeout != null && eventTimeout > 0) {

      _eventTimeout?.cancel();
      _eventTimeout = Timer(
        Duration(milliseconds: eventTimeout),
        _onEventTimeout,
      );
    }

    notifyListeners();
  }

  void dispose() {
    _eventTimeout?.cancel();
    super.dispose();
  }
}