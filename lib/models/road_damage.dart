import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'damage_type.dart';
import 'damage_severity.dart';

class RoadDamage {
  final String id;
  final LatLng position;
  final DamageType damageType;
  final String description;
  final DateTime timestamp;
  final DamageSeverity severity;
  final bool verified;
  final double confidenceScore;

  // Add these getters to fix the errors
  DamageType get type => damageType;

  RoadDamage({
    required this.id,
    required this.position,
    required this.damageType,
    required this.description,
    required this.timestamp,
    this.severity = DamageSeverity.medium,
    this.verified = false,
    this.confidenceScore = 1.0,
  });

  // Add location getter to support legacy code
  LatLng get location => position;

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'damageType': damageType.toString().split('.').last,
      'description': description,
      'timestamp': Timestamp.fromDate(timestamp),
      'severity': severity.toString().split('.').last,
      'verified': verified,
      'confidenceScore': confidenceScore,
    };
  }
  // Convert RoadDamage object to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'damageType': damageType.toString().split('.').last,
      'description': description,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'severity': severity.toString().split('.').last,
      'verified': verified,
      'confidenceScore': confidenceScore,
    };
  }

// Create RoadDamage object from JSON
  static RoadDamage fromJson(Map<String, dynamic> json) {
    return RoadDamage(
      id: json['id'] ?? '',
      position: LatLng(
          json['latitude'] ?? 0.0,
          json['longitude'] ?? 0.0
      ),
      damageType: _getDamageTypeFromString(json['damageType'] ?? 'pothole'),
      description: json['description'] ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch),
      severity: _getSeverityFromString(json['severity'] ?? 'medium'),
      verified: json['verified'] ?? false,
      confidenceScore: (json['confidenceScore'] ?? 1.0).toDouble(),
    );
  }
  // Create from Map for retrieval
  factory RoadDamage.fromMap(Map<String, dynamic> map) {
    return RoadDamage(
      id: map['id'] ?? '',
      position: LatLng(
          map['latitude'] ?? 0.0,
          map['longitude'] ?? 0.0
      ),
      damageType: _getDamageTypeFromString(map['damageType'] ?? 'pothole'),
      description: map['description'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      severity: _getSeverityFromString(map['severity'] ?? 'medium'),
      verified: map['verified'] ?? false,
      confidenceScore: (map['confidenceScore'] ?? 1.0).toDouble(),
    );
  }

  static DamageType _getDamageTypeFromString(String typeString) {
    switch (typeString) {
      case 'pothole':
        return DamageType.pothole;
      case 'crack':
        return DamageType.crack;
      case 'roughPatch':
        return DamageType.roughPatch;
      case 'speedBreaker':
        return DamageType.speedBreaker;
      case 'railwayCrossing':
        return DamageType.railwayCrossing;
      case 'smooth':
        return DamageType.smooth;
      case 'bump':
        return DamageType.bump;
      default:
        return DamageType.other;
    }
  }

  static DamageSeverity _getSeverityFromString(String severityString) {
    switch (severityString) {
      case 'low':
        return DamageSeverity.low;
      case 'medium':
        return DamageSeverity.medium;
      case 'high':
        return DamageSeverity.high;
      case 'critical':
        return DamageSeverity.critical;
      default:
        return DamageSeverity.medium;
    }
  }
}