// lib/models/damage_record.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/road_feature_type.dart';

class DamageRecord {
  final String id;
  final LatLng position;
  final RoadFeatureType type;
  final int timestamp;
  final double severity;
  final Map<String, dynamic>? metadata;

  DamageRecord({
    required this.id,
    required this.position,
    required this.type,
    required this.timestamp,
    required this.severity,
    this.metadata,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'type': type.toString().split('.').last,
      'timestamp': timestamp,
      'severity': severity,
      'metadata': metadata,
    };
  }

  // Create from JSON
  factory DamageRecord.fromJson(Map<String, dynamic> json) {
    return DamageRecord(
      id: json['id'],
      position: LatLng(json['latitude'], json['longitude']),
      type: _typeFromString(json['type']),
      timestamp: json['timestamp'],
      severity: json['severity'],
      metadata: json['metadata'],
    );
  }

  // Helper to convert string to RoadFeatureType
  static RoadFeatureType _typeFromString(String typeStr) {
    switch (typeStr) {
      case 'pothole':
        return RoadFeatureType.pothole;
      case 'speedBreaker':
        return RoadFeatureType.speedBreaker;
      case 'roughPatch':
        return RoadFeatureType.roughPatch;
      case 'railwayCrossing':
        return RoadFeatureType.railwayCrossing;
      case 'smooth':
        return RoadFeatureType.smooth;
      default:
        return RoadFeatureType.pothole;
    }
  }
}