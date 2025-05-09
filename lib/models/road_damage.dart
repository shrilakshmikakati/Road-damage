// lib/models/road_damage.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'road_feature_type.dart';

class RoadDamage {
  final String? id;
  final RoadFeatureType type;
  final LatLng position;
  final double severity;
  final Timestamp? timestamp;
  final String? description;
  final bool? verified;

  RoadDamage({
    this.id,
    required this.type,
    required this.position,
    required this.severity,
    this.timestamp,
    this.description,
    this.verified,
  });


  factory RoadDamage.fromMap(Map<String, dynamic> map, String documentId) {
    return RoadDamage(
      id: documentId,
      type: RoadFeatureTypeExtension.fromString(map['type'] as String),
      position: LatLng(
        map['latitude'] as double,
        map['longitude'] as double,
      ),
      severity: map['severity'] as double,
      timestamp: map['timestamp'] as Timestamp,
      description: map['description'] as String?,
      verified: map['verified'] as bool?,
    );
  }


  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'severity': severity,
      'timestamp': timestamp ?? Timestamp.now(),
      'description': description ?? '',
      'verified': verified ?? false,
    };
  }
}

