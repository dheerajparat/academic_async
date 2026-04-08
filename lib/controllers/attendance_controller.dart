import 'dart:async';

import 'package:academic_async/controllers/auth_controller.dart';
import 'package:academic_async/controllers/get_user_data.dart';
import 'package:academic_async/models/attendance_models.dart';
import 'package:academic_async/services/attendance_location_service.dart';
import 'package:academic_async/services/attendance_lock_service.dart';
import 'package:academic_async/services/attendance_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class AttendanceController extends GetxController {
  final RxBool isBootstrapping = false.obs;
  final RxBool isTeacher = false.obs;
  final RxString errorMessage = ''.obs;

  final RxList<AttendanceOption> branchOptions = <AttendanceOption>[].obs;
  final RxList<AttendanceOption> semesterOptions = <AttendanceOption>[].obs;
  final RxList<AttendanceSubject> teacherSubjects = <AttendanceSubject>[].obs;
  final RxList<AttendanceSubject> scopedTeacherSubjects =
      <AttendanceSubject>[].obs;
  final RxList<AttendanceSubject> studentSubjects = <AttendanceSubject>[].obs;
  final RxList<AttendanceRosterStudent> eligibleStudents =
      <AttendanceRosterStudent>[].obs;
  final RxList<String> selectedEligibleStudentIds = <String>[].obs;
  final RxString selectedBranchId = ''.obs;
  final RxString selectedBranchName = ''.obs;
  final RxString selectedSemesterId = ''.obs;
  final RxString selectedSemesterName = ''.obs;
  final RxString selectedSubjectId = ''.obs;
  final RxBool isLoadingAttendanceContext = false.obs;

  final Rxn<AttendanceEntry> activeEntry = Rxn<AttendanceEntry>();
  final RxString selectedTeacherSessionId = ''.obs;
  final RxInt activeQrSecondsLeft = 0.obs;
  final RxBool isGeneratingQr = false.obs;
  final RxBool isExtendingQr = false.obs;
  final RxBool isMutatingTeacherSession = false.obs;
  final RxInt qrValidityMinutes = 2.obs;
  final RxInt qrGraceDelaySeconds = 0.obs;
  final RxInt liveClockMillis = DateTime.now().millisecondsSinceEpoch.obs;

  final RxBool isProcessingScan = false.obs;
  final RxString lastScanMessage = ''.obs;
  final RxList<AttendanceEntry> availableStudentSessions =
      <AttendanceEntry>[].obs;

  final RxList<SubjectAttendanceSummary> studentSummaries =
      <SubjectAttendanceSummary>[].obs;
  final RxList<StudentDailyAttendanceRecord> studentDailyRecords =
      <StudentDailyAttendanceRecord>[].obs;
  final RxList<StudentAttendanceHistoryItem> studentHistory =
      <StudentAttendanceHistoryItem>[].obs;
  final RxBool isLoadingStudentData = false.obs;

  final RxList<AttendanceEntry> teacherSessions = <AttendanceEntry>[].obs;
  final RxList<TeacherSubjectReport> teacherReport =
      <TeacherSubjectReport>[].obs;
  final RxBool isLoadingTeacherReport = false.obs;
  final RxBool isExportingTeacherReport = false.obs;

  StreamSubscription<AttendanceEntry?>? _activeEntrySub;
  StreamSubscription<List<AttendanceEntry>>? _studentAvailableSessionsSub;
  Timer? _qrTicker;
  Timer? _liveClockTicker;
  Worker? _authWatcher;
  Worker? _userContextWatcher;
  String _autoCleanupSessionId = '';
  String _lastStudentContextKey = '';
  int _lastLockSnackbarMillis = 0;
  int _lastDeviceLockFailureMessageMillis = 0;
  int _lastDeviceLockSyncMillis = 0;
  bool _isEnforcingDeviceLock = false;
  bool? _pendingDeviceLockState;
  bool? _lastSyncedDeviceLockState;

  AuthController? _authController;
  UserDataController? _userDataController;

  String get _currentUid => _authController?.user.value?.uid ?? '';

  String get _currentUserName {
    final fromProfile = _userDataController?.name.value ?? '';
    if (fromProfile.trim().isNotEmpty) {
      return fromProfile.trim();
    }
    final authName = _authController?.user.value?.displayName ?? '';
    if (authName.trim().isNotEmpty) {
      return authName.trim();
    }
    final email = _authController?.user.value?.email ?? '';
    if (email.trim().isNotEmpty) {
      return email.trim().split('@').first;
    }
    return 'User';
  }

  AttendanceSubject? get selectedTeacherSubject {
    final selected = selectedSubjectId.value.trim();
    if (selected.isEmpty) {
      return null;
    }
    for (final subject in scopedTeacherSubjects) {
      if (subject.id == selected) {
        return subject;
      }
    }
    for (final subject in teacherSubjects) {
      if (subject.id == selected) {
        return subject;
      }
    }
    return null;
  }

  List<AttendanceSubject> get createSessionSubjects {
    if (scopedTeacherSubjects.isNotEmpty) {
      return scopedTeacherSubjects.toList();
    }
    return teacherSubjects.toList();
  }

  List<AttendanceSubjectContext> get selectedTeacherSubjectContexts =>
      selectedTeacherSubject?.contexts ?? const <AttendanceSubjectContext>[];

  List<AttendanceRosterStudent> get selectedEligibleStudents {
    final Set<String> selected = selectedEligibleStudentIds.toSet();
    return eligibleStudents
        .where(
          (AttendanceRosterStudent student) => selected.contains(student.uid),
        )
        .toList();
  }

  bool get areAllEligibleStudentsSelected =>
      eligibleStudents.isNotEmpty &&
      eligibleStudents.every(
        (AttendanceRosterStudent student) =>
            selectedEligibleStudentIds.contains(student.uid),
      );

  List<AttendanceStudentScan> get liveStudents =>
      activeEntry.value?.studentsSorted ?? const <AttendanceStudentScan>[];

  int get livePresentCount => activeEntry.value?.presentCount ?? 0;

  AttendanceEntry? get selectedTeacherSession {
    final String selectedId = selectedTeacherSessionId.value.trim();
    if (selectedId.isEmpty) {
      return activeEntry.value ??
          (teacherSessions.isEmpty ? null : teacherSessions.first);
    }

    final AttendanceEntry? active = activeEntry.value;
    if (active != null && active.id == selectedId) {
      return active;
    }

    for (final session in teacherSessions) {
      if (session.id == selectedId) {
        return session;
      }
    }
    return active;
  }

  List<AttendanceStudentScan> get selectedTeacherSessionStudents =>
      selectedTeacherSession?.studentsSorted ?? const <AttendanceStudentScan>[];

  int get selectedTeacherSessionPresentCount =>
      selectedTeacherSession?.presentCount ?? 0;

  bool get isSelectedTeacherSessionLive {
    final session = selectedTeacherSession;
    if (session == null) {
      return false;
    }
    return !session.isFinalized &&
        session.validUntilMillis > liveClockMillis.value;
  }

  int get selectedTeacherSessionSecondsLeft {
    final session = selectedTeacherSession;
    if (session == null || session.isFinalized) {
      return 0;
    }
    final int millisLeft = session.validUntilMillis - liveClockMillis.value;
    if (millisLeft <= 0) {
      return 0;
    }
    return (millisLeft / 1000).ceil();
  }

  bool get hasActiveQr {
    final entry = activeEntry.value;
    if (entry == null) {
      return false;
    }
    return !entry.isFinalized && activeQrSecondsLeft.value > 0;
  }

  bool get hasLiveStudentSession {
    for (final AttendanceEntry session in availableStudentSessions) {
      if (!session.isFinalized &&
          session.validUntilMillis > liveClockMillis.value) {
        return true;
      }
    }
    return false;
  }

  bool get hasLiveTeacherSession {
    for (final AttendanceEntry session in teacherSessions) {
      if (!session.isFinalized &&
          session.validUntilMillis > liveClockMillis.value) {
        return true;
      }
    }

    final AttendanceEntry? active = activeEntry.value;
    if (active != null &&
        !active.isFinalized &&
        active.validUntilMillis > liveClockMillis.value) {
      return true;
    }
    return false;
  }

  bool get isAttendanceLockActive {
    if (isTeacher.value) {
      return hasLiveTeacherSession;
    }
    return hasLiveStudentSession;
  }

  int get attendanceLockSecondsLeft {
    if (!isAttendanceLockActive) {
      return 0;
    }
    if (isTeacher.value) {
      int maxSecondsLeft = 0;
      for (final AttendanceEntry session in teacherSessions) {
        if (session.isFinalized) {
          continue;
        }
        final int millisLeft = session.validUntilMillis - liveClockMillis.value;
        if (millisLeft <= 0) {
          continue;
        }
        final int secondsLeft = (millisLeft / 1000).ceil();
        if (secondsLeft > maxSecondsLeft) {
          maxSecondsLeft = secondsLeft;
        }
      }

      final AttendanceEntry? active = activeEntry.value;
      if (active != null && !active.isFinalized) {
        final int activeMillisLeft =
            active.validUntilMillis - liveClockMillis.value;
        if (activeMillisLeft > 0) {
          final int activeSecondsLeft = (activeMillisLeft / 1000).ceil();
          if (activeSecondsLeft > maxSecondsLeft) {
            maxSecondsLeft = activeSecondsLeft;
          }
        }
      }
      return maxSecondsLeft;
    }

    int maxSecondsLeft = 0;
    for (final AttendanceEntry session in availableStudentSessions) {
      if (session.isFinalized) {
        continue;
      }
      final int millisLeft = session.validUntilMillis - liveClockMillis.value;
      if (millisLeft <= 0) {
        continue;
      }
      final int secondsLeft = (millisLeft / 1000).ceil();
      if (secondsLeft > maxSecondsLeft) {
        maxSecondsLeft = secondsLeft;
      }
    }
    return maxSecondsLeft;
  }

  String get attendanceLockDurationLabel =>
      _formatDuration(attendanceLockSecondsLeft);

  bool canPerformProtectedAction({
    String actionLabel = 'leaving the app',
    bool showMessage = true,
  }) {
    if (!isAttendanceLockActive) {
      return true;
    }
    if (showMessage) {
      showAttendanceLockMessage(actionLabel: actionLabel);
    }
    return false;
  }

  void showAttendanceLockMessage({String actionLabel = 'leaving the app'}) {
    final int nowMillis = DateTime.now().millisecondsSinceEpoch;
    if (nowMillis - _lastLockSnackbarMillis < 1200) {
      return;
    }
    _lastLockSnackbarMillis = nowMillis;

    final int secondsLeft = attendanceLockSecondsLeft;
    final String message = secondsLeft > 0
        ? 'Live attendance active. Wait ${_formatDuration(secondsLeft)} before $actionLabel.'
        : 'Live attendance active. You cannot $actionLabel right now.';
    Get.snackbar(
      'Attendance lock',
      message,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  static const double attendanceRadiusMeters = 50;

  List<int> get qrValidityMinuteOptions => const <int>[1, 2, 3, 5, 10, 15];
  List<int> get qrExtendMinuteOptions => const <int>[1, 2, 5];
  List<int> get qrGraceDelaySecondOptions => const <int>[
    0,
    15,
    30,
    45,
    60,
    90,
    120,
  ];

  void setQrValidityMinutes(int value) {
    final int normalized = value.clamp(1, 60);
    qrValidityMinutes.value = normalized;
  }

  void setQrGraceDelaySeconds(int value) {
    final int normalized = value.clamp(0, 600);
    qrGraceDelaySeconds.value = normalized;
  }

  double get overallStudentPercentage {
    final int totalDays = studentDailyRecords.length;
    if (totalDays <= 0) {
      return 0;
    }
    final int presentDays = studentDailyRecords
        .where((e) => e.wasPresent)
        .length;
    return (presentDays / totalDays) * 100;
  }

  int get totalTeacherSessionsCreated => teacherSessions.length;

  int get totalTeacherStudentsPresent =>
      teacherSessions.fold<int>(0, (sum, entry) => sum + entry.presentCount);

  int get totalTeacherDaysCovered =>
      teacherSessions.map((entry) => entry.dateKey).toSet().length;

  void _bindUserContextWatcher() {
    final userData = _userDataController;
    if (userData == null) {
      return;
    }

    _userContextWatcher?.dispose();
    _userContextWatcher = everAll(
      [userData.branchId, userData.semesterId, userData.isProfileLoaded],
      (_) {
        final String uid = _currentUid;
        if (uid.isEmpty || !userData.isProfileLoaded.value) {
          return;
        }

        if (isTeacher.value) {
          if (selectedSubjectId.value.trim().isEmpty ||
              selectedBranchId.value.trim().isEmpty ||
              selectedSemesterId.value.trim().isEmpty) {
            unawaited(_loadTeacherAttendanceContextOptions());
          }
          return;
        }

        final String contextKey =
            '$uid|${userData.branchId.value}|${userData.semesterId.value}';
        if (_lastStudentContextKey == contextKey) {
          return;
        }
        _lastStudentContextKey = contextKey;
        _bindStudentAvailableSessions();
        unawaited(refreshStudentData());
      },
    );
  }

  @override
  void onInit() {
    super.onInit();
    _startLiveClockTicker();
    _authController = Get.isRegistered<AuthController>()
        ? Get.find<AuthController>()
        : null;
    _userDataController = Get.isRegistered<UserDataController>()
        ? Get.find<UserDataController>()
        : null;
    _bindUserContextWatcher();

    final auth = _authController;
    if (auth != null) {
      _authWatcher = ever(auth.user, (_) {
        unawaited(initialize());
      });
    }

    unawaited(initialize());
    unawaited(_enforceDeviceAttendanceLock());
  }

  @override
  void onClose() {
    unawaited(AttendanceLockService.setAttendanceLock(false));
    _authWatcher?.dispose();
    _userContextWatcher?.dispose();
    _activeEntrySub?.cancel();
    _studentAvailableSessionsSub?.cancel();
    _qrTicker?.cancel();
    _liveClockTicker?.cancel();
    super.onClose();
  }

  Future<void> initialize() async {
    final uid = _currentUid;
    if (uid.isEmpty || !AttendanceService.isAvailable) {
      _clearState();
      return;
    }

    isBootstrapping.value = true;
    errorMessage.value = '';

    try {
      final context = await AttendanceService.loadUserContext(userUid: uid);
      isTeacher.value = context.isTeacher;
      teacherSubjects.assignAll(context.teacherSubjects);
      studentSubjects.assignAll(context.studentSubjects);

      if (isTeacher.value) {
        _lastStudentContextKey = '';
        _unbindStudentAvailableSessions();
        await _loadTeacherAttendanceContextOptions();
        await refreshTeacherReport();
      } else {
        _lastStudentContextKey = '';
        selectedSubjectId.value = '';
        scopedTeacherSubjects.clear();
        eligibleStudents.clear();
        selectedEligibleStudentIds.clear();
        branchOptions.clear();
        semesterOptions.clear();
        selectedBranchId.value = '';
        selectedBranchName.value = '';
        selectedSemesterId.value = '';
        selectedSemesterName.value = '';
        _bindStudentAvailableSessions();
        await refreshStudentData();
      }
    } catch (_) {
      errorMessage.value = 'Unable to load attendance configuration.';
    } finally {
      isBootstrapping.value = false;
      unawaited(_enforceDeviceAttendanceLock());
    }
  }

  void selectTeacherSubject(String subjectId) {
    selectedSubjectId.value = subjectId.trim();
    unawaited(_refreshContextOptionsForSelectedSubject());
  }

  Future<void> selectAttendanceBranch(String branchId) async {
    final String normalizedId = branchId.trim();
    final AttendanceOption? match = branchOptions.firstWhereOrNull(
      (AttendanceOption option) => option.id == normalizedId,
    );
    selectedBranchId.value = normalizedId;
    selectedBranchName.value = match?.name ?? '';
    selectedSemesterId.value = '';
    selectedSemesterName.value = '';
    semesterOptions.clear();

    if (normalizedId.isEmpty) {
      eligibleStudents.clear();
      selectedEligibleStudentIds.clear();
      return;
    }

    await _loadSemesterOptionsForSelectedBranch();
  }

  Future<void> selectAttendanceSemester(String semesterId) async {
    final String normalizedId = semesterId.trim();
    final AttendanceOption? match = semesterOptions.firstWhereOrNull(
      (AttendanceOption option) => option.id == normalizedId,
    );
    selectedSemesterId.value = normalizedId;
    selectedSemesterName.value = match?.name ?? '';
    await _loadEligibleStudentsForSelectedContext();
  }

  Future<void> _loadTeacherAttendanceContextOptions() async {
    if (!isTeacher.value) {
      return;
    }

    isLoadingAttendanceContext.value = true;
    try {
      await _refreshScopedTeacherSubjects();
    } finally {
      isLoadingAttendanceContext.value = false;
    }
  }

  Future<void> _loadSemesterOptionsForSelectedBranch() async {
    final String branchId = selectedBranchId.value.trim();
    if (branchId.isEmpty) {
      semesterOptions.clear();
      selectedSemesterId.value = '';
      selectedSemesterName.value = '';
      await _loadEligibleStudentsForSelectedContext();
      return;
    }

    final List<AttendanceSubjectContext> subjectContexts =
        selectedTeacherSubjectContexts;
    List<AttendanceOption> semesters = <AttendanceOption>[];

    for (final AttendanceSubjectContext context in subjectContexts) {
      if (_normalizeValue(context.branchId) != _normalizeValue(branchId)) {
        continue;
      }
      final String semesterId = context.semesterId.trim();
      if (semesterId.isEmpty ||
          semesters.any((AttendanceOption option) => option.id == semesterId)) {
        continue;
      }
      semesters.add(
        AttendanceOption(
          id: semesterId,
          name: context.semesterLabel,
          description: context.branchLabel,
        ),
      );
    }

    if (semesters.isEmpty) {
      semesters = await AttendanceService.loadSemesterOptions(
        branchId: branchId,
      );
    }

    semesters.sort(
      (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
    );
    semesterOptions.assignAll(semesters);

    final String currentSemesterId = selectedSemesterId.value.trim();
    final String preferredSemesterId =
        _userDataController?.semesterId.value ?? '';
    final AttendanceOption? currentSemester = semesters.firstWhereOrNull(
      (AttendanceOption option) => option.id == currentSemesterId,
    );
    final AttendanceOption? preferredSemester = semesters.firstWhereOrNull(
      (AttendanceOption option) => option.id == preferredSemesterId,
    );
    final AttendanceOption? semesterToSelect =
        currentSemester ??
        preferredSemester ??
        (semesters.isNotEmpty ? semesters.first : null);

    if (semesterToSelect == null) {
      selectedSemesterId.value = '';
      selectedSemesterName.value = '';
      await _loadEligibleStudentsForSelectedContext();
      return;
    }

    selectedSemesterId.value = semesterToSelect.id;
    selectedSemesterName.value = semesterToSelect.name;
    await _loadEligibleStudentsForSelectedContext();
  }

  Future<void> _refreshScopedTeacherSubjects() async {
    final List<AttendanceSubject> filtered = teacherSubjects.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    scopedTeacherSubjects.assignAll(filtered);

    final AttendanceSubject? preferredSubject =
        _findPreferredSubjectForUserContext(filtered);
    final String current = selectedSubjectId.value.trim();
    final AttendanceSubject? currentSubject = filtered.firstWhereOrNull(
      (AttendanceSubject subject) => subject.id == current,
    );
    final AttendanceSubject? subjectToSelect =
        currentSubject ??
        preferredSubject ??
        (filtered.isNotEmpty ? filtered.first : null);
    if (subjectToSelect == null) {
      selectedSubjectId.value = '';
      branchOptions.clear();
      semesterOptions.clear();
      selectedBranchId.value = '';
      selectedBranchName.value = '';
      selectedSemesterId.value = '';
      selectedSemesterName.value = '';
      eligibleStudents.clear();
      selectedEligibleStudentIds.clear();
      return;
    }

    selectedSubjectId.value = subjectToSelect.id;
    await _refreshContextOptionsForSelectedSubject();
  }

  Future<void> _refreshContextOptionsForSelectedSubject() async {
    final AttendanceSubject? subject = selectedTeacherSubject;
    if (subject == null) {
      branchOptions.clear();
      semesterOptions.clear();
      selectedBranchId.value = '';
      selectedBranchName.value = '';
      selectedSemesterId.value = '';
      selectedSemesterName.value = '';
      eligibleStudents.clear();
      selectedEligibleStudentIds.clear();
      return;
    }

    final Map<String, AttendanceOption> branchMap =
        <String, AttendanceOption>{};
    for (final AttendanceSubjectContext context in subject.contexts) {
      final String branchId = context.branchId.trim();
      if (branchId.isEmpty) {
        continue;
      }
      branchMap.putIfAbsent(
        branchId,
        () => AttendanceOption(id: branchId, name: context.branchLabel),
      );
    }

    if (branchMap.isEmpty) {
      final List<AttendanceOption> branches =
          await AttendanceService.loadBranchOptions();
      branchOptions.assignAll(branches);

      final String currentBranchId = selectedBranchId.value.trim();
      final String preferredBranchId =
          _userDataController?.branchId.value ?? '';
      final AttendanceOption? branchToSelect =
          branches.firstWhereOrNull(
            (AttendanceOption option) => option.id == currentBranchId,
          ) ??
          branches.firstWhereOrNull(
            (AttendanceOption option) => option.id == preferredBranchId,
          ) ??
          (branches.isNotEmpty ? branches.first : null);

      if (branchToSelect == null) {
        selectedBranchId.value = '';
        selectedBranchName.value = '';
        selectedSemesterId.value = '';
        selectedSemesterName.value = '';
        semesterOptions.clear();
        await _loadEligibleStudentsForSelectedContext();
        return;
      }

      selectedBranchId.value = branchToSelect.id;
      selectedBranchName.value = branchToSelect.name;
      await _loadSemesterOptionsForSelectedBranch();
      return;
    }

    final List<AttendanceOption> branches = branchMap.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    branchOptions.assignAll(branches);

    final String currentBranchId = selectedBranchId.value.trim();
    final String preferredBranchId = _userDataController?.branchId.value ?? '';
    final AttendanceOption? branchToSelect =
        branches.firstWhereOrNull(
          (AttendanceOption option) => option.id == currentBranchId,
        ) ??
        branches.firstWhereOrNull(
          (AttendanceOption option) => option.id == preferredBranchId,
        ) ??
        (branches.isNotEmpty ? branches.first : null);

    if (branchToSelect == null) {
      selectedBranchId.value = '';
      selectedBranchName.value = '';
      selectedSemesterId.value = '';
      selectedSemesterName.value = '';
      semesterOptions.clear();
      await _loadEligibleStudentsForSelectedContext();
      return;
    }

    selectedBranchId.value = branchToSelect.id;
    selectedBranchName.value = branchToSelect.name;
    await _loadSemesterOptionsForSelectedBranch();
  }

  Future<void> _loadEligibleStudentsForSelectedContext() async {
    final String subjectId = selectedSubjectId.value.trim();
    final String branchId = selectedBranchId.value.trim();
    final String semesterId = selectedSemesterId.value.trim();
    if (!isTeacher.value ||
        subjectId.isEmpty ||
        branchId.isEmpty ||
        semesterId.isEmpty) {
      eligibleStudents.clear();
      selectedEligibleStudentIds.clear();
      return;
    }

    final List<AttendanceRosterStudent> roster =
        await AttendanceService.loadStudentRosterForContext(
          branchId: branchId,
          semesterId: semesterId,
          subjectId: subjectId,
        );
    eligibleStudents.assignAll(roster);
    selectedEligibleStudentIds.assignAll(
      roster.map((AttendanceRosterStudent student) => student.uid).toList(),
    );
  }

  AttendanceSubject? _findPreferredSubjectForUserContext(
    List<AttendanceSubject> subjects,
  ) {
    final String preferredBranchId = _normalizeValue(
      _userDataController?.branchId.value ?? '',
    );
    final String preferredSemesterId = _normalizeValue(
      _userDataController?.semesterId.value ?? '',
    );
    if (preferredBranchId.isEmpty && preferredSemesterId.isEmpty) {
      return null;
    }

    for (final AttendanceSubject subject in subjects) {
      for (final AttendanceSubjectContext context in subject.contexts) {
        final bool branchMatches =
            preferredBranchId.isEmpty ||
            _normalizeValue(context.branchId) == preferredBranchId;
        final bool semesterMatches =
            preferredSemesterId.isEmpty ||
            _normalizeValue(context.semesterId) == preferredSemesterId;
        if (branchMatches && semesterMatches) {
          return subject;
        }
      }
    }

    return null;
  }

  String _normalizeValue(String raw) => raw.trim().toLowerCase();

  void toggleEligibleStudentSelection(String studentUid) {
    final String normalized = studentUid.trim();
    if (normalized.isEmpty) {
      return;
    }
    if (selectedEligibleStudentIds.contains(normalized)) {
      selectedEligibleStudentIds.remove(normalized);
    } else {
      selectedEligibleStudentIds.add(normalized);
    }
    selectedEligibleStudentIds.refresh();
  }

  void setAllEligibleStudentsSelected(bool selected) {
    if (selected) {
      selectedEligibleStudentIds.assignAll(
        eligibleStudents.map((AttendanceRosterStudent student) => student.uid),
      );
    } else {
      selectedEligibleStudentIds.clear();
    }
  }

  Future<void> generateAttendanceSession() async {
    if (!isTeacher.value || isGeneratingQr.value) {
      return;
    }
    final subject = selectedTeacherSubject;
    final uid = _currentUid;
    final String branchId = selectedBranchId.value.trim();
    final String semesterId = selectedSemesterId.value.trim();
    if (branchId.isEmpty || semesterId.isEmpty) {
      Get.snackbar('Attendance', 'Please select branch and semester first');
      return;
    }
    if (subject == null || uid.isEmpty) {
      Get.snackbar('Attendance', 'Please select an available subject first');
      return;
    }

    try {
      isGeneratingQr.value = true;
      final locationResult =
          await AttendanceLocationService.resolveCurrentPreciseLocation();
      if (!locationResult.isSuccess) {
        await _showLocationAccessDialog(
          locationResult,
          contextLabel: 'start attendance session',
        );
        return;
      }
      final teacherLocation = locationResult.point!;
      final entry = await AttendanceService.createAttendanceEntry(
        teacherUid: uid,
        teacherName: _currentUserName,
        subject: subject,
        branch: selectedBranchName.value.trim(),
        branchId: branchId,
        semester: selectedSemesterName.value.trim(),
        semesterId: semesterId,
        generateLatitude: teacherLocation.latitude,
        generateLongitude: teacherLocation.longitude,
        generateAccuracyMeters: teacherLocation.accuracyMeters,
        expiryDuration: Duration(minutes: qrValidityMinutes.value),
        graceDelay: Duration(seconds: qrGraceDelaySeconds.value),
        allowedRadiusMeters: attendanceRadiusMeters,
      );
      _bindActiveEntry(entry.id);
      activeEntry.value = entry;
      selectedTeacherSessionId.value = entry.id;
      _mergeTeacherSession(entry);
      _syncQrTimer();
      Get.snackbar('Attendance', 'Live attendance session started');
      await refreshTeacherReport();
    } catch (error, stackTrace) {
      debugPrint('Generate attendance session failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      Get.snackbar('Attendance', 'Failed to start attendance session: $error');
    } finally {
      isGeneratingQr.value = false;
    }
  }

  Future<void> generateAttendanceQr() => generateAttendanceSession();

  Future<void> extendActiveQrByMinutes(int minutes) async {
    final entry = activeEntry.value;
    if (entry == null || isExtendingQr.value || minutes <= 0) {
      return;
    }

    try {
      isExtendingQr.value = true;
      final updated = await AttendanceService.extendAttendanceEntryExpiry(
        attendanceId: entry.id,
        additionalDuration: Duration(minutes: minutes),
      );
      if (updated == null) {
        Get.snackbar('Attendance', 'Unable to extend active session');
        return;
      }

      activeEntry.value = updated;
      _mergeTeacherSession(updated);
      _syncQrTimer();
      Get.snackbar('Attendance', 'Session extended by $minutes minute(s)');
    } finally {
      isExtendingQr.value = false;
    }
  }

  Future<void> processScannedQrPayload(String encryptedPayload) async {
    if (isProcessingScan.value) {
      return;
    }
    final uid = _currentUid;
    if (uid.isEmpty) {
      return;
    }

    try {
      isProcessingScan.value = true;
      lastScanMessage.value = '';

      final locationResult =
          await AttendanceLocationService.resolveCurrentPreciseLocation();
      final studentLocation = locationResult.point;
      final String studentBranchId = _userDataController?.branchId.value ?? '';
      final String studentSemesterId =
          _userDataController?.semesterId.value ?? '';

      final result = await AttendanceService.markAttendanceFromQr(
        encryptedPayload: encryptedPayload,
        studentUid: uid,
        studentName: _currentUserName,
        studentLatitude: studentLocation?.latitude,
        studentLongitude: studentLocation?.longitude,
        studentAccuracyMeters: studentLocation?.accuracyMeters,
        studentBranchId: studentBranchId,
        studentSemesterId: studentSemesterId,
      );
      await _handleMarkResult(
        result: result,
        locationResult: locationResult,
        contextLabel: 'mark attendance',
      );
    } finally {
      isProcessingScan.value = false;
    }
  }

  Future<void> markAttendanceForSession(String attendanceId) async {
    if (isProcessingScan.value) {
      return;
    }
    final String uid = _currentUid;
    if (uid.isEmpty) {
      return;
    }

    try {
      isProcessingScan.value = true;
      lastScanMessage.value = '';

      final locationResult =
          await AttendanceLocationService.resolveCurrentPreciseLocation();
      final studentLocation = locationResult.point;
      final String studentBranchId = _userDataController?.branchId.value ?? '';
      final String studentSemesterId =
          _userDataController?.semesterId.value ?? '';

      final result = await AttendanceService.markAttendanceById(
        attendanceId: attendanceId,
        studentUid: uid,
        studentName: _currentUserName,
        studentLatitude: studentLocation?.latitude,
        studentLongitude: studentLocation?.longitude,
        studentAccuracyMeters: studentLocation?.accuracyMeters,
        studentBranchId: studentBranchId,
        studentSemesterId: studentSemesterId,
      );

      await _handleMarkResult(
        result: result,
        locationResult: locationResult,
        contextLabel: 'mark attendance',
      );
    } finally {
      isProcessingScan.value = false;
    }
  }

  Future<void> _handleMarkResult({
    required AttendanceMarkResult result,
    required AttendanceLocationResult locationResult,
    required String contextLabel,
  }) async {
    switch (result.status) {
      case AttendanceMarkStatus.success:
        lastScanMessage.value = 'You are Present';
        Get.snackbar('Attendance', 'You are Present');
        await refreshStudentData();
        break;
      case AttendanceMarkStatus.qrExpired:
        lastScanMessage.value = 'Session expired';
        Get.snackbar('Attendance', 'Session expired');
        break;
      case AttendanceMarkStatus.sessionClosed:
        lastScanMessage.value = 'Session already submitted';
        Get.snackbar(
          'Attendance',
          'Teacher has already submitted this session',
        );
        break;
      case AttendanceMarkStatus.alreadyMarked:
        lastScanMessage.value = 'Attendance already marked';
        Get.snackbar('Attendance', 'Attendance already marked');
        break;
      case AttendanceMarkStatus.invalidQr:
        lastScanMessage.value = 'Invalid session';
        Get.snackbar('Attendance', 'Invalid session');
        break;
      case AttendanceMarkStatus.attendanceNotFound:
        lastScanMessage.value = 'Attendance session not found';
        Get.snackbar('Attendance', 'Attendance session not found');
        break;
      case AttendanceMarkStatus.notEligible:
        lastScanMessage.value = 'Branch or semester does not match';
        Get.snackbar(
          'Attendance',
          'This session does not match your branch or semester',
        );
        break;
      case AttendanceMarkStatus.locationUnavailable:
        lastScanMessage.value = 'Location unavailable';
        Get.snackbar(
          'Attendance',
          'Location required. Enable GPS and try again',
        );
        await _showLocationAccessDialog(
          locationResult,
          contextLabel: contextLabel,
        );
        break;
      case AttendanceMarkStatus.outsideAllowedRadius:
        lastScanMessage.value = 'Outside allowed radius';
        Get.snackbar(
          'Attendance',
          'You are outside allowed radius (50m). Move near teacher.',
        );
        break;
      case AttendanceMarkStatus.permissionDenied:
        lastScanMessage.value = 'Permission denied';
        Get.snackbar('Attendance', 'Permission denied');
        break;
      case AttendanceMarkStatus.unknownError:
        lastScanMessage.value = 'Something went wrong';
        Get.snackbar('Attendance', 'Something went wrong');
        break;
    }
  }

  Future<void> _showLocationAccessDialog(
    AttendanceLocationResult locationResult, {
    required String contextLabel,
  }) async {
    final bool alreadyOpen = Get.isDialogOpen ?? false;
    if (alreadyOpen) {
      return;
    }

    switch (locationResult.status) {
      case AttendanceLocationStatus.success:
        return;
      case AttendanceLocationStatus.serviceDisabled:
        await Get.dialog<void>(
          AlertDialog(
            title: const Text('Enable Location'),
            content: Text(
              'Location service is off. Please enable GPS to $contextLabel.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back<void>(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  Get.back<void>();
                  await AttendanceLocationService.openDeviceLocationSettings();
                },
                child: const Text('Open Location'),
              ),
            ],
          ),
          barrierDismissible: true,
        );
        return;
      case AttendanceLocationStatus.permissionDenied:
        await Get.dialog<void>(
          AlertDialog(
            title: const Text('Allow Location Permission'),
            content: Text(
              'Location permission is required to $contextLabel. Tap Allow and grant permission.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back<void>(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  Get.back<void>();
                  await AttendanceLocationService.requestPermission();
                },
                child: const Text('Allow'),
              ),
            ],
          ),
          barrierDismissible: true,
        );
        return;
      case AttendanceLocationStatus.permissionDeniedForever:
        await Get.dialog<void>(
          AlertDialog(
            title: const Text('Permission Blocked'),
            content: Text(
              'Location permission is permanently denied. Open app settings and allow location to $contextLabel.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back<void>(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  Get.back<void>();
                  await AttendanceLocationService.openApplicationSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
          barrierDismissible: true,
        );
        return;
      case AttendanceLocationStatus.unavailable:
        await Get.dialog<void>(
          AlertDialog(
            title: const Text('Location Unavailable'),
            content: Text(
              'Unable to fetch precise location. Turn on GPS and location permission, then try again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back<void>(),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: () async {
                  Get.back<void>();
                  await AttendanceLocationService.openDeviceLocationSettings();
                },
                child: const Text('Open Location'),
              ),
            ],
          ),
          barrierDismissible: true,
        );
        return;
    }
  }

  Future<void> refreshStudentData() async {
    final uid = _currentUid;
    if (uid.isEmpty) {
      return;
    }

    isLoadingStudentData.value = true;
    try {
      final String studentBranchId = _userDataController?.branchId.value ?? '';
      final String studentSemesterId =
          _userDataController?.semesterId.value ?? '';
      final summaries = await AttendanceService.buildStudentSummary(
        studentUid: uid,
        preferredSubjects: studentSubjects.toList(),
        studentBranchId: studentBranchId,
        studentSemesterId: studentSemesterId,
      );
      studentSummaries.assignAll(summaries);

      final dailyRecords = await AttendanceService.buildStudentDailyAttendance(
        studentUid: uid,
        studentBranchId: studentBranchId,
        studentSemesterId: studentSemesterId,
      );
      studentDailyRecords.assignAll(dailyRecords);

      final history = await AttendanceService.loadStudentHistory(
        studentUid: uid,
      );
      studentHistory.assignAll(history);
    } catch (_) {
      Get.snackbar('Attendance', 'Unable to refresh attendance data');
    } finally {
      isLoadingStudentData.value = false;
    }
  }

  Future<void> refreshTeacherReport() async {
    final uid = _currentUid;
    if (uid.isEmpty || !isTeacher.value) {
      return;
    }

    isLoadingTeacherReport.value = true;
    try {
      await AttendanceService.deleteExpiredEmptySessionsForTeacher(
        teacherUid: uid,
      );
      final context = await AttendanceService.loadUserContext(userUid: uid);
      teacherSubjects.assignAll(context.teacherSubjects);
      await _refreshScopedTeacherSubjects();

      final sessions = await AttendanceService.loadTeacherSessions(
        teacherUid: uid,
      );
      teacherSessions.assignAll(sessions);
      _syncSelectedTeacherSession(sessions);
      final report = AttendanceService.buildTeacherSubjectReportFromEntries(
        sessions,
      );
      teacherReport.assignAll(report);
    } catch (error, stackTrace) {
      debugPrint('Refresh teacher report failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      Get.snackbar('Attendance', 'Unable to load teacher report');
    } finally {
      isLoadingTeacherReport.value = false;
    }
  }

  Future<void> copyActiveQrPayload() async {
    final payload = selectedTeacherSession?.qrPayload ?? '';
    if (payload.trim().isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: payload));
    Get.snackbar('Attendance', 'Session payload copied');
  }

  void selectTeacherSession(String attendanceId) {
    selectedTeacherSessionId.value = attendanceId.trim();
  }

  Future<void> removeStudentFromSelectedSession(String studentUid) async {
    final session = selectedTeacherSession;
    if (session == null ||
        session.isFinalized ||
        isMutatingTeacherSession.value) {
      return;
    }

    try {
      isMutatingTeacherSession.value = true;
      final updated = await AttendanceService.removeStudentFromAttendance(
        attendanceId: session.id,
        studentUid: studentUid,
      );
      if (updated == null) {
        Get.snackbar('Attendance', 'Unable to remove student from session');
        return;
      }

      if (activeEntry.value?.id == updated.id) {
        activeEntry.value = updated;
      }
      if (_shouldAutoDeleteEmptySession(updated)) {
        await _deleteSessionIfEmpty(
          updated.id,
          snackbarMessage: 'Empty attendance session removed automatically',
        );
        return;
      }
      _mergeTeacherSession(updated);
      Get.snackbar('Attendance', 'Student removed from attendance');
    } finally {
      isMutatingTeacherSession.value = false;
    }
  }

  Future<void> finalizeSelectedSession() async {
    final session = selectedTeacherSession;
    if (session == null ||
        session.isFinalized ||
        isMutatingTeacherSession.value) {
      return;
    }

    try {
      isMutatingTeacherSession.value = true;
      if (_shouldAutoDeleteEmptySession(session)) {
        await _deleteSessionIfEmpty(
          session.id,
          snackbarMessage:
              'No student marked attendance, so this session was deleted',
        );
        return;
      }
      final updated = await AttendanceService.finalizeAttendanceEntry(
        attendanceId: session.id,
      );
      if (updated == null) {
        Get.snackbar('Attendance', 'Unable to submit attendance');
        return;
      }

      if (activeEntry.value?.id == updated.id) {
        activeEntry.value = updated;
      }
      _mergeTeacherSession(updated);
      _syncQrTimer();
      Get.snackbar('Attendance', 'Attendance submitted');
    } finally {
      isMutatingTeacherSession.value = false;
    }
  }

  Future<void> copyTeacherCsvReport() async {
    if (teacherSessions.isEmpty) {
      Get.snackbar('Attendance', 'No report data available');
      return;
    }
    final String csv = await AttendanceService.buildTeacherAttendanceMatrixCsv(
      teacherSessions.toList(),
    );
    if (csv.trim().isEmpty) {
      Get.snackbar('Attendance', 'No report data available');
      return;
    }
    await Clipboard.setData(ClipboardData(text: csv));
    Get.snackbar('Attendance', 'CSV copied to clipboard');
  }

  Future<void> exportTeacherExcelReport() async {
    if (isExportingTeacherReport.value) {
      return;
    }
    if (teacherSessions.isEmpty) {
      Get.snackbar('Attendance', 'No report data available');
      return;
    }

    try {
      isExportingTeacherReport.value = true;
      final bytes = await AttendanceService.buildTeacherAttendanceMatrixExcel(
        teacherSessions.toList(),
      );
      if (bytes == null || bytes.isEmpty) {
        Get.snackbar('Attendance', 'Unable to build Excel report');
        return;
      }

      final String fileName =
          'attendance_register_${_fileSafeTimestamp(DateTime.now())}.xlsx';
      final String? savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save attendance register',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const <String>['xlsx'],
        bytes: bytes,
      );

      if (GetPlatform.isWeb) {
        Get.snackbar('Attendance', 'Excel report downloaded');
        return;
      }
      if (savedPath == null) {
        Get.snackbar('Attendance', 'Export cancelled');
        return;
      }

      Get.snackbar('Attendance', 'Excel report saved successfully');
    } catch (error, stackTrace) {
      debugPrint('Export teacher Excel report failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      Get.snackbar('Attendance', 'Failed to save Excel report');
    } finally {
      isExportingTeacherReport.value = false;
    }
  }

  void _bindActiveEntry(String attendanceId) {
    _activeEntrySub?.cancel();
    _activeEntrySub = AttendanceService.watchAttendanceEntry(attendanceId)
        .listen((entry) {
          activeEntry.value = entry;
          if (entry != null) {
            _mergeTeacherSession(entry);
          }
          _syncQrTimer();
        });
  }

  void _bindStudentAvailableSessions() {
    _studentAvailableSessionsSub?.cancel();
    final String uid = _currentUid;
    final String branchId = _userDataController?.branchId.value ?? '';
    final String semesterId = _userDataController?.semesterId.value ?? '';
    if (uid.isEmpty || branchId.trim().isEmpty || semesterId.trim().isEmpty) {
      availableStudentSessions.clear();
      unawaited(_enforceDeviceAttendanceLock());
      return;
    }

    _studentAvailableSessionsSub =
        AttendanceService.watchStudentAvailableSessions(
          studentUid: uid,
          branchId: branchId,
          semesterId: semesterId,
          studentSubjects: studentSubjects.toList(),
        ).listen((List<AttendanceEntry> sessions) {
          availableStudentSessions.assignAll(sessions);
          unawaited(_enforceDeviceAttendanceLock());
        });
  }

  void _unbindStudentAvailableSessions() {
    _studentAvailableSessionsSub?.cancel();
    _studentAvailableSessionsSub = null;
    availableStudentSessions.clear();
    unawaited(_enforceDeviceAttendanceLock());
  }

  void _unbindActiveEntry() {
    _activeEntrySub?.cancel();
    _activeEntrySub = null;
    _qrTicker?.cancel();
    activeEntry.value = null;
    activeQrSecondsLeft.value = 0;
  }

  void _mergeTeacherSession(AttendanceEntry entry) {
    final current = teacherSessions.toList();
    final int index = current.indexWhere((item) => item.id == entry.id);
    if (index >= 0) {
      current[index] = entry;
    } else {
      current.insert(0, entry);
    }
    current.sort((a, b) => b.startTimeMillis.compareTo(a.startTimeMillis));
    teacherSessions.assignAll(current);
    _syncSelectedTeacherSession(current);
    teacherReport.assignAll(
      AttendanceService.buildTeacherSubjectReportFromEntries(current),
    );
  }

  void _syncSelectedTeacherSession(List<AttendanceEntry> sessions) {
    final String currentSelectedId = selectedTeacherSessionId.value.trim();
    final bool selectionExists = sessions.any(
      (item) => item.id == currentSelectedId,
    );
    final AttendanceEntry? liveSession = _findLiveSession(sessions);

    if (selectionExists) {
      selectedTeacherSessionId.value = currentSelectedId;
    } else if (liveSession != null) {
      selectedTeacherSessionId.value = liveSession.id;
    } else if (sessions.isNotEmpty) {
      selectedTeacherSessionId.value = sessions.first.id;
    } else {
      selectedTeacherSessionId.value = '';
    }

    final AttendanceEntry? activeSession = _findLiveSession(sessions);
    if (activeSession == null) {
      _unbindActiveEntry();
      unawaited(_enforceDeviceAttendanceLock());
      return;
    }

    if (activeEntry.value?.id == activeSession.id && _activeEntrySub != null) {
      _syncQrTimer();
      unawaited(_enforceDeviceAttendanceLock());
      return;
    }
    _bindActiveEntry(activeSession.id);
    unawaited(_enforceDeviceAttendanceLock());
  }

  AttendanceEntry? _findLiveSession(List<AttendanceEntry> sessions) {
    for (final session in sessions) {
      if (!session.isFinalized &&
          session.validUntilMillis > DateTime.now().millisecondsSinceEpoch) {
        return session;
      }
    }
    return null;
  }

  void _syncQrTimer() {
    _qrTicker?.cancel();
    _updateQrSeconds();

    final entry = activeEntry.value;
    if (entry == null) {
      return;
    }

    _qrTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateQrSeconds();
      if (activeQrSecondsLeft.value <= 0) {
        _qrTicker?.cancel();
      }
    });
  }

  void _updateQrSeconds() {
    liveClockMillis.value = DateTime.now().millisecondsSinceEpoch;
    final entry = activeEntry.value;
    if (entry == null || entry.isFinalized) {
      activeQrSecondsLeft.value = 0;
      unawaited(_enforceDeviceAttendanceLock());
      return;
    }
    final int validUntilMillis =
        entry.expiryTimeMillis + (entry.graceDelaySeconds * 1000);
    final int millisLeft =
        validUntilMillis - DateTime.now().millisecondsSinceEpoch;
    if (millisLeft <= 0) {
      activeQrSecondsLeft.value = 0;
      if (_shouldAutoDeleteEmptySession(entry) &&
          _autoCleanupSessionId != entry.id) {
        _autoCleanupSessionId = entry.id;
        unawaited(
          _deleteSessionIfEmpty(
            entry.id,
            snackbarMessage: 'Expired empty attendance session removed',
          ),
        );
      }
      unawaited(_enforceDeviceAttendanceLock());
      return;
    }
    _autoCleanupSessionId = '';
    activeQrSecondsLeft.value = (millisLeft / 1000).ceil();
    unawaited(_enforceDeviceAttendanceLock());
  }

  bool _shouldAutoDeleteEmptySession(AttendanceEntry entry) {
    return !entry.isFinalized &&
        entry.presentCount <= 0 &&
        entry.students.isEmpty;
  }

  void _startLiveClockTicker() {
    _liveClockTicker?.cancel();
    liveClockMillis.value = DateTime.now().millisecondsSinceEpoch;
    _liveClockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      liveClockMillis.value = DateTime.now().millisecondsSinceEpoch;
      unawaited(_enforceDeviceAttendanceLock());
    });
  }

  Future<void> _deleteSessionIfEmpty(
    String attendanceId, {
    required String snackbarMessage,
  }) async {
    final bool deleted = await AttendanceService.deleteAttendanceEntryIfEmpty(
      attendanceId: attendanceId,
    );
    if (!deleted) {
      await refreshTeacherReport();
      return;
    }

    if (activeEntry.value?.id == attendanceId) {
      _unbindActiveEntry();
    }
    _autoCleanupSessionId = '';
    await refreshTeacherReport();
    Get.snackbar('Attendance', snackbarMessage);
  }

  void _clearState() {
    isTeacher.value = false;
    errorMessage.value = '';
    branchOptions.clear();
    semesterOptions.clear();
    teacherSubjects.clear();
    scopedTeacherSubjects.clear();
    studentSubjects.clear();
    selectedBranchId.value = '';
    selectedBranchName.value = '';
    selectedSemesterId.value = '';
    selectedSemesterName.value = '';
    selectedSubjectId.value = '';
    qrValidityMinutes.value = 2;
    qrGraceDelaySeconds.value = 0;
    activeEntry.value = null;
    selectedTeacherSessionId.value = '';
    activeQrSecondsLeft.value = 0;
    isExtendingQr.value = false;
    isMutatingTeacherSession.value = false;
    studentSummaries.clear();
    studentDailyRecords.clear();
    studentHistory.clear();
    availableStudentSessions.clear();
    teacherSessions.clear();
    teacherReport.clear();
    isExportingTeacherReport.value = false;
    eligibleStudents.clear();
    selectedEligibleStudentIds.clear();
    _lastStudentContextKey = '';
    _autoCleanupSessionId = '';
    isLoadingAttendanceContext.value = false;
    _unbindActiveEntry();
    _unbindStudentAvailableSessions();
    _qrTicker?.cancel();
    unawaited(_enforceDeviceAttendanceLock());
  }

  Future<void> _enforceDeviceAttendanceLock() async {
    final bool shouldLock = isAttendanceLockActive;
    final int nowMillis = DateTime.now().millisecondsSinceEpoch;
    final bool syncedRecently =
        _lastSyncedDeviceLockState == shouldLock &&
        (shouldLock
            ? nowMillis - _lastDeviceLockSyncMillis < 3000
            : nowMillis - _lastDeviceLockSyncMillis < 10000);
    if (syncedRecently) {
      return;
    }

    _pendingDeviceLockState = shouldLock;
    if (_isEnforcingDeviceLock) {
      return;
    }
    _isEnforcingDeviceLock = true;
    try {
      while (_pendingDeviceLockState != null) {
        final bool targetState = _pendingDeviceLockState!;
        _pendingDeviceLockState = null;

        final bool locked = await AttendanceLockService.setAttendanceLock(
          targetState,
        );
        _lastSyncedDeviceLockState = targetState;
        _lastDeviceLockSyncMillis = DateTime.now().millisecondsSinceEpoch;

        if (locked || !targetState) {
          continue;
        }

        if (_lastDeviceLockSyncMillis - _lastDeviceLockFailureMessageMillis <
            10000) {
          continue;
        }
        _lastDeviceLockFailureMessageMillis = _lastDeviceLockSyncMillis;
        Get.snackbar(
          'Attendance lock warning',
          'Strict app lock unavailable. Phone settings me Screen Pinning enable karein.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      _isEnforcingDeviceLock = false;
    }
  }

  String _fileSafeTimestamp(DateTime dateTime) {
    final String year = dateTime.year.toString().padLeft(4, '0');
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String day = dateTime.day.toString().padLeft(2, '0');
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');
    final String second = dateTime.second.toString().padLeft(2, '0');
    return '$year$month${day}_$hour$minute$second';
  }

  String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '0s';
    }
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    if (minutes <= 0) {
      return '${seconds}s';
    }
    if (seconds <= 0) {
      return '${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }
}
