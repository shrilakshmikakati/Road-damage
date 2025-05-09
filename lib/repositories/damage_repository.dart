// lib/repositories/damage_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/damage_record.dart';
import '../services/cloud_sync_service.dart';


class DamageRepository {
  static const String _storageKey = 'damage_records';
  final CloudSyncService _cloudService = CloudSyncService();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (!_isInitialized) {
      await _cloudService.initialize();
      _isInitialized = true;
    }
  }

  Future<void> saveRecords(List<DamageRecord> records, {bool syncToCloud = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = records.map((record) => jsonEncode(record.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonList);

    if (syncToCloud) {
      await _cloudService.uploadAllRecords(records);
    }
  }

  Future<void> addRecord(DamageRecord record, {bool syncToCloud = false}) async {
    await initialize();
    final records = await getRecords();
    records.add(record);
    await saveRecords(records, syncToCloud: syncToCloud);

    if (syncToCloud) {
      await _cloudService.uploadRecord(record);
    }
  }

  Future<List<DamageRecord>> getRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];

    return jsonList
        .map((str) => DamageRecord.fromJson(jsonDecode(str)))
        .toList();
  }

  Future<void> clearRecords({bool syncToCloud = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);


    if (syncToCloud) {
      await _cloudService.deleteAllRecords();
    }
  }

  Future<bool> syncWithCloud(bool upload) async {
    await initialize();

    if (upload) {

      final records = await getRecords();
      return await _cloudService.uploadAllRecords(records);
    } else {

      final cloudRecords = await _cloudService.downloadRecords();
      if (cloudRecords.isNotEmpty) {

        final localRecords = await getRecords();


        final Map<String, DamageRecord> recordMap = {};
        for (var record in localRecords) {
          recordMap[record.id] = record;
        }


        for (var record in cloudRecords) {
          if (!recordMap.containsKey(record.id)) {
            recordMap[record.id] = record;
          }
        }


        await saveRecords(recordMap.values.toList());
        return true;
      }
      return false;
    }
  }
}