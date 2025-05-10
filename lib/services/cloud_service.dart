import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/road_feature.dart';

class CloudService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> uploadRecord(RoadFeature feature) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _firestore
          .collection('users')
          .doc(userId)
          .collection('road_features')
          .doc(feature.id)
          .set(feature.toMap());
    } catch (e) {
      print('Error uploading record to cloud: $e');
      throw e;
    }
  }
}