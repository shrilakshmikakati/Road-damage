import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/road_damage.dart';
import '../models/road_feature_type.dart'; // Added import for RoadFeatureType

class FirebaseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;


  final CollectionReference _roadDamageCollection =
  FirebaseFirestore.instance.collection('road_damages');


  Future<void> initialize() async {

    await _ensureUserLoggedIn();
  }

  Future<void> _ensureUserLoggedIn() async {
    if (_auth.currentUser == null) {

      await _auth.signInAnonymously();
    }
  }


  Future<bool> uploadRoadDamage(List<RoadDamage> damages) async {
    try {
      await _ensureUserLoggedIn();

      String? userId = _auth.currentUser?.uid;
      if (userId == null || userId.isEmpty) {
        print('Error: No user logged in');
        return false;
      }

      WriteBatch batch = _firestore.batch();


      for (RoadDamage damage in damages) {

        DocumentReference docRef = _roadDamageCollection.doc();


        Map<String, dynamic> data = {
          'userId': userId,
          'type': damage.type.toString().split('.').last,
          'latitude': damage.position.latitude,
          'longitude': damage.position.longitude,
          'severity': damage.severity,
          'timestamp': damage.timestamp ?? Timestamp.now(),
          'description': damage.description ?? '',
          'verified': damage.verified ?? false,
        };

        batch.set(docRef, data);
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error uploading road damage data: $e');
      return false;
    }
  }

  Future<List<RoadDamage>> downloadRoadDamage() async {
    try {
      await _ensureUserLoggedIn();


      QuerySnapshot snapshot = await _roadDamageCollection
          .orderBy('timestamp', descending: true)
          .get();

      List<RoadDamage> damages = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        RoadFeatureType type = _parseRoadFeatureType(data['type'] as String);

        LatLng position = LatLng(
            data['latitude'] as double,
            data['longitude'] as double
        );


        return RoadDamage(
          id: doc.id,
          type: type,
          position: position,
          severity: data['severity'] as double,
          timestamp: data['timestamp'] as Timestamp,
          description: data['description'] as String?,
          verified: data['verified'] as bool?,
        );
      }).toList();

      return damages;
    } catch (e) {
      print('Error downloading road damage data: $e');
      return [];
    }
  }

  RoadFeatureType _parseRoadFeatureType(String typeString) {
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
      default:
        return RoadFeatureType.pothole; // Default value
    }
  }


  Future<bool> clearUserData() async {
    try {

      await _ensureUserLoggedIn();

      String? userId = _auth.currentUser?.uid;
      if (userId == null || userId.isEmpty) {
        print('Error: No user logged in');
        return false;
      }

      QuerySnapshot snapshot = await _roadDamageCollection
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isEmpty) {
        print('No documents found to delete');
        return true;
      }

      WriteBatch batch = _firestore.batch();
      for (DocumentSnapshot doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      return true;
    } catch (e) {
      print('Error clearing user data: $e');
      return false;
    }
  }
}