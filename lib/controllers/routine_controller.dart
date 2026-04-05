import 'dart:convert';

import 'package:academic_async/services/routine_widget_service.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RoutineImportResult {
  const RoutineImportResult._({
    required this.isSuccess,
    required this.message,
    required this.periodsCount,
  });

  factory RoutineImportResult.success({
    required String message,
    required int periodsCount,
  }) {
    return RoutineImportResult._(
      isSuccess: true,
      message: message,
      periodsCount: periodsCount,
    );
  }

  factory RoutineImportResult.failure(String message) {
    return RoutineImportResult._(
      isSuccess: false,
      message: message,
      periodsCount: 0,
    );
  }

  final bool isSuccess;
  final String message;
  final int periodsCount;
}

class RoutineImportPreview {
  const RoutineImportPreview({
    required this.parsedRoutine,
    required this.periodsCount,
    required this.entriesCount,
  });

  final Map<String, Map<String, String>> parsedRoutine;
  final int periodsCount;
  final int entriesCount;
}

class RoutineController extends GetxController {
  static const String _storageKey = 'routine_data';
  static const Map<String, Map<String, String>> _defaultRoutine = {};

  final List<String> dayKeys = const <String>[
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  final Map<String, String> dayLabels = const <String, String>{
    'monday': 'Monday',
    'tuesday': 'Tuesday',
    'wednesday': 'Wednesday',
    'thursday': 'Thursday',
    'friday': 'Friday',
    'saturday': 'Saturday',
    'sunday': 'Sunday',
  };

  final RxMap<String, Map<String, String>> routine =
      <String, Map<String, String>>{}.obs;
  final RxBool showTodayOnly = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadRoutine();
  }

  String get today {
    final DateTime now = DateTime.now();
    return dayKeys[now.weekday - 1];
  }

  List<String> get periods => routine.keys.toList()..sort();

  String dayLabel(String dayKey) => dayLabels[dayKey] ?? dayKey;

  Future<void> addOrUpdateEntry({
    required String period,
    required String day,
    required String subject,
  }) async {
    final String normalizedPeriod = period.trim().toLowerCase();
    final String normalizedDay = day.trim().toLowerCase();
    final String normalizedSubject = subject.trim();

    if (normalizedPeriod.isEmpty ||
        normalizedSubject.isEmpty ||
        !dayKeys.contains(normalizedDay)) {
      return;
    }

    final Map<String, String> existing = Map<String, String>.from(
      routine[normalizedPeriod] ?? <String, String>{},
    );
    existing[normalizedDay] = normalizedSubject;
    routine[normalizedPeriod] = existing;
    routine.refresh();
    await _saveRoutine();
  }

  Future<RoutineImportPreview> validateRoutineJson(String rawJson) async {
    final String trimmed = rawJson.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('JSON is empty.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      throw const FormatException('Invalid JSON format.');
    }

    final Map<String, Map<String, String>> parsed = _parseRoutinePayload(
      decoded,
      strict: true,
    );
    final int entriesCount = parsed.values.fold<int>(
      0,
      (int sum, Map<String, String> dayMap) => sum + dayMap.length,
    );

    return RoutineImportPreview(
      parsedRoutine: parsed,
      periodsCount: parsed.length,
      entriesCount: entriesCount,
    );
  }

  Future<RoutineImportResult> applyImportedRoutine(
    Map<String, Map<String, String>> parsedRoutine, {
    required bool mergeWithExisting,
  }) async {
    if (parsedRoutine.isEmpty) {
      return RoutineImportResult.failure('Routine data is empty.');
    }

    final Map<String, Map<String, String>> merged = mergeWithExisting
        ? _mergeRoutineData(_plainRoutine(), parsedRoutine)
        : _deepCopyRoutine(parsedRoutine);

    routine.assignAll(merged);
    routine.refresh();
    await _saveRoutine();

    final String modeText = mergeWithExisting ? 'merged' : 'replaced';
    return RoutineImportResult.success(
      message: 'Routine $modeText successfully (${merged.length} periods).',
      periodsCount: merged.length,
    );
  }

  Future<RoutineImportResult> importFromJsonString(String rawJson) async {
    try {
      final RoutineImportPreview preview = await validateRoutineJson(rawJson);
      return applyImportedRoutine(
        preview.parsedRoutine,
        mergeWithExisting: false,
      );
    } on FormatException catch (error) {
      return RoutineImportResult.failure(error.message);
    } catch (_) {
      return RoutineImportResult.failure('Unsupported JSON structure.');
    }
  }

  String exportRoutineJson({bool pretty = true}) {
    final Map<String, Map<String, String>> plain = _plainRoutine();
    if (pretty) {
      const JsonEncoder encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(plain);
    }
    return jsonEncode(plain);
  }

  Future<void> _loadRoutine() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_storageKey);

    if (jsonString == null || jsonString.trim().isEmpty) {
      routine.assignAll(_deepCopyRoutine(_defaultRoutine));
      await _saveRoutine();
      return;
    }

    try {
      final dynamic decoded = jsonDecode(jsonString);
      final Map<String, Map<String, String>> parsed = _parseRoutinePayload(
        decoded,
        strict: false,
      );

      if (parsed.isEmpty) {
        routine.assignAll(_deepCopyRoutine(_defaultRoutine));
        await _saveRoutine();
        return;
      }

      routine.assignAll(parsed);
      await RoutineWidgetService.updateRoutineWidget(_plainRoutine());
    } catch (_) {
      routine.assignAll(_deepCopyRoutine(_defaultRoutine));
      await _saveRoutine();
    }
  }

  Future<void> _saveRoutine() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Map<String, Map<String, String>> plainRoutine = _plainRoutine();
    await prefs.setString(_storageKey, jsonEncode(plainRoutine));
    await RoutineWidgetService.updateRoutineWidget(plainRoutine);
  }

  Map<String, Map<String, String>> _plainRoutine() {
    return routine.map(
      (String period, Map<String, String> dayMap) =>
          MapEntry(period, Map<String, String>.from(dayMap)),
    );
  }

  Map<String, Map<String, String>> _deepCopyRoutine(
    Map<String, Map<String, String>> source,
  ) {
    return source.map(
      (String period, Map<String, String> dayMap) =>
          MapEntry(period, Map<String, String>.from(dayMap)),
    );
  }

  Map<String, Map<String, String>> _mergeRoutineData(
    Map<String, Map<String, String>> existing,
    Map<String, Map<String, String>> incoming,
  ) {
    final Map<String, Map<String, String>> merged = _deepCopyRoutine(existing);

    for (final MapEntry<String, Map<String, String>> entry
        in incoming.entries) {
      final String period = entry.key;
      final Map<String, String> dayMap = Map<String, String>.from(
        merged[period] ?? <String, String>{},
      );
      dayMap.addAll(entry.value);
      merged[period] = dayMap;
    }

    return merged;
  }

  Map<String, Map<String, String>> _parseRoutinePayload(
    dynamic decoded, {
    required bool strict,
  }) {
    final Map<String, dynamic>? container = _extractContainer(decoded);
    if (container == null) {
      if (strict) {
        throw const FormatException(
          'Expected a routine object shaped like period -> {day: subject}.',
        );
      }
      return <String, Map<String, String>>{};
    }

    final Map<String, Map<String, String>> parsed =
        <String, Map<String, String>>{};

    for (final MapEntry<String, dynamic> entry in container.entries) {
      final String period = entry.key.trim().toLowerCase();
      if (period.isEmpty) {
        if (strict) {
          throw const FormatException('Period name cannot be empty.');
        }
        continue;
      }

      if (entry.value is! Map) {
        if (strict) {
          throw FormatException("Period '$period' must contain an object.");
        }
        continue;
      }

      final Map<dynamic, dynamic> rawDays =
          entry.value as Map<dynamic, dynamic>;
      final Map<String, String> dayMap = <String, String>{};

      for (final MapEntry<dynamic, dynamic> dayEntry in rawDays.entries) {
        final String rawDay = dayEntry.key.toString().trim().toLowerCase();
        if (!dayKeys.contains(rawDay)) {
          if (strict) {
            throw FormatException(
              "Invalid day key '$rawDay'. Allowed values: ${dayKeys.join(', ')}.",
            );
          }
          continue;
        }

        if (dayEntry.value is! String) {
          if (strict) {
            throw FormatException(
              "Subject must be a string for period '$period' on '$rawDay'.",
            );
          }
          continue;
        }

        final String subject = (dayEntry.value as String).trim();
        if (subject.isEmpty) {
          if (strict) {
            throw FormatException(
              "Subject cannot be empty for period '$period' on '$rawDay'.",
            );
          }
          continue;
        }

        dayMap[rawDay] = subject;
      }

      if (dayMap.isEmpty) {
        if (strict) {
          throw FormatException(
            "Period '$period' must contain at least one valid day entry.",
          );
        }
        continue;
      }

      parsed[period] = dayMap;
    }

    if (strict && parsed.isEmpty) {
      throw const FormatException('No valid routine entries found.');
    }

    return parsed;
  }

  Map<String, dynamic>? _extractContainer(dynamic decoded) {
    if (decoded is! Map) {
      return null;
    }

    final Map<String, dynamic> map = decoded.map<String, dynamic>(
      (dynamic key, dynamic value) => MapEntry(key.toString(), value),
    );

    if (map.containsKey('routine') && map['routine'] is Map) {
      return (map['routine'] as Map<dynamic, dynamic>).map<String, dynamic>(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );
    }

    return map;
  }
}
