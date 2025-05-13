import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/road_damage.dart';
import '../models/damage_type.dart';
import '../models/damage_severity.dart';

class FirebaseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'road_damages';

  // Add a road damage report to Firestore
  Future<void> addRoadDamage(RoadDamage damage) async {
    await _firestore.collection(_collection).doc(damage.id).set(damage.toMap());
  }

  // Get all road damages from Firestore
  Future<List<RoadDamage>> getRoadDamages() async {
    final snapshot = await _firestore.collection(_collection).get();
    return snapshot.docs.map((doc) => RoadDamage.fromMap(doc.data())).toList();
  }

  // Get road damages near a location
  Future<List<RoadDamage>> getNearbyDamages(LatLng location, double radiusKm) async {
    // This is a simplified approach - for production, use geohashing or Firestore's GeoPoint
    final snapshot = await _firestore.collection(_collection).get();

    return snapshot.docs
        .map((doc) => RoadDamage.fromMap(doc.data()))
        .where((damage) {
      final distance = _calculateDistance(
          location.latitude,
          location.longitude,
          damage.position.latitude,
          damage.position.longitude
      );
      return distance <= radiusKm;
    })
        .toList();
  }

  // Update verification status
  Future<void> updateVerificationStatus(String damageId, bool isVerified) async {
    await _firestore.collection(_collection).doc(damageId).update({
      'verified': isVerified,
    });
  }

  // Delete a road damage report
  Future<void> deleteRoadDamage(String damageId) async {
    await _firestore.collection(_collection).doc(damageId).delete();
  }

  // Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Implementation of distance calculation
    // For simplicity, this is a placeholder
    return 0.0; // Replace with actual implementation
  }
}