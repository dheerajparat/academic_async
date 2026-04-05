import 'package:academic_async/models/event_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventCacheService {
  static const String _eventsJsonKey = 'events_cache_json';
  static const String _lastSyncMillisKey = 'events_last_sync_millis';
  static const String _userBranchIdKey = 'user_branch_id';
  static const String _userSemesterIdKey = 'user_semester_id';

  static Future<List<EventRecord>> readCachedEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_eventsJsonKey) ?? '';
    return EventRecord.decodeList(raw);
  }

  static Future<void> saveCachedEvents(List<EventRecord> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_eventsJsonKey, EventRecord.encodeList(events));
  }

  static Future<int> readLastSyncMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSyncMillisKey) ?? 0;
  }

  static Future<void> saveLastSyncMillis(int millis) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSyncMillisKey, millis);
  }

  static Future<void> saveUserContext({
    required String branchId,
    required String semesterId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userBranchIdKey, branchId);
    await prefs.setString(_userSemesterIdKey, semesterId);
  }

  static Future<Map<String, String>> readUserContext() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'branch_id': prefs.getString(_userBranchIdKey) ?? '',
      'semester_id': prefs.getString(_userSemesterIdKey) ?? '',
    };
  }

  static Future<void> clearUserContext() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userBranchIdKey);
    await prefs.remove(_userSemesterIdKey);
  }
}
