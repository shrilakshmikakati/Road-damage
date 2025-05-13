enum DamageType {
  pothole,
  crack,
  roughPatch,
  speedBreaker,
  railwayCrossing,
  smooth,
  bump,
  other
}

// Add this extension to provide the displayName getter
extension DamageTypeExtension on DamageType {
  String get displayName {
    switch (this) {
      case DamageType.pothole:
        return 'Pothole';
      case DamageType.crack:
        return 'Crack';
      case DamageType.roughPatch:
        return 'Rough Patch';
      case DamageType.speedBreaker:
        return 'Speed Breaker';
      case DamageType.railwayCrossing:
        return 'Railway Crossing';
      case DamageType.smooth:
        return 'Smooth Road';
      case DamageType.bump:
        return 'Speed Bump';
      case DamageType.other:
        return 'Other';
    }
  }
}