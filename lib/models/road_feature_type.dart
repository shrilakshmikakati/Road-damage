enum RoadFeatureType {
  pothole,
  roughPatch,
  speedBreaker,
  railwayCrossing,
  smooth,
}

// Extension methods for RoadFeatureType
extension RoadFeatureTypeExtension on RoadFeatureType {
  // Display name for UI
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

  // Description for UI
  String get description {
    switch (this) {
      case RoadFeatureType.pothole:
        return 'Deep holes in the road';
      case RoadFeatureType.roughPatch:
        return 'Uneven road surface';
      case RoadFeatureType.speedBreaker:
        return 'Intentional bumps to slow traffic';
      case RoadFeatureType.railwayCrossing:
        return 'Train tracks crossing road';
      case RoadFeatureType.smooth:
        return 'Well maintained road surface';
    }
  }

  // Icon for UI
  IconData get icon {
    switch (this) {
      case RoadFeatureType.pothole:
        return Icons.warning;
      case RoadFeatureType.roughPatch:
        return Icons.waves;
      case RoadFeatureType.speedBreaker:
        return Icons.speed;
      case RoadFeatureType.railwayCrossing:
        return Icons.train;
      case RoadFeatureType.smooth:
        return Icons.check_circle;
    }
  }

  // Whether this road feature is considered damage
  bool get isDamage {
    return this == RoadFeatureType.pothole ||
        this == RoadFeatureType.roughPatch;
  }

  // Parse from string safely
  static RoadFeatureType fromString(String value) {
    try {
      return RoadFeatureType.values.firstWhere(
            (type) => type.toString().split('.').last == value,
        orElse: () => RoadFeatureType.smooth,
      );
    } catch (_) {
      return RoadFeatureType.smooth;
    }
  }
}