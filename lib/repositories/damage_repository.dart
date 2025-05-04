// lib/repositories/damage_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/damage_record.dart';
import '../services/cloud_sync_service.dart';


class DamageRepository {
  static const String _storageKey = 'damage_records';
  final CloudSyncService _cloudService = CloudSyncService();
  bool _isInitialized = false;

  // Initialize the repository
  Future<void> initialize() async {
    if (!_isInitialized) {
      await _cloudService.initialize();
      _isInitialized = true;
    }
  }

  // Save damage records
  Future<void> saveRecords(List<DamageRecord> records, {bool syncToCloud = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = records.map((record) => jsonEncode(record.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonList);

    // Sync to cloud if enabled
    if (syncToCloud) {
      await _cloudService.uploadAllRecords(records);
    }
  }

  // Add a single record
  Future<void> addRecord(DamageRecord record, {bool syncToCloud = false}) async {
    await initialize();
    final records = await getRecords();
    records.add(record);
    await saveRecords(records, syncToCloud: syncToCloud);

    // If cloud sync is enabled, sync this single record
    if (syncToCloud) {
      await _cloudService.uploadRecord(record);
    }
  }

  // Get all records
  Future<List<DamageRecord>> getRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];

    return jsonList
        .map((str) => DamageRecord.fromJson(jsonDecode(str)))
        .toList();
  }

  // Clear all records
  Future<void> clearRecords({bool syncToCloud = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);

    // Also clear cloud data if sync is enabled
    if (syncToCloud) {
      await _cloudService.deleteAllRecords();
    }
  }

  // Sync with cloud
  Future<bool> syncWithCloud(bool upload) async {
    await initialize();

    if (upload) {
      // Upload local records to cloud
      final records = await getRecords();
      return await _cloudService.uploadAllRecords(records);
    } else {
      // Download records from cloud
      final cloudRecords = await _cloudService.downloadRecords();
      if (cloudRecords.isNotEmpty) {
        // Merge with local records
        final localRecords = await getRecords();

        // Create a map for easy lookup
        final Map<String, DamageRecord> recordMap = {};
        for (var record in localRecords) {
          recordMap[record.id] = record;
        }

        // Add cloud records that don't exist locally
        for (var record in cloudRecords) {
          if (!recordMap.containsKey(record.id)) {
            recordMap[record.id] = record;
          }
        }

        // Save the merged records
        await saveRecords(recordMap.values.toList());
        return true;
      }
      return false;
    }
  }
}