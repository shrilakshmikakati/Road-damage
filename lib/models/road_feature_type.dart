enum RoadFeatureType {
  pothole,
  roughPatch,
  speedBreaker,
  railwayCrossing,
  smooth,
  bump,
  smoothRoad,
}

// Extension to add display names
extension RoadFeatureTypeExtension on RoadFeatureType {
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
      case RoadFeatureType.bump:
        return 'Speed Bump';
      case RoadFeatureType.smoothRoad:
        return 'Smooth Road';
    }
  }

  int get defaultSeverity {
    switch (this) {
      case RoadFeatureType.pothole:
        return 3;
      case RoadFeatureType.roughPatch:
        return 2;
      case RoadFeatureType.speedBreaker:
        return 1;
      case RoadFeatureType.railwayCrossing:
        return 1;
      case RoadFeatureType.smooth:
        return 0;
      case RoadFeatureType.bump:
        return 2;
      case RoadFeatureType.smoothRoad:
        return 0;
    }
  }

  static RoadFeatureType fromString(String typeString) {
    switch (typeString) {
      case 'pothole':
        return RoadFeatureType.pothole;
      case 'roughPatch':
        return RoadFeatureType.roughPatch;
      case 'speedBreaker':
        return RoadFeatureType.speedBreaker;
      case 'railwayCrossing':
        return RoadFeatureType.railwayCrossing;
      case 'smooth':
        return RoadFeatureType.smooth;
      case 'bump':
        return RoadFeatureType.bump;
      case 'smoothRoad':
        return RoadFeatureType.smoothRoad;
      default:
        return RoadFeatureType.pothole;
    }
  }
}

// Add this extension to provide the severity getter
extension RoadFeatureTypeSeverity on RoadFeatureType {
  double get severity {
    switch (this) {
      case RoadFeatureType.pothole:
        return 5.0;
      case RoadFeatureType.roughPatch:
        return 3.0;
      case RoadFeatureType.speedBreaker:
        return 2.0;
      case RoadFeatureType.railwayCrossing:
        return 2.5;
      case RoadFeatureType.smooth:
        return 0.0;
      case RoadFeatureType.bump:
        return 3.0;
      case RoadFeatureType.smoothRoad:
        return 0.0;
    }
  }
}