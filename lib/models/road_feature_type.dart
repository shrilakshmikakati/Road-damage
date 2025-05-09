// lib/models/road_feature_type.dart

/// Enum representing different types of road features that can be detected
enum RoadFeatureType {
  pothole,        // A hole in the road surface
  roughPatch,     // A rough or uneven section of road
  speedBreaker,   // An intentional bump/speed bump
  railwayCrossing, // A railway crossing
  smooth          // Normal, smooth road conditions
}


extension RoadFeatureTypeExtension on RoadFeatureType {

  static RoadFeatureType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pothole':
        return RoadFeatureType.pothole;
      case 'roughpatch':
        return RoadFeatureType.roughPatch;
      case 'speedbreaker':
        return RoadFeatureType.speedBreaker;
      case 'railwaycrossing':
        return RoadFeatureType.railwayCrossing;
      case 'smooth':
      default:
        return RoadFeatureType.smooth;
    }
  }

  String get displayName {
    switch (this) {
      case RoadFeatureType.pothole:
        return 'Pothole';
      case RoadFeatureType.roughPatch:
        return 'Rough Patch';
      case RoadFeatureType.speedBreaker:
        return 'Speed Breaker';
      case RoadFeatureType.railwayCrossing:
        return 'Railway Crossing';
      case RoadFeatureType.smooth:
        return 'Smooth Road';
    }
  }


  bool get isDamage {
    return this == RoadFeatureType.pothole || this == RoadFeatureType.roughPatch;
  }


  int get color {
    switch (this) {
      case RoadFeatureType.pothole:
        return 0xFFFF0000; // Red
      case RoadFeatureType.roughPatch:
        return 0xFFFFA500; // Orange
      case RoadFeatureType.speedBreaker:
        return 0xFFFFFF00; // Yellow
      case RoadFeatureType.railwayCrossing:
        return 0xFF800080; // Purple
      case RoadFeatureType.smooth:
        return 0xFF00FF00; // Green
    }
  }
}