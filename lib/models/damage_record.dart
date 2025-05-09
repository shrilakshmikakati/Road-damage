// lib/models/damage_record.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';

class DamageRecord {
  final String id;
  final LatLng position;
  final DateTime timestamp;
  final double severity;
  final bool isDamaged;

  DamageRecord({
    required this.id,
    required this.position,
    required this.timestamp,
    required this.severity,
    required this.isDamaged,
  });


  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lat': position.latitude,
      'lng': position.longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'severity': severity,
      'isDamaged': isDamaged,
    };
  }

  factory DamageRecord.fromJson(Map<String, dynamic> json) {
    return DamageRecord(
      id: json['id'],
      position: LatLng(json['lat'], json['lng']),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      severity: json['severity'],
      isDamaged: json['isDamaged'],
    );
  }
}