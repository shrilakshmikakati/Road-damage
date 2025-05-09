// lib/services/ai_service.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/road_feature_type.dart';
import '../utils/damage_detector.dart';


abstract class AIService {

  Future<void> init();


  Future<Map<String, dynamic>> analyze(List<MotionData> motionData);

  Future<Map<String, dynamic>> detect(List<MotionData> motionData);

  void addMotionData(MotionData data);

  Future<void> train(RoadFeatureType featureType, List<MotionData> motionData);

  Future<void> addTrainingExample(RoadFeatureType type, LatLng position);

  Future<void> saveEvent(RoadFeatureEvent event);


  Future<Map<String, dynamic>> getModelStatus();

  Future<Map<String, dynamic>> getMotionFeatures();


  void updateTrainingExampleCount(int count);


  Future<bool> trainModel(List<Map<String, dynamic>> examples);

  Future<Map<String, dynamic>> exportModelData();


  Future<void> clearTrainingData();


  int get trainingExampleCount;


  bool get isModelTrained;


  Stream<AnalysisResult> get analysisStream;
}

class AnalysisResult {
  final double severity;
  final bool isDamaged;
  final RoadFeatureType featureType;
  final double? confidence;
  final Map<RoadFeatureType, double>? probabilities;
  final LatLng position;

  AnalysisResult({
    required this.severity,
    required this.isDamaged,
    required this.featureType,
    required this.position,
    this.confidence,
    this.probabilities,
  });
}