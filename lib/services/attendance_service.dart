import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:academic_async/models/attendance_models.dart';
import 'package:academic_async/services/attendance_qr_codec.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:firebase_core/firebase_core.dart';

enum AttendanceMarkStatus {
  success,
  invalidQr,
  attendanceNotFound,
  qrExpired,
  sessionClosed,
  alreadyMarked,
  notEligible,
  locationUnavailable,
  outsideAllowedRadius,
  permissionDenied,
  unknownError,
}

class AttendanceMarkResult {
  const AttendanceMarkResult({required this.status, this.entry});

  final AttendanceMarkStatus status;
  final AttendanceEntry? entry;

  bool get isSuccess => status == AttendanceMarkStatus.success;
}

class AttendanceUserContext {
  const AttendanceUserContext({
    required this.isTeacher,
    required this.teacherSubjects,
    required this.studentSubjects,
  });

  final bool isTeacher;
  final List<AttendanceSubject> teacherSubjects;
  final List<AttendanceSubject> studentSubjects;
}

class _TeacherAttendanceMatrixRow {
  const _TeacherAttendanceMatrixRow({
    required this.registrationNo,
    required this.studentName,
    required this.attendanceMarks,
    required this.presentCount,
    required this.absentCount,
  });

  final String registrationNo;
  final String studentName;
  final List<String> attendanceMarks;
  final int presentCount;
  final int absentCount;
}

class _TeacherAttendanceMatrixSection {
  const _TeacherAttendanceMatrixSection({
    required this.subjectId,
    required this.subjectName,
    required this.branch,
    required this.branchId,
    required this.semester,
    required this.semesterId,
    required this.orderedDates,
    required this.rows,
  });

  final String subjectId;
  final String subjectName;
  final String branch;
  final String branchId;
  final String semester;
  final String semesterId;
  final List<String> orderedDates;
  final List<_TeacherAttendanceMatrixRow> rows;
}

class AttendanceService {
  static const String _collection = 'attendance_entries';
  static const Duration _defaultExpiry = Duration(minutes: 2);

  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static bool get isAvailable => Firebase.apps.isNotEmpty;

  static Future<AttendanceUserContext> loadUserContext({
    required String userUid,
  }) async {
    if (!isAvailable) {
      return const AttendanceUserContext(
        isTeacher: false,
        teacherSubjects: <AttendanceSubject>[],
        studentSubjects: <AttendanceSubject>[],
      );
    }

    final doc = await _firestore.collection('users').doc(userUid).get();
    final data = doc.data() ?? const <String, dynamic>{};
    final String role = _asString(data['role']).toLowerCase();
    final String approvalStatus = _asString(
      data['approval_status'],
    ).toLowerCase();
    final bool isTeacher =
        (role == 'teacher' ||
            role == 'faculty' ||
            role == 'professor' ||
            _asBool(data['is_teacher']) ||
            _asBool(data['isTeacher'])) &&
        approvalStatus != 'pending' &&
        approvalStatus != 'rejected';

    final List<AttendanceSubject> teacherSubjects = _parseSubjects(
      data: data,
      idKeys: const [
        'subject_id',
        'teach_subject_id',
        'teacher_subject_id',
        'teacherSubjectId',
      ],
      nameKeys: const [
        'subject_name',
        'teach_subject_name',
        'teacher_subject_name',
        'teacherSubjectName',
      ],
      listKeys: const [
        'subject_ids',
        'subjectIds',
        'teacher_subject_ids',
        'teacherSubjectIds',
        'taught_subject_ids',
        'taughtSubjectIds',
      ],
      listNameKeys: const [
        'subject_names',
        'subjectNames',
        'teacher_subject_names',
        'teacherSubjectNames',
        'taught_subject_names',
        'taughtSubjectNames',
      ],
      objectListKeys: const [
        'subjects',
        'teacher_subjects',
        'teacherSubjects',
        'taught_subjects',
        'taughtSubjects',
      ],
    );

    final List<AttendanceSubject> studentSubjects = _parseSubjects(
      data: data,
      idKeys: const [
        'enrolled_subject_id',
        'enrolledSubjectId',
        'subject_id',
        'subjectId',
      ],
      nameKeys: const [
        'enrolled_subject_name',
        'enrolledSubjectName',
        'subject_name',
        'subjectName',
      ],
      listKeys: const [
        'enrolled_subject_ids',
        'enrolledSubjectIds',
        'subject_ids',
        'subjectIds',
        'student_subject_ids',
        'studentSubjectIds',
      ],
      listNameKeys: const [
        'enrolled_subject_names',
        'enrolledSubjectNames',
        'subject_names',
        'subjectNames',
        'student_subject_names',
        'studentSubjectNames',
      ],
      objectListKeys: const [
        'enrolled_subjects',
        'enrolledSubjects',
        'student_subjects',
        'studentSubjects',
      ],
    );

    final List<AttendanceSubject> resolvedTeacherSubjects = isTeacher
        ? await _hydrateTeacherSubjectsWithContexts(teacherSubjects)
        : teacherSubjects;

    return AttendanceUserContext(
      isTeacher: isTeacher,
      teacherSubjects: resolvedTeacherSubjects,
      studentSubjects: studentSubjects,
    );
  }

  static Future<List<AttendanceOption>> loadBranchOptions() async {
    if (!isAvailable) {
      return const <AttendanceOption>[];
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('branches')
          .get();

      final List<AttendanceOption> items =
          snapshot.docs
              .map(
                (doc) => AttendanceOption(
                  id: doc.id,
                  name: _asString(doc.data()['name'], fallback: 'Unknown'),
                ),
              )
              .where((item) => item.id.trim().isNotEmpty)
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      return items;
    } catch (_) {
      return const <AttendanceOption>[];
    }
  }

  static Future<List<AttendanceOption>> loadSemesterOptions({
    required String branchId,
  }) async {
    if (!isAvailable || branchId.trim().isEmpty) {
      return const <AttendanceOption>[];
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> subCollectionSnapshot =
          await _firestore
              .collection('branches')
              .doc(branchId.trim())
              .collection('semesters')
              .get();

      if (subCollectionSnapshot.docs.isNotEmpty) {
        final List<AttendanceOption> direct =
            subCollectionSnapshot.docs
                .map(
                  (doc) => AttendanceOption(
                    id: doc.id,
                    name: _asString(doc.data()['name'], fallback: 'Semester'),
                  ),
                )
                .where((item) => item.id.trim().isNotEmpty)
                .toList()
              ..sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
        return direct;
      }

      final QuerySnapshot<Map<String, dynamic>> topLevelSnapshot =
          await _firestore
              .collection('semesters')
              .where('branch_id', isEqualTo: branchId.trim())
              .get();

      final List<AttendanceOption> fallback =
          topLevelSnapshot.docs
              .map(
                (doc) => AttendanceOption(
                  id: doc.id,
                  name: _asString(doc.data()['name'], fallback: 'Semester'),
                ),
              )
              .where((item) => item.id.trim().isNotEmpty)
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
      return fallback;
    } catch (_) {
      return const <AttendanceOption>[];
    }
  }

  static Future<List<AttendanceSubject>> loadTeacherSubjectsForContext({
    required List<AttendanceSubject> teacherSubjects,
    required String semesterId,
  }) async {
    if (teacherSubjects.isEmpty || semesterId.trim().isEmpty) {
      return teacherSubjects;
    }

    final String normalizedSemesterId = _normalizeId(semesterId);
    final List<AttendanceSubject> filtered = teacherSubjects
        .where(
          (AttendanceSubject subject) => subject.contexts.any(
            (AttendanceSubjectContext context) =>
                _normalizeId(context.semesterId) == normalizedSemesterId,
          ),
        )
        .toList();
    if (filtered.isEmpty) {
      return teacherSubjects;
    }

    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return filtered;
  }

  static Future<List<AttendanceSubject>> _hydrateTeacherSubjectsWithContexts(
    List<AttendanceSubject> teacherSubjects,
  ) async {
    if (!isAvailable || teacherSubjects.isEmpty) {
      return teacherSubjects;
    }

    final Map<String, AttendanceSubject> baseSubjectsById =
        <String, AttendanceSubject>{
          for (final AttendanceSubject subject in teacherSubjects)
            _normalizeId(subject.id): subject,
        };
    final Map<String, Set<String>> semesterIdsBySubject =
        <String, Set<String>>{};
    final Map<String, String> preferredNames = <String, String>{};

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('syllabus')
          .get();

      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final Set<String> matchedSubjectIds = <String>{};

        final String normalizedDocId = _normalizeId(doc.id);
        if (baseSubjectsById.containsKey(normalizedDocId)) {
          matchedSubjectIds.add(normalizedDocId);
        }

        final String explicitId = _normalizeId(
          _readString(data, const <String>[
            'subject_id',
            'subjectId',
            'teacher_subject_id',
            'teacherSubjectId',
          ]),
        );
        if (explicitId.isNotEmpty && baseSubjectsById.containsKey(explicitId)) {
          matchedSubjectIds.add(explicitId);
        }
        if (matchedSubjectIds.isEmpty) {
          continue;
        }

        final List<String> semesterIds = _readStringList(data, const <String>[
          'for',
          'for_semester_ids',
          'semester_ids',
          'semesterIds',
        ]);
        final String subjectName = _readString(data, const <String>[
          'title',
          'name',
          'subject_name',
          'subjectName',
        ], fallback: doc.id);

        for (final String matchedId in matchedSubjectIds) {
          if (semesterIds.isNotEmpty) {
            semesterIdsBySubject
                .putIfAbsent(matchedId, () => <String>{})
                .addAll(semesterIds);
          }
          if (subjectName.trim().isNotEmpty) {
            preferredNames.putIfAbsent(matchedId, () => subjectName.trim());
          }
        }
      }
    } catch (_) {
      return teacherSubjects;
    }

    final Set<String> targetSemesterIds = <String>{
      for (final Set<String> ids in semesterIdsBySubject.values) ...ids,
    };
    final Map<String, AttendanceSubjectContext> semesterCatalog =
        await _loadSemesterContexts(targetSemesterIds);

    final List<AttendanceSubject> enriched =
        teacherSubjects.map((AttendanceSubject subject) {
          final String normalizedSubjectId = _normalizeId(subject.id);
          final Map<String, AttendanceSubjectContext> dedupedContexts =
              <String, AttendanceSubjectContext>{};

          for (final String rawSemesterId
              in semesterIdsBySubject[normalizedSubjectId] ??
                  const <String>{}) {
            final String normalizedSemesterId = _normalizeId(rawSemesterId);
            final AttendanceSubjectContext resolved =
                semesterCatalog[normalizedSemesterId] ??
                AttendanceSubjectContext(
                  branchId: '',
                  branchName: '',
                  semesterId: rawSemesterId.trim(),
                  semesterName: rawSemesterId.trim(),
                );
            dedupedContexts.putIfAbsent(
              '${_normalizeId(resolved.branchId)}::${_normalizeId(resolved.semesterId)}',
              () => resolved,
            );
          }

          final List<AttendanceSubjectContext> contexts =
              dedupedContexts.values.toList()..sort((a, b) {
                final int branchCompare = a.branchLabel.toLowerCase().compareTo(
                  b.branchLabel.toLowerCase(),
                );
                if (branchCompare != 0) {
                  return branchCompare;
                }
                return a.semesterLabel.toLowerCase().compareTo(
                  b.semesterLabel.toLowerCase(),
                );
              });

          return subject.copyWith(
            name: preferredNames[normalizedSubjectId] ?? subject.name,
            contexts: contexts,
          );
        }).toList()..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );

    return enriched;
  }

  static Future<Map<String, AttendanceSubjectContext>> _loadSemesterContexts(
    Set<String> semesterIds,
  ) async {
    final Set<String> normalizedSemesterIds = semesterIds
        .map((String id) => _normalizeId(id))
        .where((String id) => id.isNotEmpty)
        .toSet();
    if (!isAvailable || normalizedSemesterIds.isEmpty) {
      return const <String, AttendanceSubjectContext>{};
    }

    final Map<String, String> branchNames = <String, String>{};
    try {
      final QuerySnapshot<Map<String, dynamic>> branchesSnapshot =
          await _firestore.collection('branches').get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in branchesSnapshot.docs) {
        branchNames[doc.id] = _readString(doc.data(), const <String>[
          'name',
          'title',
          'branch_name',
          'branchName',
        ], fallback: doc.id);
      }
    } catch (_) {
      // Keep branch labels empty and continue with best-effort semester labels.
    }

    final Map<String, AttendanceSubjectContext> catalog =
        <String, AttendanceSubjectContext>{};

    void mergeSemesterDoc(
      String semesterId,
      Map<String, dynamic> data, {
      String branchIdFallback = '',
    }) {
      final String normalizedSemesterId = _normalizeId(semesterId);
      if (!normalizedSemesterIds.contains(normalizedSemesterId)) {
        return;
      }

      final String branchId = _readString(data, const <String>[
        'branch_id',
        'branchId',
      ], fallback: branchIdFallback);
      final String branchName = _readString(data, const <String>[
        'branch',
        'branch_name',
        'branchName',
      ], fallback: branchNames[branchId] ?? branchId);
      final AttendanceSubjectContext candidate = AttendanceSubjectContext(
        branchId: branchId,
        branchName: branchName,
        semesterId: semesterId.trim(),
        semesterName: _readString(data, const <String>[
          'name',
          'title',
          'semester',
          'semester_name',
        ], fallback: semesterId),
      );

      final AttendanceSubjectContext? existing = catalog[normalizedSemesterId];
      if (_shouldReplaceSemesterContext(existing, candidate)) {
        catalog[normalizedSemesterId] = candidate;
      }
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> groupSnapshot = await _firestore
          .collectionGroup('semesters')
          .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in groupSnapshot.docs) {
        mergeSemesterDoc(
          doc.id,
          doc.data(),
          branchIdFallback: doc.reference.parent.parent?.id ?? '',
        );
      }
    } catch (_) {
      // Collection group may be unavailable in some deployments; fall back.
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> topLevelSnapshot =
          await _firestore.collection('semesters').get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
          in topLevelSnapshot.docs) {
        mergeSemesterDoc(doc.id, doc.data());
      }
    } catch (_) {
      // Best-effort fallback only.
    }

    return catalog;
  }

  static bool _shouldReplaceSemesterContext(
    AttendanceSubjectContext? existing,
    AttendanceSubjectContext candidate,
  ) {
    if (existing == null) {
      return true;
    }

    int score(AttendanceSubjectContext value) {
      int points = 0;
      if (value.semesterName.trim().isNotEmpty &&
          _normalizeId(value.semesterName) != _normalizeId(value.semesterId)) {
        points += 2;
      }
      if (value.branchName.trim().isNotEmpty) {
        points += 2;
      }
      if (value.branchId.trim().isNotEmpty) {
        points += 1;
      }
      return points;
    }

    return score(candidate) > score(existing);
  }

  static Future<AttendanceEntry> createAttendanceEntry({
    required String teacherUid,
    required String teacherName,
    required AttendanceSubject subject,
    required String branch,
    required String branchId,
    required String semester,
    required String semesterId,
    required double generateLatitude,
    required double generateLongitude,
    required double generateAccuracyMeters,
    Duration expiryDuration = _defaultExpiry,
    Duration graceDelay = Duration.zero,
    double allowedRadiusMeters = 50,
  }) async {
    final now = DateTime.now();
    final int startMillis = now.millisecondsSinceEpoch;
    final int expiryMillis = now.add(expiryDuration).millisecondsSinceEpoch;
    final int validForSeconds = expiryDuration.inSeconds;
    final int graceDelaySeconds = graceDelay.inSeconds < 0
        ? 0
        : graceDelay.inSeconds;
    final String dateKey = _dateKey(now);

    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection(_collection)
        .doc();

    await ref.set({
      'created_by_uid': teacherUid,
      'created_by_name': teacherName,
      'subject_id': subject.id,
      'subject_name': subject.name,
      'branch': branch,
      'branch_id': branchId,
      'branchId': branchId,
      'semester': semester,
      'semester_id': semesterId,
      'semesterId': semesterId,
      'teacher_id': teacherUid,
      'teacher_name': teacherName,
      'date_key': dateKey,
      'start_time_millis': startMillis,
      'expiry_time_millis': expiryMillis,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'qr_payload': '',
      'qr_issued_at_millis': startMillis,
      'valid_for_seconds': validForSeconds,
      'grace_delay_seconds': graceDelaySeconds,
      'allowed_radius_meters': allowedRadiusMeters,
      'generate_latitude': generateLatitude,
      'generate_longitude': generateLongitude,
      'generate_accuracy_meters': generateAccuracyMeters,
      'eligible_branch_id': branchId,
      'eligibleBranchId': branchId,
      'eligible_branch_ids': branchId.trim().isEmpty
          ? const <String>[]
          : <String>[branchId],
      'eligibleBranchIds': branchId.trim().isEmpty
          ? const <String>[]
          : <String>[branchId],
      'eligible_semester_id': semesterId,
      'eligibleSemesterId': semesterId,
      'eligible_semester_ids': semesterId.trim().isEmpty
          ? const <String>[]
          : <String>[semesterId],
      'eligibleSemesterIds': semesterId.trim().isEmpty
          ? const <String>[]
          : <String>[semesterId],
      'attendance_scope': <String, dynamic>{
        'teacher_id': teacherUid,
        'teacher_name': teacherName,
        'subject_id': subject.id,
        'subject_name': subject.name,
        'branch_id': branchId,
        'branch_name': branch,
        'semester_id': semesterId,
        'semester_name': semester,
      },
      'students': <String, dynamic>{},
      'present_count': 0,
      'class_conducted': false,
      'is_finalized': false,
      'finalized_at_millis': 0,
    });

    return AttendanceEntry(
      id: ref.id,
      subjectId: subject.id,
      subjectName: subject.name,
      branch: branch,
      branchId: branchId,
      semester: semester,
      semesterId: semesterId,
      teacherId: teacherUid,
      teacherName: teacherName,
      dateKey: dateKey,
      startTimeMillis: startMillis,
      expiryTimeMillis: expiryMillis,
      qrPayload: '',
      eligibleStudentIds: const <String>[],
      eligibleStudentNames: const <String, String>{},
      students: const <String, AttendanceStudentScan>{},
      presentCount: 0,
      classConducted: false,
      isFinalized: false,
      finalizedAtMillis: 0,
      allowedRadiusMeters: allowedRadiusMeters,
      graceDelaySeconds: graceDelaySeconds,
      validForSeconds: validForSeconds,
      generateLatitude: generateLatitude,
      generateLongitude: generateLongitude,
      generateAccuracyMeters: generateAccuracyMeters,
    );
  }

  static Stream<AttendanceEntry?> watchAttendanceEntry(String attendanceId) {
    return _firestore.collection(_collection).doc(attendanceId).snapshots().map(
      (doc) {
        if (!doc.exists) {
          return null;
        }
        return AttendanceEntry.fromFirestore(doc);
      },
    );
  }

  static Future<AttendanceEntry?> extendAttendanceEntryExpiry({
    required String attendanceId,
    required Duration additionalDuration,
  }) async {
    if (additionalDuration.inSeconds <= 0) {
      return null;
    }

    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection(_collection)
        .doc(attendanceId);

    try {
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(ref);
        if (!doc.exists) {
          return;
        }

        final data = doc.data() ?? const <String, dynamic>{};
        if (_asBool(data['is_finalized'])) {
          return;
        }
        final int startTimeMillis = _asInt(data['start_time_millis']);
        final int currentExpiryMillis = _asInt(data['expiry_time_millis']);
        final int baseExpiryMillis = math.max(
          currentExpiryMillis,
          DateTime.now().millisecondsSinceEpoch,
        );
        final int newExpiryMillis =
            baseExpiryMillis + additionalDuration.inMilliseconds;
        final int validForSeconds = startTimeMillis <= 0
            ? _asInt(data['valid_for_seconds']) + additionalDuration.inSeconds
            : ((newExpiryMillis - startTimeMillis) / 1000).ceil();
        transaction.update(ref, {
          'expiry_time_millis': newExpiryMillis,
          'valid_for_seconds': validForSeconds,
          'qr_payload': _asString(data['qr_payload']),
          'updated_at': FieldValue.serverTimestamp(),
        });
      });

      final latest = await ref.get();
      if (!latest.exists) {
        return null;
      }
      return AttendanceEntry.fromFirestore(latest);
    } catch (_) {
      return null;
    }
  }

  static Future<AttendanceEntry?> removeStudentFromAttendance({
    required String attendanceId,
    required String studentUid,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection(_collection)
        .doc(attendanceId);

    try {
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(ref);
        if (!doc.exists) {
          return;
        }

        final data = doc.data() ?? const <String, dynamic>{};
        if (_asBool(data['is_finalized'])) {
          return;
        }

        final Map<String, dynamic> students = Map<String, dynamic>.from(
          (data['students'] as Map?) ?? const {},
        );
        if (!students.containsKey(studentUid)) {
          return;
        }

        students.remove(studentUid);
        final int updatedPresentCount = students.length;

        transaction.update(ref, {
          'students.$studentUid': FieldValue.delete(),
          'present_count': updatedPresentCount,
          'class_conducted': updatedPresentCount > 0,
          'updated_at': FieldValue.serverTimestamp(),
        });
        transaction.delete(ref.collection('scans').doc(studentUid));
      });

      final latest = await ref.get();
      if (!latest.exists) {
        return null;
      }
      return AttendanceEntry.fromFirestore(latest);
    } catch (_) {
      return null;
    }
  }

  static Future<AttendanceEntry?> finalizeAttendanceEntry({
    required String attendanceId,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection(_collection)
        .doc(attendanceId);

    try {
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(ref);
        if (!doc.exists) {
          return;
        }

        final data = doc.data() ?? const <String, dynamic>{};
        if (_asBool(data['is_finalized'])) {
          return;
        }

        final int presentCount = _asInt(data['present_count']);
        transaction.update(ref, {
          'is_finalized': true,
          'finalized_at_millis': DateTime.now().millisecondsSinceEpoch,
          'class_conducted':
              presentCount > 0 || _asBool(data['class_conducted']),
          'updated_at': FieldValue.serverTimestamp(),
        });
      });

      final latest = await ref.get();
      if (!latest.exists) {
        return null;
      }
      return AttendanceEntry.fromFirestore(latest);
    } catch (_) {
      return null;
    }
  }

  static Future<AttendanceMarkResult> markAttendanceFromQr({
    required String encryptedPayload,
    required String studentUid,
    required String studentName,
    required double? studentLatitude,
    required double? studentLongitude,
    required double? studentAccuracyMeters,
    String studentBranchId = '',
    String studentSemesterId = '',
  }) async {
    final payload = AttendanceQrCodec.decode(encryptedPayload);
    if (payload == null) {
      return const AttendanceMarkResult(status: AttendanceMarkStatus.invalidQr);
    }

    return markAttendanceById(
      attendanceId: payload.attendanceId,
      studentUid: studentUid,
      studentName: studentName,
      qrPayload: payload,
      studentLatitude: studentLatitude,
      studentLongitude: studentLongitude,
      studentAccuracyMeters: studentAccuracyMeters,
      studentBranchId: studentBranchId,
      studentSemesterId: studentSemesterId,
    );
  }

  static Future<AttendanceMarkResult> markAttendanceById({
    required String attendanceId,
    required String studentUid,
    required String studentName,
    AttendanceQrPayload? qrPayload,
    required double? studentLatitude,
    required double? studentLongitude,
    required double? studentAccuracyMeters,
    String studentBranchId = '',
    String studentSemesterId = '',
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection(_collection)
        .doc(attendanceId);
    final bool needsStudentDocFallback =
        studentBranchId.trim().isEmpty || studentSemesterId.trim().isEmpty;
    final Map<String, dynamic>? studentData = needsStudentDocFallback
        ? await _loadUserDataByUid(studentUid)
        : null;

    try {
      AttendanceEntry? updatedEntry;
      AttendanceMarkStatus status = AttendanceMarkStatus.unknownError;
      double? distanceMeters;

      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(ref);
        if (!doc.exists) {
          status = AttendanceMarkStatus.attendanceNotFound;
          return;
        }

        final data = doc.data() ?? const <String, dynamic>{};
        if (_asBool(data['is_finalized'])) {
          status = AttendanceMarkStatus.sessionClosed;
          return;
        }
        final String docTeacherId = _asString(data['teacher_id']);
        final String docSubjectId = _asString(data['subject_id']);
        if (qrPayload != null) {
          if (qrPayload.teacherId.isNotEmpty &&
              docTeacherId.isNotEmpty &&
              qrPayload.teacherId != docTeacherId) {
            status = AttendanceMarkStatus.invalidQr;
            return;
          }
          if (qrPayload.subjectId.isNotEmpty &&
              docSubjectId.isNotEmpty &&
              qrPayload.subjectId != docSubjectId) {
            status = AttendanceMarkStatus.invalidQr;
            return;
          }
        }

        final int nowMillis = DateTime.now().millisecondsSinceEpoch;
        final int expiryMillis = _asInt(data['expiry_time_millis']);
        final int graceDelaySeconds = _asInt(data['grace_delay_seconds']);
        final int validUntilMillis = expiryMillis + (graceDelaySeconds * 1000);
        if (nowMillis > validUntilMillis) {
          status = AttendanceMarkStatus.qrExpired;
          return;
        }

        final String entryBranchId = _readString(data, const <String>[
          'branch_id',
          'branchId',
        ]);
        final String entrySemesterId = _readString(data, const <String>[
          'semester_id',
          'semesterId',
        ]);
        if (!_studentMatchesAttendanceContext(
          studentData,
          branchId: entryBranchId,
          semesterId: entrySemesterId,
          studentBranchId: studentBranchId,
          studentSemesterId: studentSemesterId,
        )) {
          status = AttendanceMarkStatus.notEligible;
          return;
        }

        final bool hasGeneratedLocation =
            data.containsKey('generate_latitude') &&
            data.containsKey('generate_longitude');
        final double generatedLatitude = hasGeneratedLocation
            ? _asDouble(data['generate_latitude'])
            : qrPayload?.latitude ?? 0;
        final double generatedLongitude = hasGeneratedLocation
            ? _asDouble(data['generate_longitude'])
            : qrPayload?.longitude ?? 0;
        final double allowedRadiusMeters = _asDouble(
          data['allowed_radius_meters'],
          fallback: qrPayload?.radiusMeters ?? 50,
        );
        final bool requiresLocationGate =
            (generatedLatitude != 0 || generatedLongitude != 0) &&
            allowedRadiusMeters > 0;
        if (requiresLocationGate) {
          if (studentLatitude == null || studentLongitude == null) {
            status = AttendanceMarkStatus.locationUnavailable;
            return;
          }

          distanceMeters = _distanceMeters(
            generatedLatitude,
            generatedLongitude,
            studentLatitude,
            studentLongitude,
          );
          if (distanceMeters! > allowedRadiusMeters) {
            status = AttendanceMarkStatus.outsideAllowedRadius;
            return;
          }
        }

        final Map<String, dynamic> students = Map<String, dynamic>.from(
          (data['students'] as Map?) ?? const {},
        );
        if (students.containsKey(studentUid)) {
          status = AttendanceMarkStatus.alreadyMarked;
          return;
        }

        final scan = AttendanceStudentScan(
          uid: studentUid,
          name: studentName,
          scanTimeMillis: nowMillis,
          latitude: studentLatitude,
          longitude: studentLongitude,
          distanceMeters: distanceMeters,
          accuracyMeters: studentAccuracyMeters,
        );

        transaction.update(ref, {
          'students.$studentUid': scan.toJson(),
          'present_count': FieldValue.increment(1),
          'class_conducted': true,
          'updated_at': FieldValue.serverTimestamp(),
        });

        final scanRef = ref.collection('scans').doc(studentUid);
        transaction.set(scanRef, {
          'uid': scan.uid,
          'name': scan.name,
          'scan_time_millis': scan.scanTimeMillis,
          'start_time_millis': _asInt(data['start_time_millis']),
          'attendance_id': attendanceId,
          'subject_id': _asString(data['subject_id']),
          'subject_name': _asString(data['subject_name']),
          'branch_id': entryBranchId,
          'semester_id': entrySemesterId,
          'date_key': _asString(data['date_key']),
          'scan_latitude': studentLatitude,
          'scan_longitude': studentLongitude,
          'scan_accuracy_meters': studentAccuracyMeters,
          'distance_meters': distanceMeters,
          'allowed_radius_meters': _asDouble(
            data['allowed_radius_meters'],
            fallback: qrPayload?.radiusMeters ?? 50,
          ),
        }, SetOptions(merge: true));

        status = AttendanceMarkStatus.success;
      });

      if (status == AttendanceMarkStatus.success) {
        final latest = await ref.get();
        updatedEntry = latest.exists
            ? AttendanceEntry.fromFirestore(latest)
            : null;
      }

      return AttendanceMarkResult(status: status, entry: updatedEntry);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return const AttendanceMarkResult(
          status: AttendanceMarkStatus.permissionDenied,
        );
      }
      return const AttendanceMarkResult(
        status: AttendanceMarkStatus.unknownError,
      );
    } catch (_) {
      return const AttendanceMarkResult(
        status: AttendanceMarkStatus.unknownError,
      );
    }
  }

  static Future<List<SubjectAttendanceSummary>> buildStudentSummary({
    required String studentUid,
    required List<AttendanceSubject> preferredSubjects,
    String studentBranchId = '',
    String studentSemesterId = '',
    int maxEntries = 1000,
  }) async {
    final bool needsStudentDocFallback =
        studentBranchId.trim().isEmpty || studentSemesterId.trim().isEmpty;
    final Map<String, dynamic>? studentData = needsStudentDocFallback
        ? await _loadUserDataByUid(studentUid)
        : null;
    if (needsStudentDocFallback && studentData == null) {
      return const <SubjectAttendanceSummary>[];
    }

    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('start_time_millis', descending: true)
        .limit(maxEntries)
        .get();

    final Map<String, AttendanceSubject> subjectCatalog =
        <String, AttendanceSubject>{
          for (final subject in preferredSubjects) subject.id: subject,
        };
    final Map<String, Set<String>> totalDaysBySubject = <String, Set<String>>{};
    final Map<String, Set<String>> presentDaysBySubject =
        <String, Set<String>>{};

    for (final doc in snapshot.docs) {
      final entry = AttendanceEntry.fromFirestore(doc);
      if (entry == null) {
        continue;
      }
      if (!_studentMatchesAttendanceContext(
        studentData,
        branchId: entry.branchId,
        semesterId: entry.semesterId,
        studentBranchId: studentBranchId,
        studentSemesterId: studentSemesterId,
      )) {
        continue;
      }

      final subjectId = entry.subjectId;
      if (subjectId.isEmpty) {
        continue;
      }

      totalDaysBySubject
          .putIfAbsent(subjectId, () => <String>{})
          .add(entry.dateKey);
      if (entry.students.containsKey(studentUid)) {
        presentDaysBySubject
            .putIfAbsent(subjectId, () => <String>{})
            .add(entry.dateKey);
      }

      subjectCatalog.putIfAbsent(
        subjectId,
        () => AttendanceSubject(id: subjectId, name: entry.subjectName),
      );
    }

    final List<SubjectAttendanceSummary> summaries =
        <SubjectAttendanceSummary>[];
    for (final entry in subjectCatalog.entries) {
      final subjectId = entry.key;
      final subject = entry.value;
      final totalDays = totalDaysBySubject[subjectId]?.length ?? 0;
      final presentDays = presentDaysBySubject[subjectId]?.length ?? 0;
      if (totalDays == 0 && presentDays == 0) {
        continue;
      }
      summaries.add(
        SubjectAttendanceSummary(
          subjectId: subjectId,
          subjectName: subject.name,
          totalClassDays: totalDays,
          presentDays: presentDays,
        ),
      );
    }

    summaries.sort((a, b) => b.percentage.compareTo(a.percentage));
    return summaries;
  }

  static Future<List<StudentAttendanceHistoryItem>> loadStudentHistory({
    required String studentUid,
    int limit = 60,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> scansSnapshot = await _firestore
        .collectionGroup('scans')
        .where('uid', isEqualTo: studentUid)
        .orderBy('scan_time_millis', descending: true)
        .limit(limit)
        .get();

    final List<StudentAttendanceHistoryItem> history =
        <StudentAttendanceHistoryItem>[];
    for (final doc in scansSnapshot.docs) {
      final data = doc.data();
      history.add(
        StudentAttendanceHistoryItem(
          subjectId: _asString(data['subject_id']),
          subjectName: _asString(data['subject_name'], fallback: 'Subject'),
          scanTimeMillis: _asInt(data['scan_time_millis']),
          sessionStartTimeMillis: _asInt(data['start_time_millis']),
          attendanceId: _asString(data['attendance_id']),
          dateKey: _asString(data['date_key']),
        ),
      );
    }
    return history;
  }

  static Future<List<StudentDailyAttendanceRecord>>
  buildStudentDailyAttendance({
    required String studentUid,
    String studentBranchId = '',
    String studentSemesterId = '',
    int maxEntries = 1200,
  }) async {
    final bool needsStudentDocFallback =
        studentBranchId.trim().isEmpty || studentSemesterId.trim().isEmpty;
    final Map<String, dynamic>? studentData = needsStudentDocFallback
        ? await _loadUserDataByUid(studentUid)
        : null;
    if (needsStudentDocFallback && studentData == null) {
      return const <StudentDailyAttendanceRecord>[];
    }

    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('start_time_millis', descending: true)
        .limit(maxEntries)
        .get();

    final Map<String, int> scheduledByDay = <String, int>{};
    final Map<String, List<StudentAttendanceHistoryItem>> attendedByDay =
        <String, List<StudentAttendanceHistoryItem>>{};

    for (final doc in snapshot.docs) {
      final entry = AttendanceEntry.fromFirestore(doc);
      if (entry == null || entry.dateKey.isEmpty) {
        continue;
      }
      if (!_studentMatchesAttendanceContext(
        studentData,
        branchId: entry.branchId,
        semesterId: entry.semesterId,
        studentBranchId: studentBranchId,
        studentSemesterId: studentSemesterId,
      )) {
        continue;
      }

      scheduledByDay[entry.dateKey] = (scheduledByDay[entry.dateKey] ?? 0) + 1;

      final scan = entry.students[studentUid];
      if (scan == null) {
        continue;
      }

      final attendedClasses = attendedByDay.putIfAbsent(
        entry.dateKey,
        () => <StudentAttendanceHistoryItem>[],
      );
      attendedClasses.add(
        StudentAttendanceHistoryItem(
          subjectId: entry.subjectId,
          subjectName: entry.subjectName,
          scanTimeMillis: scan.scanTimeMillis,
          sessionStartTimeMillis: entry.startTimeMillis,
          attendanceId: entry.id,
          dateKey: entry.dateKey,
        ),
      );
    }

    final List<StudentDailyAttendanceRecord> records =
        <StudentDailyAttendanceRecord>[];
    for (final dateKey in scheduledByDay.keys) {
      final attendedClasses =
          (attendedByDay[dateKey] ?? const <StudentAttendanceHistoryItem>[])
              .toList()
            ..sort(
              (a, b) => b.displayTimeMillis.compareTo(a.displayTimeMillis),
            );
      records.add(
        StudentDailyAttendanceRecord(
          dateKey: dateKey,
          scheduledSessionCount: scheduledByDay[dateKey] ?? 0,
          attendedSessionCount: attendedClasses.length,
          attendedClasses: attendedClasses,
        ),
      );
    }

    records.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return records;
  }

  static Future<List<AttendanceEntry>> loadTeacherSessions({
    required String teacherUid,
    int limit = 200,
  }) async {
    List<AttendanceEntry> entries = <AttendanceEntry>[];

    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('teacher_id', isEqualTo: teacherUid)
          .limit(limit)
          .get();

      entries = snapshot.docs
          .map(AttendanceEntry.fromFirestore)
          .whereType<AttendanceEntry>()
          .toList();
    } on FirebaseException catch (error) {
      if (error.code != 'failed-precondition') {
        rethrow;
      }
    }

    if (entries.length < limit) {
      final int fallbackLimit = math.max(limit * 4, 400);
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('start_time_millis', descending: true)
          .limit(fallbackLimit)
          .get();

      final List<AttendanceEntry> fallbackEntries = snapshot.docs
          .map(AttendanceEntry.fromFirestore)
          .whereType<AttendanceEntry>()
          .where((AttendanceEntry entry) => entry.teacherId == teacherUid)
          .toList();

      final Map<String, AttendanceEntry> merged = <String, AttendanceEntry>{
        for (final AttendanceEntry entry in entries) entry.id: entry,
        for (final AttendanceEntry entry in fallbackEntries) entry.id: entry,
      };
      entries = merged.values.toList();
    }

    entries.sort((a, b) => b.startTimeMillis.compareTo(a.startTimeMillis));
    if (entries.length > limit) {
      return entries.take(limit).toList();
    }
    return entries;
  }

  static Future<List<AttendanceRosterStudent>> loadStudentRosterForContext({
    required String branchId,
    required String semesterId,
    required String subjectId,
  }) async {
    return _loadStudentRosterForContext(
      branchId: branchId,
      semesterId: semesterId,
      subjectId: subjectId,
    );
  }

  static Stream<List<AttendanceEntry>> watchStudentAvailableSessions({
    required String studentUid,
    required String branchId,
    required String semesterId,
    required List<AttendanceSubject> studentSubjects,
  }) {
    if (!isAvailable ||
        studentUid.trim().isEmpty ||
        branchId.trim().isEmpty ||
        semesterId.trim().isEmpty) {
      return const Stream<List<AttendanceEntry>>.empty();
    }

    return _firestore.collection(_collection).snapshots().map((snapshot) {
      final List<AttendanceEntry> sessions =
          snapshot.docs
              .map(AttendanceEntry.fromFirestore)
              .whereType<AttendanceEntry>()
              .where((AttendanceEntry entry) {
                if (entry.isFinalized || entry.isExpired) {
                  return false;
                }
                if (branchId.trim().isNotEmpty &&
                    _normalizeId(entry.branchId) != _normalizeId(branchId)) {
                  return false;
                }
                if (semesterId.trim().isNotEmpty &&
                    _normalizeId(entry.semesterId) !=
                        _normalizeId(semesterId)) {
                  return false;
                }
                if (entry.students.containsKey(studentUid.trim())) {
                  return false;
                }
                return true;
              })
              .toList()
            ..sort((a, b) => b.startTimeMillis.compareTo(a.startTimeMillis));

      return sessions;
    });
  }

  static Future<int> deleteExpiredEmptySessionsForTeacher({
    required String teacherUid,
    int limit = 200,
  }) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('teacher_id', isEqualTo: teacherUid)
        .limit(limit)
        .get();

    int deletedCount = 0;
    for (final doc in snapshot.docs) {
      final AttendanceEntry? entry = AttendanceEntry.fromFirestore(doc);
      if (entry == null || !_shouldAutoDeleteExpiredEmptyEntry(entry)) {
        continue;
      }

      final bool deleted = await deleteAttendanceEntryIfEmpty(
        attendanceId: entry.id,
      );
      if (deleted) {
        deletedCount += 1;
      }
    }

    return deletedCount;
  }

  static Future<bool> deleteAttendanceEntryIfEmpty({
    required String attendanceId,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _firestore
        .collection(_collection)
        .doc(attendanceId);

    try {
      bool shouldDelete = false;
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(ref);
        if (!doc.exists) {
          return;
        }

        final AttendanceEntry? entry = AttendanceEntry.fromFirestore(doc);
        if (entry == null || !_isEmptyUnfinalizedEntry(entry)) {
          return;
        }

        transaction.delete(ref);
        shouldDelete = true;
      });

      if (!shouldDelete) {
        return false;
      }

      final QuerySnapshot<Map<String, dynamic>> scansSnapshot = await ref
          .collection('scans')
          .get();
      if (scansSnapshot.docs.isNotEmpty) {
        final WriteBatch batch = _firestore.batch();
        for (final scanDoc in scansSnapshot.docs) {
          batch.delete(scanDoc.reference);
        }
        await batch.commit();
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<TeacherSubjectReport>> buildTeacherSubjectReport({
    required String teacherUid,
    int maxEntries = 1500,
  }) async {
    final entries = await loadTeacherSessions(
      teacherUid: teacherUid,
      limit: maxEntries,
    );
    return buildTeacherSubjectReportFromEntries(entries);
  }

  static List<TeacherSubjectReport> buildTeacherSubjectReportFromEntries(
    List<AttendanceEntry> entries,
  ) {
    final Map<String, String> subjectName = <String, String>{};
    final Map<String, String> branchName = <String, String>{};
    final Map<String, String> branchIds = <String, String>{};
    final Map<String, String> semesterName = <String, String>{};
    final Map<String, String> semesterIds = <String, String>{};
    final Map<String, Set<String>> classDays = <String, Set<String>>{};
    final Map<String, int> totalPresentScans = <String, int>{};
    final Map<String, int> totalSessionsCreated = <String, int>{};

    for (final entry in entries) {
      if (entry.subjectId.isEmpty) {
        continue;
      }
      final String reportKey = _teacherReportKey(entry);
      subjectName[reportKey] = entry.subjectName;
      branchName[reportKey] = entry.branch;
      branchIds[reportKey] = entry.branchId;
      semesterName[reportKey] = entry.semester;
      semesterIds[reportKey] = entry.semesterId;
      classDays.putIfAbsent(reportKey, () => <String>{}).add(entry.dateKey);
      totalPresentScans[reportKey] =
          (totalPresentScans[reportKey] ?? 0) + entry.presentCount;
      totalSessionsCreated[reportKey] =
          (totalSessionsCreated[reportKey] ?? 0) + 1;
    }

    final List<TeacherSubjectReport> report = <TeacherSubjectReport>[];
    for (final String reportKey in totalSessionsCreated.keys) {
      report.add(
        TeacherSubjectReport(
          subjectId: _firstPart(reportKey),
          subjectName: subjectName[reportKey] ?? 'Subject',
          branch: branchName[reportKey] ?? '',
          branchId: branchIds[reportKey] ?? '',
          semester: semesterName[reportKey] ?? '',
          semesterId: semesterIds[reportKey] ?? '',
          totalSessionsCreated: totalSessionsCreated[reportKey] ?? 0,
          totalClassDays: classDays[reportKey]?.length ?? 0,
          totalPresentScans: totalPresentScans[reportKey] ?? 0,
        ),
      );
    }

    report.sort((a, b) {
      final int bySessions = b.totalSessionsCreated.compareTo(
        a.totalSessionsCreated,
      );
      if (bySessions != 0) {
        return bySessions;
      }
      return a.subjectName.toLowerCase().compareTo(b.subjectName.toLowerCase());
    });
    return report;
  }

  static String buildTeacherReportCsv(List<TeacherSubjectReport> report) {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'Subject ID,Subject Name,Branch,Semester,Sessions Created,Class Days,Total Present Scans,Average Present Per Session',
    );
    for (final item in report) {
      buffer.writeln(
        '${_csv(item.subjectId)},${_csv(item.subjectName)},${_csv(item.branch)},${_csv(item.semester)},${item.totalSessionsCreated},${item.totalClassDays},${item.totalPresentScans},${item.avgPresentPerSession.toStringAsFixed(2)}',
      );
    }
    return buffer.toString();
  }

  static Uint8List? buildTeacherReportExcel(
    List<TeacherSubjectReport> report, {
    DateTime? generatedAt,
  }) {
    if (report.isEmpty) {
      return null;
    }

    final DateTime createdAt = generatedAt ?? DateTime.now();
    final Excel excel = Excel.createExcel();
    const String sheetName = 'Subject Report';
    final String? defaultSheet = excel.getDefaultSheet();
    if (defaultSheet == null) {
      excel[sheetName];
    } else if (defaultSheet != sheetName) {
      excel.rename(defaultSheet, sheetName);
    }
    excel.setDefaultSheet(sheetName);

    final Sheet sheet = excel[sheetName];
    sheet.appendRow(<CellValue>[
      TextCellValue('Subject-wise Attendance Report'),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Generated At'),
      TextCellValue(_exportTimestamp(createdAt)),
    ]);
    sheet.appendRow(const <CellValue>[]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Subject ID'),
      TextCellValue('Subject Name'),
      TextCellValue('Branch'),
      TextCellValue('Semester'),
      TextCellValue('Sessions Created'),
      TextCellValue('Class Days'),
      TextCellValue('Total Present'),
      TextCellValue('Average Present / Session'),
    ]);

    for (final TeacherSubjectReport item in report) {
      sheet.appendRow(<CellValue>[
        TextCellValue(item.subjectId),
        TextCellValue(item.subjectName),
        TextCellValue(item.branch),
        TextCellValue(item.semester),
        IntCellValue(item.totalSessionsCreated),
        IntCellValue(item.totalClassDays),
        IntCellValue(item.totalPresentScans),
        DoubleCellValue(item.avgPresentPerSession),
      ]);
    }

    for (int columnIndex = 0; columnIndex < 8; columnIndex += 1) {
      sheet.setColumnAutoFit(columnIndex);
    }

    final List<int>? bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return Uint8List.fromList(bytes);
  }

  static Future<Uint8List?> buildTeacherAttendanceMatrixExcel(
    List<AttendanceEntry> entries, {
    DateTime? generatedAt,
  }) async {
    final List<_TeacherAttendanceMatrixSection> sections =
        await _buildTeacherAttendanceMatrixSections(entries);
    if (sections.isEmpty) {
      return null;
    }

    final DateTime createdAt = generatedAt ?? DateTime.now();
    final Excel excel = Excel.createExcel();
    final String? defaultSheet = excel.getDefaultSheet();
    final Set<String> usedSheetNames = <String>{};

    for (int index = 0; index < sections.length; index += 1) {
      final _TeacherAttendanceMatrixSection section = sections[index];
      final String sheetName = _buildAttendanceMatrixSheetName(
        section,
        usedSheetNames,
      );
      usedSheetNames.add(sheetName);

      if (index == 0) {
        if (defaultSheet == null) {
          excel[sheetName];
        } else if (defaultSheet != sheetName) {
          excel.rename(defaultSheet, sheetName);
        }
        excel.setDefaultSheet(sheetName);
      } else {
        excel[sheetName];
      }

      final Sheet sheet = excel[sheetName];
      _appendTeacherAttendanceMatrixSheet(
        sheet: sheet,
        section: section,
        generatedAt: createdAt,
      );
    }

    final List<int>? bytes = excel.encode();
    if (bytes == null || bytes.isEmpty) {
      return null;
    }
    return Uint8List.fromList(bytes);
  }

  static Future<String> buildTeacherAttendanceMatrixCsv(
    List<AttendanceEntry> entries,
  ) async {
    final List<_TeacherAttendanceMatrixSection> sections =
        await _buildTeacherAttendanceMatrixSections(entries);
    if (sections.isEmpty) {
      return '';
    }

    final StringBuffer buffer = StringBuffer();
    bool wroteSection = false;

    for (final _TeacherAttendanceMatrixSection section in sections) {
      if (wroteSection) {
        buffer.writeln();
        buffer.writeln();
      }
      wroteSection = true;

      buffer.writeln('Subject,${_csv(section.subjectName)}');
      buffer.writeln('Branch,${_csv(section.branch)}');
      buffer.writeln('Semester,${_csv(section.semester)}');
      buffer.writeln();
      buffer.write('Registration No,Student Name');
      for (final String dateKey in section.orderedDates) {
        buffer.write(',${_csv(dateKey)}');
      }
      buffer.writeln(',Present Count,Absent Count');

      for (final _TeacherAttendanceMatrixRow row in section.rows) {
        buffer.write(_csv(row.registrationNo));
        buffer.write(',${_csv(row.studentName)}');
        for (final String mark in row.attendanceMarks) {
          buffer.write(',${_csv(mark)}');
        }
        buffer.writeln(',${row.presentCount},${row.absentCount}');
      }
    }

    return wroteSection ? buffer.toString() : '';
  }

  static Future<List<DateTime>> loadConductedClassDaysForSubject(
    String subjectId,
  ) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('subject_id', isEqualTo: subjectId)
        .where('class_conducted', isEqualTo: true)
        .get();

    final Set<String> days = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final dateKey = _asString(data['date_key']);
      if (dateKey.isNotEmpty) {
        days.add(dateKey);
      }
    }

    final List<DateTime> parsed =
        days.map(_tryParseDateKey).whereType<DateTime>().toList()
          ..sort((a, b) => a.compareTo(b));
    return parsed;
  }

  static List<AttendanceSubject> _parseSubjects({
    required Map<String, dynamic> data,
    required List<String> idKeys,
    required List<String> nameKeys,
    required List<String> listKeys,
    required List<String> listNameKeys,
    required List<String> objectListKeys,
  }) {
    final List<AttendanceSubject> subjects = <AttendanceSubject>[];
    final Set<String> seen = <String>{};
    final List<String> normalizedNameKeys = <String>[
      ...nameKeys,
      'name',
      'title',
      'subject_name',
      'subjectName',
      'teacher_subject_name',
      'teacherSubjectName',
    ];

    for (int i = 0; i < idKeys.length; i++) {
      final String id = _asString(data[idKeys[i]]);
      if (id.isEmpty) {
        continue;
      }
      final String name = i < nameKeys.length
          ? _asString(data[nameKeys[i]], fallback: 'Subject')
          : 'Subject';
      if (seen.add(id)) {
        subjects.add(AttendanceSubject(id: id, name: name));
      }
    }

    final List<String> listIds = _readStringList(data, listKeys);
    final List<String> listNames = _readStringList(data, listNameKeys);
    for (int i = 0; i < listIds.length; i++) {
      final String id = listIds[i];
      if (id.isEmpty || !seen.add(id)) {
        continue;
      }
      final String name = i < listNames.length
          ? _asString(listNames[i], fallback: 'Subject')
          : 'Subject';
      subjects.add(AttendanceSubject(id: id, name: name));
    }

    for (final key in objectListKeys) {
      final raw = data[key];
      if (raw is! List) {
        continue;
      }
      for (final item in raw) {
        if (item is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(item);
        final id = _readString(map, <String>[
          'id',
          ...idKeys,
          'subject_id',
          'subjectId',
          'teacher_subject_id',
          'teacherSubjectId',
        ]);
        if (id.isEmpty || !seen.add(id)) {
          continue;
        }
        subjects.add(
          AttendanceSubject(
            id: id,
            name: _readString(map, normalizedNameKeys, fallback: 'Subject'),
          ),
        );
      }
    }

    return subjects;
  }

  static String _readString(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final String value = _asString(data[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  static List<String> _readStringList(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
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

  static String _teacherReportKey(AttendanceEntry entry) {
    return '${entry.subjectId}::${entry.branchId}::${entry.semesterId}';
  }

  static String _firstPart(String value) {
    final int index = value.indexOf('::');
    if (index < 0) {
      return value;
    }
    return value.substring(0, index);
  }

  static Future<List<_TeacherAttendanceMatrixSection>>
  _buildTeacherAttendanceMatrixSections(List<AttendanceEntry> entries) async {
    final List<AttendanceEntry> scopedEntries = entries
        .where(
          (AttendanceEntry entry) =>
              entry.subjectId.trim().isNotEmpty &&
              entry.dateKey.trim().isNotEmpty &&
              (entry.classConducted || entry.presentCount > 0),
        )
        .toList();
    if (scopedEntries.isEmpty) {
      return const <_TeacherAttendanceMatrixSection>[];
    }

    final Map<String, List<AttendanceEntry>> grouped =
        <String, List<AttendanceEntry>>{};
    for (final AttendanceEntry entry in scopedEntries) {
      final String key = _teacherReportKey(entry);
      grouped.putIfAbsent(key, () => <AttendanceEntry>[]).add(entry);
    }

    final List<String> sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final List<AttendanceEntry> aEntries = grouped[a] ?? const [];
        final List<AttendanceEntry> bEntries = grouped[b] ?? const [];
        final int aLatest = aEntries.isEmpty
            ? 0
            : aEntries.map((entry) => entry.startTimeMillis).reduce(math.max);
        final int bLatest = bEntries.isEmpty
            ? 0
            : bEntries.map((entry) => entry.startTimeMillis).reduce(math.max);
        return bLatest.compareTo(aLatest);
      });

    final List<_TeacherAttendanceMatrixSection> sections =
        <_TeacherAttendanceMatrixSection>[];
    for (final String key in sortedKeys) {
      final List<AttendanceEntry> groupEntries =
          (grouped[key] ?? const <AttendanceEntry>[]).toList()
            ..sort((a, b) => a.dateKey.compareTo(b.dateKey));
      if (groupEntries.isEmpty) {
        continue;
      }

      final AttendanceEntry first = groupEntries.first;
      final bool everyEntryHasScopedRoster = groupEntries.every(
        (AttendanceEntry entry) => entry.eligibleStudentIds.isNotEmpty,
      );
      final List<String> orderedDates =
          groupEntries.map((entry) => entry.dateKey).toSet().toList()..sort();

      final Map<String, Set<String>> presentByDate = <String, Set<String>>{};
      final Map<String, Set<String>> eligibleByDate = <String, Set<String>>{};
      final Map<String, AttendanceRosterStudent> eligibleRoster =
          <String, AttendanceRosterStudent>{};
      final Map<String, AttendanceRosterStudent> scannedFallback =
          <String, AttendanceRosterStudent>{};

      for (final AttendanceEntry entry in groupEntries) {
        final Set<String> attendees = presentByDate.putIfAbsent(
          entry.dateKey,
          () => <String>{},
        );
        for (final AttendanceStudentScan scan in entry.students.values) {
          final String normalizedUid = scan.uid.trim();
          if (normalizedUid.isEmpty) {
            continue;
          }
          attendees.add(normalizedUid);
          scannedFallback.putIfAbsent(
            normalizedUid,
            () => AttendanceRosterStudent(
              uid: normalizedUid,
              name: scan.name.trim().isEmpty ? normalizedUid : scan.name.trim(),
              registrationNo: '',
            ),
          );
        }

        final Set<String> eligibleSet = eligibleByDate.putIfAbsent(
          entry.dateKey,
          () => <String>{},
        );
        if (entry.eligibleStudentIds.isNotEmpty) {
          for (final String uid in entry.eligibleStudentIds) {
            final String normalizedUid = uid.trim();
            if (normalizedUid.isEmpty) {
              continue;
            }
            eligibleSet.add(normalizedUid);
            eligibleRoster.putIfAbsent(
              normalizedUid,
              () => AttendanceRosterStudent(
                uid: normalizedUid,
                name:
                    entry.eligibleStudentNames[normalizedUid]
                            ?.trim()
                            .isNotEmpty ==
                        true
                    ? entry.eligibleStudentNames[normalizedUid]!.trim()
                    : normalizedUid,
                registrationNo: '',
              ),
            );
          }
        }
      }

      List<AttendanceRosterStudent> roster = await _loadStudentRosterForContext(
        branchId: first.branchId,
        semesterId: first.semesterId,
        subjectId: first.subjectId,
      );
      final Map<String, AttendanceRosterStudent> rosterByUid =
          <String, AttendanceRosterStudent>{
            for (final AttendanceRosterStudent student in roster)
              student.uid.trim(): student,
          };
      if (everyEntryHasScopedRoster && eligibleRoster.isNotEmpty) {
        roster = eligibleRoster.keys
            .map(
              (String uid) => rosterByUid[uid.trim()] ?? eligibleRoster[uid]!,
            )
            .toList();
        rosterByUid
          ..clear()
          ..addEntries(
            roster.map(
              (AttendanceRosterStudent student) =>
                  MapEntry(student.uid.trim(), student),
            ),
          );
      }
      for (final AttendanceRosterStudent student in eligibleRoster.values) {
        rosterByUid.putIfAbsent(student.uid.trim(), () => student);
      }
      for (final AttendanceRosterStudent student in scannedFallback.values) {
        rosterByUid.putIfAbsent(student.uid.trim(), () => student);
      }

      final Map<String, AttendanceRosterStudent> resolvedStudents =
          await _loadRosterStudentsByIds(<String>{
            ...rosterByUid.keys,
            ...eligibleRoster.keys,
            ...scannedFallback.keys,
          });
      for (final AttendanceRosterStudent resolved in resolvedStudents.values) {
        final String normalizedUid = resolved.uid.trim();
        final AttendanceRosterStudent? existing = rosterByUid[normalizedUid];
        if (existing == null) {
          rosterByUid[normalizedUid] = resolved;
          continue;
        }
        rosterByUid[normalizedUid] = AttendanceRosterStudent(
          uid: normalizedUid,
          name: resolved.name.trim().isNotEmpty ? resolved.name : existing.name,
          registrationNo: resolved.registrationNo.trim().isNotEmpty
              ? resolved.registrationNo
              : existing.registrationNo,
        );
      }
      roster = rosterByUid.values.toList();
      if (roster.isEmpty && scannedFallback.isNotEmpty) {
        roster = scannedFallback.values.toList();
      }
      if (roster.isEmpty) {
        continue;
      }

      roster.sort((a, b) {
        final String aKey = a.registrationNo.trim().isEmpty
            ? a.name.toLowerCase()
            : a.registrationNo.toLowerCase();
        final String bKey = b.registrationNo.trim().isEmpty
            ? b.name.toLowerCase()
            : b.registrationNo.toLowerCase();
        return aKey.compareTo(bKey);
      });

      final List<_TeacherAttendanceMatrixRow> rows =
          <_TeacherAttendanceMatrixRow>[];
      for (final AttendanceRosterStudent student in roster) {
        final String normalizedStudentUid = student.uid.trim();
        int presentCount = 0;
        int absentCount = 0;
        final List<String> attendanceMarks = <String>[];

        for (final String dateKey in orderedDates) {
          final Set<String> eligibleStudentsForDate =
              eligibleByDate[dateKey] ?? const <String>{};
          final bool isEligibleForDate =
              eligibleStudentsForDate.isEmpty ||
              eligibleStudentsForDate.contains(normalizedStudentUid);
          final bool wasPresent =
              presentByDate[dateKey]?.contains(normalizedStudentUid) == true;
          if (!isEligibleForDate) {
            attendanceMarks.add('-');
            continue;
          }
          if (wasPresent) {
            presentCount += 1;
          } else {
            absentCount += 1;
          }
          attendanceMarks.add(wasPresent ? 'P' : 'A');
        }

        rows.add(
          _TeacherAttendanceMatrixRow(
            registrationNo: student.registrationNo,
            studentName: student.name,
            attendanceMarks: attendanceMarks,
            presentCount: presentCount,
            absentCount: absentCount,
          ),
        );
      }

      sections.add(
        _TeacherAttendanceMatrixSection(
          subjectId: first.subjectId,
          subjectName: first.subjectName,
          branch: first.branch,
          branchId: first.branchId,
          semester: first.semester,
          semesterId: first.semesterId,
          orderedDates: orderedDates,
          rows: rows,
        ),
      );
    }

    return sections;
  }

  static Future<List<AttendanceRosterStudent>> _loadStudentRosterForContext({
    required String branchId,
    required String semesterId,
    required String subjectId,
  }) async {
    if (!isAvailable || subjectId.trim().isEmpty) {
      return const <AttendanceRosterStudent>[];
    }

    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      if (branchId.trim().isNotEmpty) {
        snapshot = await _firestore
            .collection('users')
            .where('branch_id', isEqualTo: branchId.trim())
            .get();
      } else {
        snapshot = await _firestore.collection('users').get();
      }
    } catch (_) {
      snapshot = await _firestore.collection('users').get();
    }

    final Map<String, AttendanceRosterStudent> roster =
        <String, AttendanceRosterStudent>{};
    for (final doc in snapshot.docs) {
      final Map<String, dynamic> data = doc.data();
      final String userBranchId = _readString(data, const <String>[
        'branch_id',
        'branchId',
      ]);
      final String userSemesterId = _readString(data, const <String>[
        'semester_id',
        'semesterId',
      ]);

      if (branchId.trim().isNotEmpty &&
          _normalizeId(userBranchId) != _normalizeId(branchId)) {
        continue;
      }
      if (semesterId.trim().isNotEmpty &&
          _normalizeId(userSemesterId) != _normalizeId(semesterId)) {
        continue;
      }
      if (!_isLikelyStudentUser(data)) {
        continue;
      }
      if (!_userHasSubject(data, subjectId)) {
        continue;
      }

      final String uid = _readString(data, const <String>[
        'uid',
      ], fallback: doc.id);
      if (uid.trim().isEmpty) {
        continue;
      }
      roster[uid] = AttendanceRosterStudent(
        uid: uid,
        name: _readString(data, const <String>[
          'name',
          'full_name',
          'display_name',
          'username',
        ], fallback: uid),
        registrationNo: _readString(data, const <String>[
          'registration_no',
          'registrationNo',
          'roll_no',
          'rollNo',
        ]),
      );
    }

    return roster.values.toList();
  }

  static Future<Map<String, AttendanceRosterStudent>> _loadRosterStudentsByIds(
    Iterable<String> userIds,
  ) async {
    if (!isAvailable) {
      return const <String, AttendanceRosterStudent>{};
    }

    final List<String> normalizedIds = userIds
        .map((String uid) => uid.trim())
        .where((String uid) => uid.isNotEmpty)
        .toSet()
        .toList();
    if (normalizedIds.isEmpty) {
      return const <String, AttendanceRosterStudent>{};
    }

    final Map<String, AttendanceRosterStudent> rosterByUid =
        <String, AttendanceRosterStudent>{};
    final Set<String> unresolvedIds = normalizedIds.toSet();

    try {
      for (int index = 0; index < normalizedIds.length; index += 10) {
        final int chunkEnd = math.min(index + 10, normalizedIds.length);
        final List<String> chunk = normalizedIds.sublist(index, chunkEnd);
        if (chunk.isEmpty) {
          continue;
        }

        final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
            in snapshot.docs) {
          final AttendanceRosterStudent? student = _userDocToRosterStudent(doc);
          if (student == null) {
            continue;
          }
          rosterByUid[student.uid.trim()] = student;
          unresolvedIds.remove(student.uid.trim());
          unresolvedIds.remove(doc.id.trim());
        }
      }
    } catch (_) {
      // Fall through to per-uid lookup when batched document-id reads fail.
    }

    for (final String uid in unresolvedIds.toList()) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
            .collection('users')
            .doc(uid)
            .get();
        if (doc.exists) {
          final AttendanceRosterStudent? student = _userDocToRosterStudent(doc);
          if (student != null) {
            rosterByUid[student.uid.trim()] = student;
            continue;
          }
        }

        final QuerySnapshot<Map<String, dynamic>> fallbackSnapshot =
            await _firestore
                .collection('users')
                .where('uid', isEqualTo: uid)
                .limit(1)
                .get();
        if (fallbackSnapshot.docs.isEmpty) {
          continue;
        }

        final AttendanceRosterStudent? student = _userDocToRosterStudent(
          fallbackSnapshot.docs.first,
        );
        if (student != null) {
          rosterByUid[student.uid.trim()] = student;
        }
      } catch (_) {
        continue;
      }
    }

    return rosterByUid;
  }

  static AttendanceRosterStudent? _userDocToRosterStudent(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic>? data = doc.data();
    if (data == null) {
      return null;
    }

    final String uid = _readString(data, const <String>[
      'uid',
    ], fallback: doc.id).trim();
    if (uid.isEmpty) {
      return null;
    }

    return AttendanceRosterStudent(
      uid: uid,
      name: _readString(data, const <String>[
        'name',
        'full_name',
        'display_name',
        'username',
      ], fallback: uid),
      registrationNo: _readString(data, const <String>[
        'registration_no',
        'registrationNo',
        'roll_no',
        'rollNo',
      ]),
    );
  }

  static Future<Map<String, dynamic>?> _loadUserDataByUid(String uid) async {
    final String normalizedUid = uid.trim();
    if (!isAvailable || normalizedUid.isEmpty) {
      return null;
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> directDoc = await _firestore
          .collection('users')
          .doc(normalizedUid)
          .get();
      if (directDoc.exists) {
        final Map<String, dynamic>? data = directDoc.data();
        if (data != null) {
          return data;
        }
      }
    } catch (_) {
      // Fall back to uid-field lookup below.
    }

    try {
      final QuerySnapshot<Map<String, dynamic>> fallbackSnapshot =
          await _firestore
              .collection('users')
              .where('uid', isEqualTo: normalizedUid)
              .limit(1)
              .get();
      if (fallbackSnapshot.docs.isNotEmpty) {
        return fallbackSnapshot.docs.first.data();
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static bool _studentMatchesAttendanceContext(
    Map<String, dynamic>? studentData, {
    required String branchId,
    required String semesterId,
    String studentBranchId = '',
    String studentSemesterId = '',
  }) {
    final Map<String, dynamic> normalizedStudentData =
        studentData ?? const <String, dynamic>{};
    final String resolvedBranchId = studentBranchId.trim().isNotEmpty
        ? studentBranchId.trim()
        : _readString(normalizedStudentData, const <String>[
            'branch_id',
            'branchId',
          ]);
    final String resolvedSemesterId = studentSemesterId.trim().isNotEmpty
        ? studentSemesterId.trim()
        : _readString(normalizedStudentData, const <String>[
            'semester_id',
            'semesterId',
          ]);

    if (branchId.trim().isNotEmpty && resolvedBranchId.isEmpty) {
      return false;
    }
    if (semesterId.trim().isNotEmpty && resolvedSemesterId.isEmpty) {
      return false;
    }
    if (branchId.trim().isNotEmpty &&
        _normalizeId(resolvedBranchId) != _normalizeId(branchId)) {
      return false;
    }
    if (semesterId.trim().isNotEmpty &&
        _normalizeId(resolvedSemesterId) != _normalizeId(semesterId)) {
      return false;
    }
    return true;
  }

  static bool _isLikelyStudentUser(Map<String, dynamic> data) {
    final String role = _readString(data, const <String>[
      'role',
      'requested_role',
      'requestedRole',
    ]).toLowerCase();
    if (role == 'developer') {
      return false;
    }
    if (role == 'teacher' ||
        role == 'faculty' ||
        role == 'professor' ||
        role == 'teacher_pending') {
      return false;
    }
    if (_asBool(data['is_teacher']) || _asBool(data['isTeacher'])) {
      return false;
    }
    if (role == 'student') {
      return true;
    }

    return _readString(data, const <String>[
          'registration_no',
          'registrationNo',
          'roll_no',
          'rollNo',
        ]).isNotEmpty &&
        _readString(data, const <String>['branch_id', 'branchId']).isNotEmpty &&
        _readString(data, const <String>[
          'semester_id',
          'semesterId',
        ]).isNotEmpty;
  }

  static bool _userHasSubject(Map<String, dynamic> data, String subjectId) {
    if (subjectId.trim().isEmpty) {
      return false;
    }

    final List<AttendanceSubject> subjects = _parseSubjects(
      data: data,
      idKeys: const <String>[
        'enrolled_subject_id',
        'enrolledSubjectId',
        'student_subject_id',
        'studentSubjectId',
        'subject_id',
        'subjectId',
      ],
      nameKeys: const <String>[
        'enrolled_subject_name',
        'enrolledSubjectName',
        'student_subject_name',
        'studentSubjectName',
        'subject_name',
        'subjectName',
      ],
      listKeys: const <String>[
        'enrolled_subject_ids',
        'enrolledSubjectIds',
        'student_subject_ids',
        'studentSubjectIds',
        'subject_ids',
        'subjectIds',
      ],
      listNameKeys: const <String>[
        'enrolled_subject_names',
        'enrolledSubjectNames',
        'student_subject_names',
        'studentSubjectNames',
        'subject_names',
        'subjectNames',
      ],
      objectListKeys: const <String>[
        'enrolled_subjects',
        'enrolledSubjects',
        'student_subjects',
        'studentSubjects',
        'subjects',
      ],
    );

    return subjects.any(
      (AttendanceSubject subject) =>
          _normalizeId(subject.id) == _normalizeId(subjectId),
    );
  }

  static bool _isEmptyUnfinalizedEntry(AttendanceEntry entry) {
    return !entry.isFinalized &&
        entry.presentCount <= 0 &&
        entry.students.isEmpty;
  }

  static bool _shouldAutoDeleteExpiredEmptyEntry(AttendanceEntry entry) {
    return _isEmptyUnfinalizedEntry(entry) && entry.isExpired;
  }

  static String _normalizeId(String raw) => raw.trim().toLowerCase();

  static String _csv(String raw) {
    final escaped = raw.replaceAll('"', '""');
    return '"$escaped"';
  }

  static void _appendTeacherAttendanceMatrixSheet({
    required Sheet sheet,
    required _TeacherAttendanceMatrixSection section,
    required DateTime generatedAt,
  }) {
    sheet.appendRow(<CellValue>[
      TextCellValue('Subject'),
      TextCellValue(section.subjectName),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Subject ID'),
      TextCellValue(section.subjectId),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Branch'),
      TextCellValue(section.branch),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Semester'),
      TextCellValue(section.semester),
    ]);
    sheet.appendRow(<CellValue>[
      TextCellValue('Generated At'),
      TextCellValue(_exportTimestamp(generatedAt)),
    ]);
    sheet.appendRow(const <CellValue>[]);

    final List<CellValue> header = <CellValue>[
      TextCellValue('Registration No'),
      TextCellValue('Student Name'),
      ...section.orderedDates.map((String dateKey) => TextCellValue(dateKey)),
      TextCellValue('Present Count'),
      TextCellValue('Absent Count'),
    ];
    sheet.appendRow(header);

    for (final _TeacherAttendanceMatrixRow row in section.rows) {
      sheet.appendRow(<CellValue>[
        TextCellValue(row.registrationNo),
        TextCellValue(row.studentName),
        ...row.attendanceMarks.map((String mark) => TextCellValue(mark)),
        IntCellValue(row.presentCount),
        IntCellValue(row.absentCount),
      ]);
    }

    for (int columnIndex = 0; columnIndex < header.length; columnIndex += 1) {
      sheet.setColumnAutoFit(columnIndex);
    }
  }

  static String _buildAttendanceMatrixSheetName(
    _TeacherAttendanceMatrixSection section,
    Set<String> usedSheetNames,
  ) {
    final String rawBase = <String>[
      section.subjectName,
      section.semester,
    ].where((String value) => value.trim().isNotEmpty).join(' - ');
    String base = rawBase.trim();
    if (base.isEmpty) {
      base = section.subjectId.trim().isEmpty
          ? 'Attendance Register'
          : section.subjectId.trim();
    }

    base = base.replaceAll(RegExp(r'[:\\/?*\\[\\]]'), ' ');
    base = base.replaceAll(RegExp(r'\\s+'), ' ').trim();
    if (base.isEmpty) {
      base = 'Attendance Register';
    }
    if (base.length > 31) {
      base = base.substring(0, 31).trim();
    }
    if (base.isEmpty) {
      base = 'Sheet';
    }

    String candidate = base;
    int counter = 2;
    while (usedSheetNames.contains(candidate)) {
      final String suffix = ' ($counter)';
      final int maxBaseLength = 31 - suffix.length;
      String truncatedBase = base;
      if (truncatedBase.length > maxBaseLength) {
        truncatedBase = truncatedBase.substring(0, maxBaseLength).trim();
      }
      if (truncatedBase.isEmpty) {
        truncatedBase = 'Sheet';
      }
      candidate = '$truncatedBase$suffix';
      counter += 1;
    }

    return candidate;
  }

  static String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _exportTimestamp(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');
    final String second = date.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  static DateTime? _tryParseDateKey(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return DateTime.tryParse(trimmed);
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
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
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

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.trim().toLowerCase() == 'true';
    }
    if (value is num) {
      return value != 0;
    }
    return false;
  }

  static double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadiusMeters = 6371000;
    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);
    final double rLat1 = _toRadians(lat1);
    final double rLat2 = _toRadians(lat2);

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) *
            math.sin(dLon / 2) *
            math.cos(rLat1) *
            math.cos(rLat2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double _toRadians(double degree) {
    return degree * (math.pi / 180);
  }
}
