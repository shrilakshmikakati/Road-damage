import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/road_damage.dart';

abstract class DamageRepository {
  Future<List<RoadDamage>> getAllDamages();
  Future<void> saveDamage(RoadDamage damage);
  Future<void> clearAllDamages();
}

class LocalDamageRepository implements DamageRepository {
  static const String _storageKey = 'road_damages';

  @override
  Future<List<RoadDamage>> getAllDamages() async {
    final prefs = await SharedPreferences.getInstance();
    final damagesJson = prefs.getStringList(_storageKey) ?? [];

    return damagesJson
        .map((json) => RoadDamage.fromJson(jsonDecode(json)))
        .toList();
  }

  @override
  Future<void> saveDamage(RoadDamage damage) async {
    final prefs = await SharedPreferences.getInstance();
    final damagesJson = prefs.getStringList(_storageKey) ?? [];

    damagesJson.add(jsonEncode(damage.toJson()));
    await prefs.setStringList(_storageKey, damagesJson);
  }

  @override
  Future<void> clearAllDamages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}