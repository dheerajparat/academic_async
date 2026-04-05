import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SyllabusProgressService {
  static const String _storagePrefix = 'syllabus_progress_v1';

  static String buildScope({
    required String semesterId,
    required String userId,
  }) {
    final String normalizedSemester = semesterId.trim().toLowerCase();
    final String normalizedUser = userId.trim().toLowerCase();
    if (normalizedSemester.isEmpty) {
      return '';
    }
    return '${normalizedUser.isEmpty ? 'guest' : normalizedUser}::$normalizedSemester';
  }

  static Future<Set<String>> readCompletedKeys(String scope) async {
    if (scope.trim().isEmpty) {
      return <String>{};
    }
    final prefs = await SharedPreferences.getInstance();
    final String raw = prefs.getString(_prefKey(scope)) ?? '[]';
    final dynamic decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <String>{};
    }
    return decoded
        .whereType<dynamic>()
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  static Future<void> saveCompletedKeys(String scope, Set<String> keys) async {
    if (scope.trim().isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final List<String> sorted = keys.toList()..sort();
    await prefs.setString(_prefKey(scope), jsonEncode(sorted));
  }

  static String _prefKey(String scope) => '$_storagePrefix::$scope';
}
