// lib/repositories/damage_repository.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/damage_record.dart';

class DamageRepository {
  static const String _storageKey = 'damage_records';

  // Save damage records
  Future<void> saveRecords(List<DamageRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = records.map((record) => jsonEncode(record.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }

  // Add a single record
  Future<void> addRecord(DamageRecord record) async {
    final records = await getRecords();
    records.add(record);
    await saveRecords(records);
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
  Future<void> clearRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}