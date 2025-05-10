import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

enum RoadFeatureType {
  pothole,        // A hole in the road surface
  roughPatch,     // A rough or uneven section of road
  speedBreaker,   // An intentional bump/speed bump
  railwayCrossing, // A railway crossing
  smooth
}

class RoadFeature {
  final String id;
  final RoadFeatureType type;
  final double latitude;
  final double longitude;
  final double severity;
  final DateTime timestamp;
  final String? imageUrl;
  final String? notes;
  final bool isVerified;

  RoadFeature({
    String? id,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.severity,
    DateTime? timestamp,
    this.imageUrl,
    this.notes,
    this.isVerified = false,
  }) :
        this.id = id ?? const Uuid().v4(),
        this.timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'latitude': latitude,
      'longitude': longitude,
      'severity': severity,
      'timestamp': Timestamp.fromDate(timestamp),
      'imageUrl': imageUrl,
      'notes': notes,
      'isVerified': isVerified,
    };
  }

  factory RoadFeature.fromMap(Map<String, dynamic> map) {
    return RoadFeature(
      id: map['id'],
      type: RoadFeatureType.values.firstWhere(
            (e) => e.toString().split('.').last == map['type'],
        orElse: () => RoadFeatureType.smooth,
      ),
      latitude: map['latitude'],
      longitude: map['longitude'],
      severity: map['severity'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      imageUrl: map['imageUrl'],
      notes: map['notes'],
      isVerified: map['isVerified'] ?? false,
    );
  }
}