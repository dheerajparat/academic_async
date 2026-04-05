import 'dart:convert';

import 'package:academic_async/models/developer_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeveloperCacheService {
  static const String _developersJsonKey = 'developers_cache_json';

  static Future<List<DeveloperProfile>> readCachedDevelopers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_developersJsonKey) ?? '';
    if (raw.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      final mapped = decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .map(DeveloperProfile.fromCacheMap)
          .where((item) => item.hasContent)
          .toList();
      return mapped;
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveCachedDevelopers(List<DeveloperProfile> items) async {
    final prefs = await SharedPreferences.getInstance();
    final list = items.map((item) => item.toCacheMap()).toList();
    await prefs.setString(_developersJsonKey, jsonEncode(list));
  }
}
