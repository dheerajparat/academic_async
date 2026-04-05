import 'dart:convert';

class AttendanceQrPayload {
  const AttendanceQrPayload({
    required this.attendanceId,
    required this.timestampMillis,
    required this.teacherId,
    required this.subjectId,
    required this.expiryTimeMillis,
    required this.validForSeconds,
    required this.graceDelaySeconds,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String attendanceId;
  final int timestampMillis;
  final String teacherId;
  final String subjectId;
  final int expiryTimeMillis;
  final int validForSeconds;
  final int graceDelaySeconds;
  final double latitude;
  final double longitude;
  final double radiusMeters;
}

class AttendanceQrCodec {
  // Kept for backward compatibility with previously generated encrypted payloads.
  static const String _secret = 'academic_async_qr_v1';

  static String encode({
    required String attendanceId,
    required int timestampMillis,
    required String teacherId,
    required String subjectId,
    required int expiryTimeMillis,
    required int validForSeconds,
    required int graceDelaySeconds,
    required double latitude,
    required double longitude,
    required double radiusMeters,
  }) {
    final Map<String, dynamic> jsonMap = {
      'attendance_id': attendanceId,
      'timestamp_millis': timestampMillis,
      'teacher_id': teacherId,
      'subject_id': subjectId,
      'expiry_time_millis': expiryTimeMillis,
      'valid_for_seconds': validForSeconds,
      'grace_delay_seconds': graceDelaySeconds,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
    };
    return jsonEncode(jsonMap);
  }

  static AttendanceQrPayload? decode(String encryptedPayload) {
    final String raw = encryptedPayload.trim();
    if (raw.isEmpty) {
      return null;
    }

    final Map<String, dynamic>? map =
        _decodePlainJson(raw) ?? _decodeLegacyEncrypted(raw);
    if (map == null) {
      return null;
    }

    final String attendanceId = _asString(map['attendance_id']);
    final int timestampMillis = _asInt(map['timestamp_millis']);
    if (attendanceId.isEmpty || timestampMillis <= 0) {
      return null;
    }

    final int validForSeconds = _asInt(map['valid_for_seconds']);
    final int explicitExpiryMillis = _asInt(map['expiry_time_millis']);
    final int computedExpiryMillis = explicitExpiryMillis > 0
        ? explicitExpiryMillis
        : (validForSeconds > 0
              ? timestampMillis + (validForSeconds * 1000)
              : timestampMillis);

    try {
      return AttendanceQrPayload(
        attendanceId: attendanceId,
        timestampMillis: timestampMillis,
        teacherId: _asString(map['teacher_id']),
        subjectId: _asString(map['subject_id']),
        expiryTimeMillis: computedExpiryMillis,
        validForSeconds: validForSeconds,
        graceDelaySeconds: _asInt(map['grace_delay_seconds']),
        latitude: _asDouble(map['latitude']),
        longitude: _asDouble(map['longitude']),
        radiusMeters: _asDouble(map['radius_meters'], fallback: 50),
      );
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _decodePlainJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic>? _decodeLegacyEncrypted(String raw) {
    try {
      final List<int> encryptedBytes = base64Url.decode(raw);
      final List<int> plainBytes = _xorWithSecret(encryptedBytes);
      final dynamic decoded = jsonDecode(utf8.decode(plainBytes));
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }

  static List<int> _xorWithSecret(List<int> source) {
    final List<int> key = utf8.encode(_secret);
    return List<int>.generate(source.length, (index) {
      return source[index] ^ key[index % key.length];
    });
  }

  static String _asString(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    if (value == null) {
      return '';
    }
    return value.toString().trim();
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

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) {
      return value;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim()) ?? fallback;
    }
    return fallback;
  }
}
