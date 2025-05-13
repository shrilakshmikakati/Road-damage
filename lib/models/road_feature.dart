import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'road_feature_type.dart';

class RoadFeature {
  final String id;
  final LatLng position;
  final RoadFeatureType type;
  final String description;
  final DateTime timestamp;

  RoadFeature({
    required this.id,
    required this.position,
    required this.type,
    required this.description,
    required this.timestamp,
  });

  // Convert to Map for storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'type': type.toString().split('.').last,
      'description': description,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  // Create from Map for retrieval
  factory RoadFeature.fromMap(Map<String, dynamic> map) {
    return RoadFeature(
      id: map['id'],
      position: LatLng(map['latitude'], map['longitude']),
      type: RoadFeatureTypeExtension.fromString(map['type']),
      description: map['description'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}