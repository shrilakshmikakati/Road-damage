import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/road_damage.dart';
import '../models/road_feature_type.dart'; // Added import for RoadFeatureType

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
      String? userId = _auth.currentUser?.uid;
      if (userId == null || userId.isEmpty) {
        print('Error: No user logged in');
        return false;
      }

      // Use a batch write for better performance with multiple writes
      WriteBatch batch = _firestore.batch();

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

        // Add to batch
        batch.set(docRef, data);
      }

      // Commit the batch
      await batch.commit();
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
      String? userId = _auth.currentUser?.uid;
      if (userId == null || userId.isEmpty) {
        print('Error: No user logged in');
        return false;
      }

      // Query all documents belonging to this user
      QuerySnapshot snapshot = await _roadDamageCollection
          .where('userId', isEqualTo: userId)
          .get();

      // Check if there are documents to delete
      if (snapshot.docs.isEmpty) {
        print('No documents found to delete');
        return true;
      }

      // Use a batch delete for better performance
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

// Consider replacing this with RoadFeatureTypeExtension.fromString from your extension
// Or you can leave this method and make it use the extension internally
/*
  RoadFeatureType _parseRoadFeatureType(String typeString) {
    return RoadFeatureTypeExtension.fromString(typeString);
  }
  */
}