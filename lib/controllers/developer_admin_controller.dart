import 'dart:async';

import 'package:academic_async/controllers/get_user_data.dart';
import 'package:academic_async/models/developer_admin_models.dart';
import 'package:academic_async/models/event_record.dart';
import 'package:academic_async/models/syllabus_record.dart';
import 'package:academic_async/services/event_sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';

class DeveloperAdminController extends GetxController {
  final RxBool isAccessGranted = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString usersErrorMessage = ''.obs;
  final RxString requestsErrorMessage = ''.obs;
  final RxString eventsErrorMessage = ''.obs;
  final RxString syllabusErrorMessage = ''.obs;
  final RxBool isPerformingAction = false.obs;

  final RxList<AdminUserRecord> allUsers = <AdminUserRecord>[].obs;
  final RxList<AdminUserRecord> students = <AdminUserRecord>[].obs;
  final RxList<TeacherSignupRequestRecord> pendingTeacherRequests =
      <TeacherSignupRequestRecord>[].obs;
  final RxList<EventRecord> allEvents = <EventRecord>[].obs;
  final RxList<SyllabusRecord> allSyllabus = <SyllabusRecord>[].obs;

  final RxString userSearchQuery = ''.obs;
  final RxString userRoleFilter = 'all'.obs;
  final RxString eventSearchQuery = ''.obs;
  final RxString syllabusSearchQuery = ''.obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _requestsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _eventsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _syllabusSub;
  Worker? _roleWatcher;
  Timer? _usersRetryTimer;
  Timer? _requestsRetryTimer;
  Timer? _eventsRetryTimer;
  Timer? _syllabusRetryTimer;

  @override
  void onInit() {
    super.onInit();
    _watchAccessAndStart();
  }

  @override
  void onClose() {
    _roleWatcher?.dispose();
    _disposeStreams();
    super.onClose();
  }

  int get studentCount => students.length;
  int get totalUsersCount => allUsers.length;
  int get teacherCount => allUsers.where((u) => u.isLikelyTeacher).length;
  int get pendingRequestCount => pendingTeacherRequests.length;
  int get totalEventsCount => allEvents.length;
  int get totalSyllabusCount => allSyllabus.length;

  List<AdminUserRecord> get visibleUsers {
    final query = userSearchQuery.value.trim().toLowerCase();
    final filter = userRoleFilter.value.trim().toLowerCase();

    return allUsers.where((user) {
      if (!_matchesRoleFilter(user, filter)) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return user.displayName.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          user.uid.toLowerCase().contains(query) ||
          user.registrationNo.toLowerCase().contains(query) ||
          user.branch.toLowerCase().contains(query) ||
          user.semester.toLowerCase().contains(query) ||
          user.role.toLowerCase().contains(query);
    }).toList();
  }

  List<EventRecord> get visibleEvents {
    final query = eventSearchQuery.value.trim().toLowerCase();
    if (query.isEmpty) {
      return allEvents.toList();
    }
    return allEvents.where((event) {
      final dateText =
          '${event.date.day}/${event.date.month}/${event.date.year}';
      return event.description.toLowerCase().contains(query) ||
          event.type.toLowerCase().contains(query) ||
          event.branch.toLowerCase().contains(query) ||
          event.semester.toLowerCase().contains(query) ||
          event.id.toLowerCase().contains(query) ||
          dateText.contains(query);
    }).toList();
  }

  List<SyllabusRecord> get visibleSyllabus {
    final query = syllabusSearchQuery.value.trim().toLowerCase();
    if (query.isEmpty) {
      return allSyllabus.toList();
    }

    return allSyllabus.where((record) {
      if (record.title.toLowerCase().contains(query) ||
          record.id.toLowerCase().contains(query)) {
        return true;
      }

      for (final semesterId in record.forSemesterIds) {
        if (semesterId.toLowerCase().contains(query)) {
          return true;
        }
      }

      for (final unit in record.units) {
        if (unit.title.toLowerCase().contains(query) ||
            unit.id.toLowerCase().contains(query)) {
          return true;
        }
        for (final topic in unit.topics) {
          if (topic.title.toLowerCase().contains(query) ||
              topic.id.toLowerCase().contains(query) ||
              topic.details.toLowerCase().contains(query)) {
            return true;
          }
        }
      }
      return false;
    }).toList();
  }

  void updateUserSearch(String text) {
    userSearchQuery.value = text;
  }

  void updateUserRoleFilter(String filter) {
    final normalized = filter.trim().toLowerCase();
    if (normalized.isEmpty) {
      userRoleFilter.value = 'all';
      return;
    }
    userRoleFilter.value = normalized;
  }

  void updateEventSearch(String text) {
    eventSearchQuery.value = text;
  }

  void updateSyllabusSearch(String text) {
    syllabusSearchQuery.value = text;
  }

  Future<void> approveTeacherRequest(TeacherSignupRequestRecord request) async {
    if (isPerformingAction.value) {
      return;
    }

    isPerformingAction.value = true;
    try {
      final firestore = FirebaseFirestore.instance;
      final requestRef = firestore
          .collection('teacher_signup_requests')
          .doc(request.uid);
      final userRef = firestore.collection('users').doc(request.uid);

      await firestore.runTransaction((transaction) async {
        final userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
          throw StateError('User not found');
        }

        transaction.set(requestRef, {
          'status': 'approved',
          'request_status': 'approved',
          'reviewed_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.set(userRef, {
          'role': 'teacher',
          'requested_role': 'teacher',
          'requestedRole': 'teacher',
          'approval_status': 'approved',
          'approvalStatus': 'approved',
          'is_teacher': true,
          'isTeacher': true,
          if (request.teacherSubjectIds.isNotEmpty)
            'teacher_subject_ids': request.teacherSubjectIds,
          if (request.teacherSubjectIds.isNotEmpty)
            'teacherSubjectIds': request.teacherSubjectIds,
          if (request.teacherSubjectNames.isNotEmpty)
            'teacher_subject_names': request.teacherSubjectNames,
          if (request.teacherSubjectNames.isNotEmpty)
            'teacherSubjectNames': request.teacherSubjectNames,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      Get.snackbar('Developer', 'Teacher request approved');
    } catch (_) {
      Get.snackbar('Developer', 'Unable to approve request');
    } finally {
      isPerformingAction.value = false;
    }
  }

  Future<void> rejectTeacherRequest(TeacherSignupRequestRecord request) async {
    if (isPerformingAction.value) {
      return;
    }

    isPerformingAction.value = true;
    try {
      final firestore = FirebaseFirestore.instance;
      final requestRef = firestore
          .collection('teacher_signup_requests')
          .doc(request.uid);
      final userRef = firestore.collection('users').doc(request.uid);

      await firestore.runTransaction((transaction) async {
        transaction.set(requestRef, {
          'status': 'rejected',
          'request_status': 'rejected',
          'reviewed_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        transaction.set(userRef, {
          'role': 'teacher_pending',
          'requested_role': 'teacher',
          'requestedRole': 'teacher',
          'approval_status': 'rejected',
          'approvalStatus': 'rejected',
          'is_teacher': false,
          'isTeacher': false,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      Get.snackbar('Developer', 'Teacher request rejected');
    } catch (_) {
      Get.snackbar('Developer', 'Unable to reject request');
    } finally {
      isPerformingAction.value = false;
    }
  }

  Future<void> upsertUser({
    required String uid,
    required String name,
    required String email,
    required String registrationNo,
    required String branch,
    required String branchId,
    required String semester,
    required String semesterId,
    required String role,
    required String requestedRole,
    required String approvalStatus,
    required bool isTeacher,
    required List<String> teacherSubjectIds,
    required List<String> teacherSubjectNames,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      Get.snackbar('Validation', 'User UID is required');
      return;
    }
    if (isPerformingAction.value) {
      return;
    }

    final normalizedRole = role.trim().toLowerCase();
    final normalizedRequestedRole = requestedRole.trim().toLowerCase();
    final normalizedApprovalStatus = approvalStatus.trim().toLowerCase();
    final normalizedSubjectIds = teacherSubjectIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final normalizedSubjectNames = teacherSubjectNames
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    isPerformingAction.value = true;
    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(normalizedUid);
      final existing = await ref.get();

      await ref.set({
        'name': name.trim(),
        'email': email.trim(),
        'registration_no': registrationNo.trim(),
        'registrationNo': registrationNo.trim(),
        'branch': branch.trim(),
        'branch_id': branchId.trim(),
        'branchId': branchId.trim(),
        'semester': semester.trim(),
        'semester_id': semesterId.trim(),
        'semesterId': semesterId.trim(),
        'role': normalizedRole,
        'requested_role': normalizedRequestedRole,
        'requestedRole': normalizedRequestedRole,
        'approval_status': normalizedApprovalStatus,
        'approvalStatus': normalizedApprovalStatus,
        'is_teacher': isTeacher,
        'isTeacher': isTeacher,
        'teacher_subject_ids': normalizedSubjectIds,
        'teacherSubjectIds': normalizedSubjectIds,
        'teacher_subject_names': normalizedSubjectNames,
        'teacherSubjectNames': normalizedSubjectNames,
        if (!existing.exists) 'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Get.snackbar(
        'Developer',
        existing.exists ? 'User updated' : 'User created',
      );
    } catch (_) {
      Get.snackbar('Developer', 'Unable to save user');
    } finally {
      isPerformingAction.value = false;
    }
  }

  Future<void> upsertStudent({
    required String uid,
    required String name,
    required String email,
    required String registrationNo,
    required String branch,
    required String branchId,
    required String semester,
    required String semesterId,
  }) async {
    await upsertUser(
      uid: uid,
      name: name,
      email: email,
      registrationNo: registrationNo,
      branch: branch,
      branchId: branchId,
      semester: semester,
      semesterId: semesterId,
      role: 'student',
      requestedRole: 'student',
      approvalStatus: 'approved',
      isTeacher: false,
      teacherSubjectIds: const <String>[],
      teacherSubjectNames: const <String>[],
    );
  }

  Future<void> deleteUser(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty || isPerformingAction.value) {
      return;
    }

    isPerformingAction.value = true;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(normalizedUid)
          .delete();
      Get.snackbar('Developer', 'User deleted');
    } catch (_) {
      Get.snackbar('Developer', 'Unable to delete user');
    } finally {
      isPerformingAction.value = false;
    }
  }

  Future<void> deleteStudent(String uid) => deleteUser(uid);

  Future<void> upsertEvent({
    required String id,
    required DateTime date,
    required String description,
    required String type,
    required String branch,
    required String branchId,
    required String semester,
    required String semesterId,
  }) async {
    if (isPerformingAction.value) {
      return;
    }

    final normalizedId = id.trim();
    final normalizedType = type.trim().isEmpty ? 'event' : type.trim();
    final normalizedDescription = description.trim();
    final normalizedBranch = branch.trim();
    final normalizedBranchId = branchId.trim();
    final normalizedSemester = semester.trim();
    final normalizedSemesterId = semesterId.trim();
    final normalizedDate = DateTime(date.year, date.month, date.day);

    isPerformingAction.value = true;
    try {
      final collection = FirebaseFirestore.instance.collection('events');
      final docRef = normalizedId.isEmpty
          ? collection.doc()
          : collection.doc(normalizedId);
      final existing = await docRef.get();

      await docRef.set({
        'date': Timestamp.fromDate(normalizedDate),
        'event_date': Timestamp.fromDate(normalizedDate),
        'eventDate': Timestamp.fromDate(normalizedDate),
        'description': normalizedDescription,
        'title': normalizedDescription,
        'type': normalizedType,
        'event_type': normalizedType,
        'branch': normalizedBranch,
        'branch_id': normalizedBranchId,
        'branchId': normalizedBranchId,
        'semester': normalizedSemester,
        'semester_id': normalizedSemesterId,
        'semesterId': normalizedSemesterId,
        if (!existing.exists) 'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      Get.snackbar(
        'Developer',
        existing.exists ? 'Event updated' : 'Event created',
      );
      await _refreshLocalEventCache();
    } catch (_) {
      Get.snackbar('Developer', 'Unable to save event');
    } finally {
      isPerformingAction.value = false;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    final normalizedId = eventId.trim();
    if (normalizedId.isEmpty || isPerformingAction.value) {
      return;
    }

    isPerformingAction.value = true;
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(normalizedId)
          .delete();
      await _refreshLocalEventCache();
      Get.snackbar('Developer', 'Event deleted');
    } catch (_) {
      Get.snackbar('Developer', 'Unable to delete event');
    } finally {
      isPerformingAction.value = false;
    }
  }

  Future<void> upsertSyllabus({
    required String id,
    required String title,
    required List<String> semesterIds,
    required List<Map<String, dynamic>> units,
  }) async {
    if (isPerformingAction.value) {
      return;
    }

    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      Get.snackbar('Validation', 'Subject title is required');
      return;
    }
    if (units.isEmpty) {
      Get.snackbar('Validation', 'Add at least one unit');
      return;
    }

    final normalizedSemesterIds = semesterIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();

    isPerformingAction.value = true;
    try {
      final collection = FirebaseFirestore.instance.collection('syllabus');
      final normalizedId = id.trim();
      final docRef = normalizedId.isEmpty
          ? collection.doc()
          : collection.doc(normalizedId);
      final existing = await docRef.get();

      await docRef.set({
        'title': normalizedTitle,
        'for': normalizedSemesterIds,
        'unit': units,
      });

      Get.snackbar(
        'Developer',
        existing.exists ? 'Syllabus updated' : 'Syllabus created',
      );
    } catch (_) {
      Get.snackbar('Developer', 'Unable to save syllabus');
    } finally {
      isPerformingAction.value = false;
    }
  }

  Future<void> deleteSyllabus(String syllabusId) async {
    final normalizedId = syllabusId.trim();
    if (normalizedId.isEmpty || isPerformingAction.value) {
      return;
    }

    isPerformingAction.value = true;
    try {
      await FirebaseFirestore.instance
          .collection('syllabus')
          .doc(normalizedId)
          .delete();
      Get.snackbar('Developer', 'Syllabus deleted');
    } catch (_) {
      Get.snackbar('Developer', 'Unable to delete syllabus');
    } finally {
      isPerformingAction.value = false;
    }
  }

  void _watchAccessAndStart() {
    if (!Get.isRegistered<UserDataController>()) {
      isAccessGranted.value = false;
      errorMessage.value = 'User profile is unavailable';
      return;
    }

    final userData = Get.find<UserDataController>();
    _roleWatcher = ever<String>(userData.role, (_) {
      _refreshAccess(userData);
    });
    _refreshAccess(userData);
  }

  void _refreshAccess(UserDataController userData) {
    if (Firebase.apps.isEmpty) {
      isAccessGranted.value = false;
      errorMessage.value = 'Firebase is not initialized';
      usersErrorMessage.value = '';
      requestsErrorMessage.value = '';
      eventsErrorMessage.value = '';
      syllabusErrorMessage.value = '';
      _disposeStreams();
      return;
    }

    final bool isDeveloper = userData.isDeveloper;
    isAccessGranted.value = isDeveloper;
    if (!isDeveloper) {
      errorMessage.value = 'Developer access required';
      _disposeStreams();
      allUsers.clear();
      students.clear();
      pendingTeacherRequests.clear();
      allEvents.clear();
      allSyllabus.clear();
      usersErrorMessage.value = '';
      requestsErrorMessage.value = '';
      eventsErrorMessage.value = '';
      syllabusErrorMessage.value = '';
      return;
    }

    errorMessage.value = '';
    _startUsersListener();
    _startTeacherRequestsListener();
    _startEventsListener();
    _startSyllabusListener();
  }

  void _startUsersListener() {
    _usersRetryTimer?.cancel();
    _usersSub?.cancel();
    _usersSub = null;

    _usersSub = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen(
          (snapshot) {
            usersErrorMessage.value = '';
            final parsed = snapshot.docs.map(AdminUserRecord.fromDoc).toList()
              ..sort(
                (a, b) => a.displayName.toLowerCase().compareTo(
                  b.displayName.toLowerCase(),
                ),
              );
            allUsers.assignAll(parsed);
            final onlyStudents = parsed.where((u) => u.isStudent).toList()
              ..sort(
                (a, b) => a.displayName.toLowerCase().compareTo(
                  b.displayName.toLowerCase(),
                ),
              );
            students.assignAll(onlyStudents);
          },
          onError: (_) {
            usersErrorMessage.value = 'Unable to load users';
            _usersSub?.cancel();
            _usersSub = null;
            _usersRetryTimer = Timer(const Duration(seconds: 2), () {
              if (isAccessGranted.value) {
                _startUsersListener();
              }
            });
          },
        );
  }

  void _startTeacherRequestsListener() {
    _requestsRetryTimer?.cancel();
    _requestsSub?.cancel();
    _requestsSub = null;

    _requestsSub = FirebaseFirestore.instance
        .collection('teacher_signup_requests')
        .snapshots()
        .listen(
          (snapshot) {
            requestsErrorMessage.value = '';
            final parsed =
                snapshot.docs.map(TeacherSignupRequestRecord.fromDoc).where((
                  item,
                ) {
                  final normalized = item.status.trim().toLowerCase();
                  return normalized.isEmpty ||
                      normalized == 'pending' ||
                      normalized == 'requested';
                }).toList()..sort(
                  (a, b) => b.requestedAtMillis.compareTo(a.requestedAtMillis),
                );
            pendingTeacherRequests.assignAll(parsed);
          },
          onError: (_) {
            requestsErrorMessage.value = 'Unable to load teacher requests';
            _requestsSub?.cancel();
            _requestsSub = null;
            _requestsRetryTimer = Timer(const Duration(seconds: 2), () {
              if (isAccessGranted.value) {
                _startTeacherRequestsListener();
              }
            });
          },
        );
  }

  void _startEventsListener() {
    _eventsRetryTimer?.cancel();
    _eventsSub?.cancel();
    _eventsSub = null;

    _eventsSub = FirebaseFirestore.instance
        .collection('events')
        .snapshots()
        .listen(
          (snapshot) {
            eventsErrorMessage.value = '';
            final parsed =
                snapshot.docs
                    .map((doc) => EventRecord.fromFirestore(doc.id, doc.data()))
                    .whereType<EventRecord>()
                    .toList()
                  ..sort((a, b) => b.date.compareTo(a.date));
            allEvents.assignAll(parsed);
          },
          onError: (_) {
            eventsErrorMessage.value = 'Unable to load events';
            _eventsSub?.cancel();
            _eventsSub = null;
            _eventsRetryTimer = Timer(const Duration(seconds: 2), () {
              if (isAccessGranted.value) {
                _startEventsListener();
              }
            });
          },
        );
  }

  void _startSyllabusListener() {
    _syllabusRetryTimer?.cancel();
    _syllabusSub?.cancel();
    _syllabusSub = null;

    _syllabusSub = FirebaseFirestore.instance
        .collection('syllabus')
        .snapshots()
        .listen(
          (snapshot) {
            syllabusErrorMessage.value = '';
            final parsed =
                snapshot.docs
                    .map(
                      (doc) => SyllabusRecord.fromFirestore(doc.id, doc.data()),
                    )
                    .whereType<SyllabusRecord>()
                    .toList()
                  ..sort(
                    (a, b) =>
                        a.title.toLowerCase().compareTo(b.title.toLowerCase()),
                  );
            allSyllabus.assignAll(parsed);
          },
          onError: (_) {
            syllabusErrorMessage.value = 'Unable to load syllabus';
            _syllabusSub?.cancel();
            _syllabusSub = null;
            _syllabusRetryTimer = Timer(const Duration(seconds: 2), () {
              if (isAccessGranted.value) {
                _startSyllabusListener();
              }
            });
          },
        );
  }

  bool _matchesRoleFilter(AdminUserRecord user, String filter) {
    switch (filter) {
      case 'student':
        return user.isStudent;
      case 'teacher':
        return user.isLikelyTeacher;
      case 'developer':
        return user.isDeveloper;
      case 'pending':
        return user.approvalStatus.trim().toLowerCase() == 'pending' ||
            user.role.trim().toLowerCase() == 'teacher_pending';
      default:
        return true;
    }
  }

  List<String> parseListInput(String raw) {
    return raw
        .split(RegExp(r'[,;\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  void _disposeStreams() {
    _usersSub?.cancel();
    _requestsSub?.cancel();
    _eventsSub?.cancel();
    _syllabusSub?.cancel();
    _usersRetryTimer?.cancel();
    _requestsRetryTimer?.cancel();
    _eventsRetryTimer?.cancel();
    _syllabusRetryTimer?.cancel();
    _usersSub = null;
    _requestsSub = null;
    _eventsSub = null;
    _syllabusSub = null;
    _usersRetryTimer = null;
    _requestsRetryTimer = null;
    _eventsRetryTimer = null;
    _syllabusRetryTimer = null;
  }

  Future<void> _refreshLocalEventCache() async {
    try {
      await EventSyncService.syncEvents(forceFull: true, sideEffects: true);
    } catch (_) {
      // Best-effort cache refresh only.
    }
  }
}
