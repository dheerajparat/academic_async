import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUserRecord {
  const AdminUserRecord({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.requestedRole,
    required this.approvalStatus,
    required this.registrationNo,
    required this.branch,
    required this.branchId,
    required this.semester,
    required this.semesterId,
    required this.isTeacher,
    required this.teacherSubjectIds,
    required this.teacherSubjectNames,
  });

  final String uid;
  final String name;
  final String email;
  final String role;
  final String requestedRole;
  final String approvalStatus;
  final String registrationNo;
  final String branch;
  final String branchId;
  final String semester;
  final String semesterId;
  final bool isTeacher;
  final List<String> teacherSubjectIds;
  final List<String> teacherSubjectNames;

  bool get isLikelyTeacher {
    final normalizedRole = role.trim().toLowerCase();
    final normalizedRequestedRole = requestedRole.trim().toLowerCase();
    return isTeacher ||
        normalizedRole == 'teacher' ||
        normalizedRole == 'faculty' ||
        normalizedRole == 'professor' ||
        normalizedRole == 'teacher_pending' ||
        normalizedRequestedRole == 'teacher';
  }

  bool get isStudent {
    final normalizedRole = role.trim().toLowerCase();
    final normalizedRequestedRole = requestedRole.trim().toLowerCase();
    if (isDeveloper || isLikelyTeacher) {
      return false;
    }
    if (normalizedRole == 'student' || normalizedRequestedRole == 'student') {
      return true;
    }
    return registrationNo.isNotEmpty ||
        branchId.isNotEmpty ||
        semesterId.isNotEmpty;
  }

  bool get isDeveloper => role.trim().toLowerCase() == 'developer';

  String get displayName {
    if (name.trim().isNotEmpty) {
      return name.trim();
    }
    if (email.trim().isNotEmpty) {
      return email.split('@').first.trim();
    }
    return uid;
  }

  static AdminUserRecord fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AdminUserRecord(
      uid: doc.id,
      name: _readString(data, const [
        'name',
        'full_name',
        'display_name',
        'username',
        'user_name',
      ]),
      email: _readString(data, const ['email', 'mail']),
      role: _readString(data, const ['role', 'user_role', 'type']),
      requestedRole: _readString(data, const [
        'requested_role',
        'requestedRole',
      ]),
      approvalStatus: _readString(data, const [
        'approval_status',
        'approvalStatus',
      ]),
      registrationNo: _readString(data, const [
        'registration_no',
        'registrationNo',
        'roll_no',
      ]),
      branch: _readString(data, const ['branch', 'branch_name']),
      branchId: _readString(data, const ['branch_id', 'branchId']),
      semester: _readString(data, const ['semester', 'semester_name']),
      semesterId: _readString(data, const ['semester_id', 'semesterId']),
      isTeacher: _asBool(data['is_teacher']) || _asBool(data['isTeacher']),
      teacherSubjectIds: _readStringList(data, const [
        'teacher_subject_ids',
        'teacherSubjectIds',
      ]),
      teacherSubjectNames: _readStringList(data, const [
        'teacher_subject_names',
        'teacherSubjectNames',
      ]),
    );
  }
}

class TeacherSignupRequestRecord {
  const TeacherSignupRequestRecord({
    required this.uid,
    required this.name,
    required this.email,
    required this.status,
    required this.teacherSubjectIds,
    required this.teacherSubjectNames,
    required this.requestedAtMillis,
  });

  final String uid;
  final String name;
  final String email;
  final String status;
  final List<String> teacherSubjectIds;
  final List<String> teacherSubjectNames;
  final int requestedAtMillis;

  static TeacherSignupRequestRecord fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return TeacherSignupRequestRecord(
      uid: _readString(data, const ['uid'], fallback: doc.id),
      name: _readString(data, const [
        'name',
        'full_name',
        'display_name',
        'username',
      ]),
      email: _readString(data, const ['email', 'mail']),
      status: _readString(data, const [
        'status',
        'request_status',
      ], fallback: 'pending'),
      teacherSubjectIds: _readStringList(data, const [
        'teacher_subject_ids',
        'teacherSubjectIds',
      ]),
      teacherSubjectNames: _readStringList(data, const [
        'teacher_subject_names',
        'teacherSubjectNames',
      ]),
      requestedAtMillis: _readInt(data, const [
        'requested_at',
        'requestedAt',
        'created_at',
        'updated_at',
      ]),
    );
  }
}

String _readString(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = _asString(data[key]);
    if (value.isNotEmpty) {
      return value;
    }
  }
  return fallback;
}

int _readInt(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = _asInt(data[key]);
    if (value > 0) {
      return value;
    }
  }
  return 0;
}

List<String> _readStringList(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final values = _asStringList(data[key]);
    if (values.isNotEmpty) {
      return values;
    }
  }
  return const <String>[];
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

bool _asBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
  return false;
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

List<String> _asStringList(dynamic value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((e) => _asString(e))
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();
}
