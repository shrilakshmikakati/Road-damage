import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/road_feature.dart';
import '../utils/connectivity_helper.dart';
import '../services/cloud_service.dart';
import '../models/damage_record.dart';

class DamageRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ConnectivityHelper _connectivityHelper = ConnectivityHelper();
  final CloudService _cloudService = CloudService();
  final String _storageKey = 'road_features';
  final String _damageRecordsKey = 'damage_records'; // Separate key for damage records
  bool _initialized = false;

  Future<void> initialize() async {
    if (!_initialized) {
      // Ensure Firebase is ready
      _initialized = true;
    }
  }

  // Save a road feature to local storage and optionally to Firebase
  Future<bool> saveRoadFeature(RoadFeature feature, {bool syncToCloud = false}) async {
    try {
      // Save to local storage first
      final features = await getLocalRoadFeatures();
      features.add(feature);
      await _saveLocalRoadFeatures(features);

      // If cloud sync is enabled and we have connectivity, save to Firebase
      if (syncToCloud && await _connectivityHelper.isConnected()) {
        await _saveToFirebase(feature);
      }

      return true;
    } catch (e) {
      print('Error saving road feature: $e');
      return false;
    }
  }

  // Save road features to local storage
  Future<void> _saveLocalRoadFeatures(List<RoadFeature> features) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = features.map((feature) => jsonEncode(feature.toMap())).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }

  // Save a road feature to Firebase
  Future<void> _saveToFirebase(RoadFeature feature) async {
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
      print('Error saving to Firebase: $e');
      throw e;
    }
  }

  // Sync local data with Firebase (upload or download)
  Future<bool> syncWithCloud(bool isUpload) async {
    try {
      if (!await _connectivityHelper.isConnected()) {
        throw Exception('No internet connection');
      }

      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      if (isUpload) {
        // Upload local data to Firebase
        final localFeatures = await getLocalRoadFeatures();
        for (final feature in localFeatures) {
          await _saveToFirebase(feature);
        }
      } else {
        // Download data from Firebase
        final snapshot = await _firestore
            .collection('users')
            .doc(userId)
            .collection('road_features')
            .get();

        if (snapshot.docs.isEmpty) {
          return false; // No data to download
        }

        List<RoadFeature> features = [];
        for (final doc in snapshot.docs) {
          final feature = RoadFeature.fromMap(doc.data());
          features.add(feature);
        }

        // Save all downloaded features to local storage
        await _saveLocalRoadFeatures(features);
      }

      return true;
    } catch (e) {
      print('Error syncing with cloud: $e');
      throw e;
    }
  }

  // Add a single damage record
  Future<void> addRecord(DamageRecord record, {bool syncToCloud = false}) async {
    await initialize();
    final records = await getRecords();
    records.add(record);
    await saveRecords(records, syncToCloud: syncToCloud);

    // If cloud sync is enabled, sync this single record
    if (syncToCloud) {
      // Convert DamageRecord to RoadFeature for cloud service
      final roadFeature = convertDamageRecordToRoadFeature(record);
      await _saveToFirebase(roadFeature);
    }
  }

  // Convert DamageRecord to RoadFeature
  RoadFeature convertDamageRecordToRoadFeature(DamageRecord record) {
    return RoadFeature(
      id: record.id,
      latitude: record.position.latitude,
      longitude: record.position.longitude,
      type: record.isDamaged ? RoadFeatureType.pothole : RoadFeatureType.smooth,
      severity: record.severity,
      timestamp: record.timestamp,
    );
  }

  // Save damage records
  Future<void> saveRecords(List<DamageRecord> records, {bool syncToCloud = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = records.map((record) => jsonEncode(record.toJson())).toList();
    await prefs.setStringList(_damageRecordsKey, jsonList);

    // Sync to cloud if enabled
    if (syncToCloud) {
      for (var record in records) {
        final roadFeature = convertDamageRecordToRoadFeature(record);
        await _saveToFirebase(roadFeature);
      }
    }
  }

  // Get all damage records
  Future<List<DamageRecord>> getRecords() async {
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_damageRecordsKey) ?? [];

    return jsonList
        .map((jsonString) => DamageRecord.fromJson(jsonDecode(jsonString)))
        .toList();
  }

  // Get all road features from local storage
  Future<List<RoadFeature>> getLocalRoadFeatures() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];

    return jsonList
        .map((jsonString) => RoadFeature.fromMap(jsonDecode(jsonString)))
        .toList();
  }

  // Clear all records from local storage and optionally from Firebase
  Future<void> clearRecords({bool syncToCloud = false}) async {
    try {
      // Clear local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_damageRecordsKey);

      // If cloud sync is enabled, clear Firebase data too
      if (syncToCloud) {
        final userId = _auth.currentUser?.uid;
        if (userId != null) {
          final batch = _firestore.batch();
          final snapshot = await _firestore
              .collection('users')
              .doc(userId)
              .collection('road_features')
              .get();

          for (final doc in snapshot.docs) {
            batch.delete(doc.reference);
          }

          await batch.commit();
        }
      }
    } catch (e) {
      print('Error clearing records: $e');
      throw e;
    }
  }
}