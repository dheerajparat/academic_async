import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

class EventRecord {
  const EventRecord({
    required this.id,
    required this.date,
    required this.description,
    required this.type,
    required this.branch,
    required this.branchId,
    required this.semester,
    required this.semesterId,
    required this.updatedAtMillis,
  });

  final String id;
  final DateTime date;
  final String description;
  final String type;
  final String branch;
  final String branchId;
  final String semester;
  final String semesterId;
  final int updatedAtMillis;

  String get displayText => description.isNotEmpty ? description : type;

  DateTime get normalizedDate => DateTime(date.year, date.month, date.day);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'description': description,
      'type': type,
      'branch': branch,
      'branch_id': branchId,
      'semester': semester,
      'semester_id': semesterId,
      'updated_at_millis': updatedAtMillis,
    };
  }

  factory EventRecord.fromJson(Map<String, dynamic> map) {
    return EventRecord(
      id: _asString(map['id']),
      date: _parseDate(map['date']) ?? DateTime.now(),
      description: _asString(map['description']),
      type: _asString(map['type'], fallback: 'Event'),
      branch: _asString(map['branch']),
      branchId: _asString(map['branch_id']),
      semester: _asString(map['semester']),
      semesterId: _asString(map['semester_id']),
      updatedAtMillis: _asInt(map['updated_at_millis']),
    );
  }

  static EventRecord? fromFirestore(String id, Map<String, dynamic> data) {
    final DateTime? parsedDate =
        _parseDate(data['date']) ??
        _parseDate(data['event_date']) ??
        _parseDate(data['eventDate']);
    if (parsedDate == null) {
      return null;
    }

    final DateTime updatedAt =
        _parseDate(data['updated_at']) ??
        _parseDate(data['updatedAt']) ??
        _parseDate(data['created_at']) ??
        _parseDate(data['createdAt']) ??
        DateTime.now();

    final String description = _asString(
      data['description'],
      fallback: _asString(data['title'], fallback: _asString(data['name'])),
    ).trim();
    final String type = _asString(
      data['type'],
      fallback: _asString(data['event_type'], fallback: 'event'),
    ).trim();

    return EventRecord(
      id: id,
      date: parsedDate,
      description: description,
      type: type.isEmpty ? 'event' : type,
      branch: _asString(data['branch']),
      branchId: _asString(
        data['branch_id'],
        fallback: _asString(data['branchId']),
      ),
      semester: _asString(data['semester']),
      semesterId: _asString(
        data['semester_id'],
        fallback: _asString(data['semesterId']),
      ),
      updatedAtMillis: updatedAt.millisecondsSinceEpoch,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is int) {
      final bool looksLikeSeconds = value.abs() < 1000000000000;
      final int millis = looksLikeSeconds ? value * 1000 : value;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    if (value is double) {
      final int raw = value.toInt();
      final bool looksLikeSeconds = raw.abs() < 1000000000000;
      final int millis = looksLikeSeconds ? raw * 1000 : raw;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    if (value is String) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      final DateTime? iso = DateTime.tryParse(trimmed);
      if (iso != null) {
        return iso;
      }

      final RegExp dmyPattern = RegExp(
        r'^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$',
      );
      final match = dmyPattern.firstMatch(trimmed);
      if (match == null) {
        return null;
      }

      final int? day = int.tryParse(match.group(1)!);
      final int? month = int.tryParse(match.group(2)!);
      final int? yearRaw = int.tryParse(match.group(3)!);
      if (day == null || month == null || yearRaw == null) {
        return null;
      }
      final int year = yearRaw < 100 ? (2000 + yearRaw) : yearRaw;
      final DateTime? dmy = _safeDate(year, month, day);
      if (dmy != null) {
        return dmy;
      }
      return _safeDate(year, day, month);
    }
    return null;
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    final normalized = value.toString().trim();
    return normalized.isEmpty ? fallback : normalized;
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }

  static DateTime? _safeDate(int year, int month, int day) {
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final DateTime parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static String encodeList(List<EventRecord> events) {
    return jsonEncode(events.map((e) => e.toJson()).toList());
  }

  static List<EventRecord> decodeList(String raw) {
    if (raw.trim().isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map((e) => EventRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
