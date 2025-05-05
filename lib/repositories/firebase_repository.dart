// lib/repositories/firebase_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/road_damage.dart';

class FirebaseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  final CollectionReference _roadDamageCollection =
  FirebaseFirestore.instance.collection('road_damages');

  // Initialize Firebase
  Future<void> initialize() async {
    // Any initialization code if needed
    // This might include checking if the user is logged in
    await _ensureUserLoggedIn();
  }

  // Ensure user is logged in (anonymously if needed)
  Future<void> _ensureUserLoggedIn() async {
    if (_auth.currentUser == null) {
      // Sign in anonymously if no user is logged in
      await _auth.signInAnonymously();
    }
  }

  // Upload road damage data to Firestore
  Future<bool> uploadRoadDamage(List<RoadDamage> damages) async {
    try {
      // Ensure user is logged in
      await _ensureUserLoggedIn();

      // Get current user ID
      String userId = _auth.currentUser!.uid;

      // Upload each damage record
      for (RoadDamage damage in damages) {
        // Create a document reference with an auto-generated ID
        DocumentReference docRef = _roadDamageCollection.doc();

        // Prepare the data
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

        // Set the data in Firestore
        await docRef.set(data);
      }

      return true;
    } catch (e) {
      print('Error uploading road damage data: $e');
      return false;
    }
  }

  // Download road damage data from Firestore
  Future<List<RoadDamage>> downloadRoadDamage() async {
    try {
      // Ensure user is logged in
      await _ensureUserLoggedIn();

      // Query all documents in the road_damages collection
      // Could be filtered by location/time/etc. depending on requirements
      QuerySnapshot snapshot = await _roadDamageCollection
          .orderBy('timestamp', descending: true)
          .get();

      // Convert the query snapshot to a list of RoadDamage objects
      List<RoadDamage> damages = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        // Parse the type from string to enum
        RoadFeatureType type = _parseRoadFeatureType(data['type'] as String);

        // Create the LatLng object
        LatLng position = LatLng(
            data['latitude'] as double,
            data['longitude'] as double
        );

        // Create and return the RoadDamage object
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

  // Helper method to parse string to enum
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

  // Delete all road damage data for a user
  Future<bool> clearUserData() async {
    try {
      // Ensure user is logged in
      await _ensureUserLoggedIn();

      // Get current user ID
      String userId = _auth.currentUser!.uid;

      // Query all documents belonging to this user
      QuerySnapshot snapshot = await _roadDamageCollection
          .where('userId', isEqualTo: userId)
          .get();

      // Delete each document
      for (DocumentSnapshot doc in snapshot.docs) {
        await doc.reference.delete();
      }

      return true;
    } catch (e) {
      print('Error clearing user data: $e');
      return false;
    }
  }
}

