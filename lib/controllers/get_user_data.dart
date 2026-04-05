import 'dart:async';

import 'package:academic_async/controllers/auth_controller.dart';
import 'package:academic_async/services/event_cache_service.dart';
import 'package:academic_async/services/event_sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class UserDataController extends GetxController {
  final RxString name = ''.obs;
  final RxString email = ''.obs;
  final RxString profilePictureUrl = ''.obs;
  final RxList<String> teacherSubjectIds = <String>[].obs;
  final RxList<String> teacherSubjectNames = <String>[].obs;
  final RxString registrationNo = ''.obs;
  final RxString branch = ''.obs;
  final RxString branchId = ''.obs;
  final RxString semester = ''.obs;
  final RxString semesterId = ''.obs;
  final RxString role = ''.obs;
  final RxString requestedRole = ''.obs;
  final RxString approvalStatus = ''.obs;
  final RxBool isTeacher = false.obs;
  final RxBool isProfileLoaded = false.obs;
  String _lastContextScopedSyncKey = '';

  bool get isDeveloper => role.value.trim().toLowerCase() == 'developer';
  bool get isTeacherProfile {
    final String normalizedRole = role.value.trim().toLowerCase();
    return isTeacher.value ||
        normalizedRole == 'teacher' ||
        normalizedRole == 'faculty' ||
        normalizedRole == 'professor' ||
        normalizedRole == 'teacher_pending';
  }

  @override
  void onInit() {
    super.onInit();
    if (Get.isRegistered<AuthController>()) {
      final AuthController authController = Get.find<AuthController>();
      ever(authController.user, (user) {
        if (user == null) {
          clear();
        } else {
          loadUserDataFromUid(user.uid);
        }
      });

      final currentUser = authController.user.value;
      if (currentUser != null) {
        loadUserDataFromUid(currentUser.uid);
      }
    }
  }

  Future<void> loadUserDataFromUid(String uid) async {
    if (Firebase.apps.isEmpty) {
      isProfileLoaded.value = true;
      return;
    }

    try {
      final DocumentReference<Map<String, dynamic>> userRef = FirebaseFirestore
          .instance
          .collection('users')
          .doc(uid);
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final Map<String, dynamic>? data = userDoc.data();
        _applyUserMap(data);
      } else {
        // Fallback: if user docs use random ids, resolve by email.
        final authUser = Get.isRegistered<AuthController>()
            ? Get.find<AuthController>().user.value
            : null;
        final String? userEmail = authUser?.email;
        if (userEmail != null && userEmail.isNotEmpty) {
          final QuerySnapshot<Map<String, dynamic>> query =
              await FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: userEmail)
                  .limit(1)
                  .get();
          if (query.docs.isNotEmpty) {
            final Map<String, dynamic> data = query.docs.first.data();
            _applyUserMap(data);
            await userRef.set({
              'name': name.value,
              'email': email.value,
              'teacher_subject_ids': teacherSubjectIds.toList(),
              'teacherSubjectIds': teacherSubjectIds.toList(),
              'teacher_subject_names': teacherSubjectNames.toList(),
              'teacherSubjectNames': teacherSubjectNames.toList(),
              'registration_no': registrationNo.value,
              'registrationNo': registrationNo.value,
              'branch': branch.value,
              'branch_id': branchId.value,
              'branchId': branchId.value,
              'semester': semester.value,
              'semester_id': semesterId.value,
              'semesterId': semesterId.value,
              'role': role.value,
              'requested_role': requestedRole.value,
              'requestedRole': requestedRole.value,
              'approval_status': approvalStatus.value,
              'approvalStatus': approvalStatus.value,
              'is_teacher': isTeacher.value,
              'isTeacher': isTeacher.value,
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      }
    } catch (_) {
      // Intentionally silent: UI can fallback to auth email if Firestore read fails.
    }

    if (name.value.isEmpty && Get.isRegistered<AuthController>()) {
      final authUser = Get.find<AuthController>().user.value;
      name.value =
          authUser?.displayName ??
          authUser?.email?.split('@').first ??
          'Student';
      email.value = authUser?.email ?? email.value;
    }

    isProfileLoaded.value = true;

    await EventCacheService.saveUserContext(
      branchId: branchId.value,
      semesterId: semesterId.value,
    );
    unawaited(_syncEventsForCurrentContext(uid));
  }

  void clear() {
    name.value = '';
    email.value = '';
    profilePictureUrl.value = '';
    teacherSubjectIds.clear();
    teacherSubjectNames.clear();
    registrationNo.value = '';
    branch.value = '';
    branchId.value = '';
    semester.value = '';
    semesterId.value = '';
    role.value = '';
    requestedRole.value = '';
    approvalStatus.value = '';
    isTeacher.value = false;
    isProfileLoaded.value = false;
    _lastContextScopedSyncKey = '';
    unawaited(EventCacheService.clearUserContext());
  }

  Future<void> _syncEventsForCurrentContext(String uid) async {
    final syncKey = '$uid|${branchId.value}|${semesterId.value}';
    if (_lastContextScopedSyncKey == syncKey) {
      return;
    }
    _lastContextScopedSyncKey = syncKey;

    try {
      await EventSyncService.syncEvents(forceFull: false, sideEffects: true);
    } catch (error, stackTrace) {
      debugPrint('Context scoped event sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> updateCurrentProfile({
    required String name,
    String? registrationNo,
    String? branch,
    String? branchId,
    String? semester,
    String? semesterId,
    List<String>? teacherSubjectIds,
    List<String>? teacherSubjectNames,
  }) async {
    if (Firebase.apps.isEmpty) {
      return false;
    }

    final AuthController? authController = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    final authUser = authController?.user.value;
    final String uid = authUser?.uid ?? '';
    if (uid.isEmpty) {
      return false;
    }

    final String resolvedName = name.trim().isEmpty
        ? this.name.value
        : name.trim();
    final Map<String, dynamic> payload = <String, dynamic>{
      'name': resolvedName,
      'updated_at': FieldValue.serverTimestamp(),
    };

    if (isTeacherProfile) {
      final List<String> resolvedSubjectIds = _normalizeStringList(
        teacherSubjectIds ?? this.teacherSubjectIds.toList(),
      );
      final List<String> resolvedSubjectNames = _normalizeStringList(
        teacherSubjectNames ?? this.teacherSubjectNames.toList(),
      );
      payload.addAll(<String, dynamic>{
        'teacher_subject_ids': resolvedSubjectIds,
        'teacherSubjectIds': resolvedSubjectIds,
        'teacher_subject_names': resolvedSubjectNames,
        'teacherSubjectNames': resolvedSubjectNames,
      });
    } else {
      final String resolvedRegistrationNo =
          (registrationNo ?? this.registrationNo.value).trim();
      final String resolvedBranch = (branch ?? this.branch.value).trim();
      final String resolvedBranchId = (branchId ?? this.branchId.value).trim();
      final String resolvedSemester = (semester ?? this.semester.value).trim();
      final String resolvedSemesterId = (semesterId ?? this.semesterId.value)
          .trim();

      payload.addAll(<String, dynamic>{
        'registration_no': resolvedRegistrationNo,
        'registrationNo': resolvedRegistrationNo,
        'branch': resolvedBranch,
        'branch_id': resolvedBranchId,
        'branchId': resolvedBranchId,
        'semester': resolvedSemester,
        'semester_id': resolvedSemesterId,
        'semesterId': resolvedSemesterId,
      });
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(payload, SetOptions(merge: true));

    if (authUser != null &&
        resolvedName.isNotEmpty &&
        resolvedName != (authUser.displayName ?? '').trim()) {
      await authUser.updateDisplayName(resolvedName);
    }

    await loadUserDataFromUid(uid);
    return true;
  }

  void _applyUserMap(Map<String, dynamic>? data) {
    if (data == null) {
      return;
    }
    name.value = _asString(data['name']);
    email.value = _asString(data['email']);
    teacherSubjectIds.assignAll(
      _asStringList(
        data['teacher_subject_ids'],
        fallback: _asStringList(data['teacherSubjectIds']),
      ),
    );
    teacherSubjectNames.assignAll(
      _asStringList(
        data['teacher_subject_names'],
        fallback: _asStringList(data['teacherSubjectNames']),
      ),
    );
    final dynamic regNo = data['registration_no'] ?? data['registrationNo'];
    if (regNo is int) {
      registrationNo.value = regNo.toString();
    } else if (regNo is String) {
      registrationNo.value = regNo;
    } else {
      registrationNo.value = '';
    }
    branch.value = _asString(data['branch']);
    branchId.value = _asString(
      data['branch_id'],
      fallback: _asString(data['branchId']),
    );
    semester.value = _asString(data['semester']);
    semesterId.value = _asString(
      data['semester_id'],
      fallback: _asString(data['semesterId']),
    );
    role.value = _asString(data['role']);
    requestedRole.value = _asString(
      data['requested_role'],
      fallback: _asString(data['requestedRole']),
    );
    approvalStatus.value = _asString(
      data['approval_status'],
      fallback: _asString(data['approvalStatus']),
    );
    isTeacher.value = _asBool(data['is_teacher']) || _asBool(data['isTeacher']);
    profilePictureUrl.value = _asString(
      data['profilePictureUrl'],
      fallback: _asString(data['profile_picture_url']),
    );
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

  List<String> _asStringList(
    dynamic value, {
    List<String> fallback = const [],
  }) {
    if (value is! List) {
      return fallback;
    }
    return _normalizeStringList(value);
  }

  List<String> _normalizeStringList(Iterable<dynamic> values) {
    return values
        .map((value) => _asString(value))
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }
}
