// lib/services/cloud_sync_service.dart
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/damage_record.dart';

class CloudSyncService {
  static const String _userIdKey = 'user_id';
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  String? _userId;

  Future<void> initialize() async {
    await _getUserId();
  }

  Future<void> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString(_userIdKey);

    if (userId == null) {

      userId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString(_userIdKey, userId);
    }

    _userId = userId;
  }

  Future<bool> uploadRecord(DamageRecord record) async {
    if (_userId == null) {
      await _getUserId();
    }

    try {
      await _database.child('records').child(_userId!).child(record.id).set(record.toJson());
      return true;
    } catch (e) {
      print('Error uploading record: $e');
      return false;
    }
  }

  Future<bool> uploadAllRecords(List<DamageRecord> records) async {
    if (_userId == null) {
      await _getUserId();
    }

    try {
      final Map<String, dynamic> updates = {};

      for (var record in records) {
        updates['/records/${_userId!}/${record.id}'] = record.toJson();
      }

      await _database.update(updates);
      return true;
    } catch (e) {
      print('Error uploading records: $e');
      return false;
    }
  }

  Future<List<DamageRecord>> downloadRecords() async {
    if (_userId == null) {
      await _getUserId();
    }

    final List<DamageRecord> records = [];

    try {
      final DataSnapshot snapshot = await _database.child('records').child(_userId!).get();

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

        data.forEach((key, value) {
          records.add(DamageRecord.fromJson(Map<String, dynamic>.from(value)));
        });
      }

      return records;
    } catch (e) {
      print('Error downloading records: $e');
      return [];
    }
  }

  Future<bool> deleteAllRecords() async {
    if (_userId == null) {
      await _getUserId();
    }

    try {
      await _database.child('records').child(_userId!).remove();
      return true;
    } catch (e) {
      print('Error deleting records: $e');
      return false;
    }
  }
}