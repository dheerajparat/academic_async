import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceSubjectContext {
  const AttendanceSubjectContext({
    required this.branchId,
    required this.branchName,
    required this.semesterId,
    required this.semesterName,
  });

  final String branchId;
  final String branchName;
  final String semesterId;
  final String semesterName;

  String get branchLabel =>
      branchName.trim().isEmpty ? branchId.trim() : branchName.trim();

  String get semesterLabel =>
      semesterName.trim().isEmpty ? semesterId.trim() : semesterName.trim();

  String get semesterWithBranchLabel {
    final String semester = semesterLabel;
    final String branch = branchLabel;
    if (semester.isEmpty) {
      return branch;
    }
    if (branch.isEmpty) {
      return semester;
    }
    return '$semester • $branch';
  }
}

class AttendanceSubject {
  const AttendanceSubject({
    required this.id,
    required this.name,
    this.contexts = const <AttendanceSubjectContext>[],
  });

  final String id;
  final String name;
  final List<AttendanceSubjectContext> contexts;

  AttendanceSubject copyWith({
    String? id,
    String? name,
    List<AttendanceSubjectContext>? contexts,
  }) {
    return AttendanceSubject(
      id: id ?? this.id,
      name: name ?? this.name,
      contexts: contexts ?? this.contexts,
    );
  }
}

class AttendanceOption {
  const AttendanceOption({
    required this.id,
    required this.name,
    this.description = '',
  });

  final String id;
  final String name;
  final String description;

  String get label {
    final String normalizedDescription = description.trim();
    if (normalizedDescription.isEmpty) {
      return name;
    }
    return '$name • $normalizedDescription';
  }
}

class AttendanceRosterStudent {
  const AttendanceRosterStudent({
    required this.uid,
    required this.name,
    required this.registrationNo,
  });

  final String uid;
  final String name;
  final String registrationNo;

  String get displayName => name.trim().isEmpty ? uid : name.trim();
}

class AttendanceStudentScan {
  const AttendanceStudentScan({
    required this.uid,
    required this.name,
    required this.scanTimeMillis,
    this.latitude,
    this.longitude,
    this.distanceMeters,
    this.accuracyMeters,
  });

  final String uid;
  final String name;
  final int scanTimeMillis;
  final double? latitude;
  final double? longitude;
  final double? distanceMeters;
  final double? accuracyMeters;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'scan_time_millis': scanTimeMillis,
      if (latitude != null) 'scan_latitude': latitude,
      if (longitude != null) 'scan_longitude': longitude,
      if (distanceMeters != null) 'distance_meters': distanceMeters,
      if (accuracyMeters != null) 'scan_accuracy_meters': accuracyMeters,
    };
  }

  static AttendanceStudentScan? fromDynamic(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final map = Map<String, dynamic>.from(raw);
    final String uid = _asString(map['uid']);
    if (uid.isEmpty) {
      return null;
    }
    return AttendanceStudentScan(
      uid: uid,
      name: _asString(map['name']),
      scanTimeMillis: _asInt(map['scan_time_millis']),
      latitude: _asNullableDouble(map['scan_latitude']),
      longitude: _asNullableDouble(map['scan_longitude']),
      distanceMeters: _asNullableDouble(map['distance_meters']),
      accuracyMeters: _asNullableDouble(map['scan_accuracy_meters']),
    );
  }
}

class AttendanceEntry {
  const AttendanceEntry({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.branch,
    required this.branchId,
    required this.semester,
    required this.semesterId,
    required this.teacherId,
    required this.teacherName,
    required this.dateKey,
    required this.startTimeMillis,
    required this.expiryTimeMillis,
    required this.qrPayload,
    required this.eligibleStudentIds,
    required this.eligibleStudentNames,
    required this.students,
    required this.presentCount,
    required this.classConducted,
    required this.isFinalized,
    required this.finalizedAtMillis,
    required this.allowedRadiusMeters,
    required this.graceDelaySeconds,
    required this.validForSeconds,
    required this.generateLatitude,
    required this.generateLongitude,
    required this.generateAccuracyMeters,
  });

  final String id;
  final String subjectId;
  final String subjectName;
  final String branch;
  final String branchId;
  final String semester;
  final String semesterId;
  final String teacherId;
  final String teacherName;
  final String dateKey;
  final int startTimeMillis;
  final int expiryTimeMillis;
  final String qrPayload;
  final List<String> eligibleStudentIds;
  final Map<String, String> eligibleStudentNames;
  final Map<String, AttendanceStudentScan> students;
  final int presentCount;
  final bool classConducted;
  final bool isFinalized;
  final int finalizedAtMillis;
  final double allowedRadiusMeters;
  final int graceDelaySeconds;
  final int validForSeconds;
  final double generateLatitude;
  final double generateLongitude;
  final double generateAccuracyMeters;

  int get validUntilMillis => expiryTimeMillis + (graceDelaySeconds * 1000);

  bool get isClosed => isFinalized || isExpired;

  bool get isExpired =>
      DateTime.now().millisecondsSinceEpoch > validUntilMillis;

  int get eligibleStudentCount => eligibleStudentIds.length;

  bool isEligibleForStudent(String studentUid) {
    final String normalized = studentUid.trim();
    if (normalized.isEmpty) {
      return false;
    }
    if (eligibleStudentIds.isEmpty) {
      return true;
    }
    return eligibleStudentIds.contains(normalized);
  }

  List<AttendanceStudentScan> get studentsSorted {
    final list = students.values.toList()
      ..sort((a, b) => b.scanTimeMillis.compareTo(a.scanTimeMillis));
    return list;
  }

  static AttendanceEntry? fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      return null;
    }

    final Map<String, AttendanceStudentScan> mappedStudents =
        <String, AttendanceStudentScan>{};
    final rawStudents = data['students'];
    if (rawStudents is Map) {
      for (final entry in rawStudents.entries) {
        final scan = AttendanceStudentScan.fromDynamic(entry.value);
        if (scan != null) {
          mappedStudents[entry.key.toString()] = scan;
        }
      }
    }

    final List<String> eligibleStudentIds =
        _firstStringList(data, const <String>[
          'eligible_student_ids',
          'eligibleStudentIds',
          'target_student_ids',
          'targetStudentIds',
        ]);
    final Map<String, String> eligibleStudentNames = <String, String>{};
    final dynamic rawEligibleStudents =
        data['eligible_students'] ?? data['eligibleStudents'];
    if (rawEligibleStudents is Map) {
      for (final entry in rawEligibleStudents.entries) {
        final String uid = _asString(entry.key);
        if (uid.isEmpty) {
          continue;
        }
        eligibleStudentNames[uid] = _asString(entry.value, fallback: uid);
      }
    }

    return AttendanceEntry(
      id: doc.id,
      subjectId: _firstString(data, const <String>[
        'subject_id',
        'subjectId',
        'teacher_subject_id',
        'teacherSubjectId',
      ]),
      subjectName: _firstString(data, const <String>[
        'subject_name',
        'subjectName',
        'teacher_subject_name',
        'teacherSubjectName',
      ], fallback: 'Subject'),
      branch: _firstString(data, const <String>['branch', 'branch_name']),
      branchId: _firstString(data, const <String>['branch_id', 'branchId']),
      semester: _firstString(data, const <String>['semester', 'semester_name']),
      semesterId: _firstString(data, const <String>[
        'semester_id',
        'semesterId',
      ]),
      teacherId: _firstString(data, const <String>[
        'teacher_id',
        'teacherId',
        'teacher_uid',
        'teacherUid',
      ]),
      teacherName: _firstString(data, const <String>[
        'teacher_name',
        'teacherName',
      ], fallback: 'Teacher'),
      dateKey: _firstString(data, const <String>['date_key', 'dateKey']),
      startTimeMillis: _firstInt(data, const <String>[
        'start_time_millis',
        'startTimeMillis',
      ]),
      expiryTimeMillis: _firstInt(data, const <String>[
        'expiry_time_millis',
        'expiryTimeMillis',
      ]),
      qrPayload: _firstString(data, const <String>['qr_payload', 'qrPayload']),
      eligibleStudentIds: eligibleStudentIds,
      eligibleStudentNames: eligibleStudentNames,
      students: mappedStudents,
      presentCount: _firstInt(data, const <String>[
        'present_count',
        'presentCount',
      ]),
      classConducted: _firstBool(data, const <String>[
        'class_conducted',
        'classConducted',
      ]),
      isFinalized: _firstBool(data, const <String>[
        'is_finalized',
        'isFinalized',
      ]),
      finalizedAtMillis: _firstInt(data, const <String>[
        'finalized_at_millis',
        'finalizedAtMillis',
      ]),
      allowedRadiusMeters: _firstDouble(data, const <String>[
        'allowed_radius_meters',
        'allowedRadiusMeters',
      ], fallback: 50),
      graceDelaySeconds: _firstInt(data, const <String>[
        'grace_delay_seconds',
        'graceDelaySeconds',
      ]),
      validForSeconds: _firstInt(data, const <String>[
        'valid_for_seconds',
        'validForSeconds',
      ]),
      generateLatitude: _firstDouble(data, const <String>[
        'generate_latitude',
        'generateLatitude',
      ]),
      generateLongitude: _firstDouble(data, const <String>[
        'generate_longitude',
        'generateLongitude',
      ]),
      generateAccuracyMeters: _firstDouble(data, const <String>[
        'generate_accuracy_meters',
        'generateAccuracyMeters',
      ]),
    );
  }
}

class SubjectAttendanceSummary {
  const SubjectAttendanceSummary({
    required this.subjectId,
    required this.subjectName,
    required this.totalClassDays,
    required this.presentDays,
  });

  final String subjectId;
  final String subjectName;
  final int totalClassDays;
  final int presentDays;

  double get percentage {
    if (totalClassDays <= 0) {
      return 0;
    }
    return (presentDays / totalClassDays) * 100;
  }
}

class StudentAttendanceHistoryItem {
  const StudentAttendanceHistoryItem({
    required this.subjectId,
    required this.subjectName,
    required this.scanTimeMillis,
    required this.sessionStartTimeMillis,
    required this.attendanceId,
    required this.dateKey,
  });

  final String subjectId;
  final String subjectName;
  final int scanTimeMillis;
  final int sessionStartTimeMillis;
  final String attendanceId;
  final String dateKey;

  int get displayTimeMillis =>
      sessionStartTimeMillis > 0 ? sessionStartTimeMillis : scanTimeMillis;
}

class StudentDailyAttendanceRecord {
  const StudentDailyAttendanceRecord({
    required this.dateKey,
    required this.scheduledSessionCount,
    required this.attendedSessionCount,
    required this.attendedClasses,
  });

  final String dateKey;
  final int scheduledSessionCount;
  final int attendedSessionCount;
  final List<StudentAttendanceHistoryItem> attendedClasses;

  bool get wasPresent => attendedSessionCount > 0;
}

class TeacherSubjectReport {
  const TeacherSubjectReport({
    required this.subjectId,
    required this.subjectName,
    required this.branch,
    required this.branchId,
    required this.semester,
    required this.semesterId,
    required this.totalSessionsCreated,
    required this.totalClassDays,
    required this.totalPresentScans,
  });

  final String subjectId;
  final String subjectName;
  final String branch;
  final String branchId;
  final String semester;
  final String semesterId;
  final int totalSessionsCreated;
  final int totalClassDays;
  final int totalPresentScans;

  double get avgPresentPerSession {
    if (totalSessionsCreated <= 0) {
      return 0;
    }
    return totalPresentScans / totalSessionsCreated;
  }
}

String _asString(dynamic value, {String fallback = ''}) {
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

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value is Timestamp) {
    return value.millisecondsSinceEpoch;
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

bool _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  if (value is num) {
    return value != 0;
  }
  return false;
}

String _firstString(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final String key in keys) {
    final String value = _asString(data[key]);
    if (value.isNotEmpty) {
      return value;
    }
  }
  return fallback;
}

int _firstInt(Map<String, dynamic> data, List<String> keys) {
  for (final String key in keys) {
    final dynamic raw = data[key];
    if (raw != null) {
      return _asInt(raw);
    }
  }
  return 0;
}

List<String> _firstStringList(Map<String, dynamic> data, List<String> keys) {
  for (final String key in keys) {
    final dynamic raw = data[key];
    if (raw is! List) {
      continue;
    }
    final List<String> values = raw
        .map((item) => _asString(item))
        .where((item) => item.isNotEmpty)
        .toList();
    if (values.isNotEmpty) {
      return values;
    }
  }
  return const <String>[];
}

double _firstDouble(
  Map<String, dynamic> data,
  List<String> keys, {
  double fallback = 0,
}) {
  for (final String key in keys) {
    final dynamic raw = data[key];
    if (raw != null) {
      return _asDouble(raw, fallback: fallback);
    }
  }
  return fallback;
}

bool _firstBool(Map<String, dynamic> data, List<String> keys) {
  for (final String key in keys) {
    final dynamic raw = data[key];
    if (raw != null) {
      return _asBool(raw);
    }
  }
  return false;
}

double _asDouble(dynamic value, {double fallback = 0}) {
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

double? _asNullableDouble(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}
