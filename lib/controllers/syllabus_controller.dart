import 'dart:async';

import 'package:academic_async/controllers/auth_controller.dart';
import 'package:academic_async/controllers/get_user_data.dart';
import 'package:academic_async/models/syllabus_record.dart';
import 'package:academic_async/pages/syllabus_topics_page.dart';
import 'package:academic_async/services/syllabus_progress_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SyllabusController extends GetxController {
  final RxList<SyllabusRecord> allItems = <SyllabusRecord>[].obs;
  final RxList<SyllabusRecord> visibleItems = <SyllabusRecord>[].obs;
  final RxMap<String, bool> completedTopicMap = <String, bool>{}.obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxString activeSemesterId = ''.obs;

  UserDataController? _userDataController;
  AuthController? _authController;
  Worker? _profileWatcher;
  Worker? _authWatcher;
  String _activeProgressScope = '';

  bool get isTeacherScopedView =>
      _userDataController?.isTeacherProfile ?? false;
  bool get requiresSemesterProfile => !isTeacherScopedView;
  List<String> get teacherSubjectLabels =>
      _userDataController?.teacherSubjectNames.toList() ?? const <String>[];

  @override
  void onInit() {
    super.onInit();
    _bindUserScope();
    _bindAuthUser();
    unawaited(loadSyllabus());
  }

  @override
  void onClose() {
    _profileWatcher?.dispose();
    _authWatcher?.dispose();
    super.onClose();
  }

  Future<void> loadSyllabus() async {
    if (Firebase.apps.isEmpty) {
      errorMessage.value = 'Firebase is not initialized.';
      allItems.clear();
      visibleItems.clear();
      return;
    }

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection('syllabus').get();

      final List<SyllabusRecord> records = <SyllabusRecord>[];
      for (final doc in snapshot.docs) {
        try {
          final SyllabusRecord? parsed = SyllabusRecord.fromFirestore(
            doc.id,
            doc.data(),
          );
          if (parsed != null) {
            records.add(parsed);
          }
        } catch (_) {
          // Skip malformed docs to avoid blocking the complete list.
        }
      }

      records.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
      allItems.assignAll(records);
      _applySemesterFilter();
      await _loadProgressForActiveScope();
    } catch (_) {
      errorMessage.value = 'Unable to load syllabus right now.';
      allItems.clear();
      visibleItems.clear();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshData() => loadSyllabus();

  void openTopics(SyllabusRecord record) {
    Get.to(() => SyllabusTopicsPage(record: record));
  }

  void showTopicDetails(SyllabusTopic topic) {
    if (topic.details.trim().isEmpty) {
      Get.snackbar(
        'Topic',
        topic.title,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    Get.bottomSheet(
      SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Get.theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                topic.title,
                style: TextStyle(
                  color: Get.theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                topic.details,
                style: TextStyle(color: Get.theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _bindUserScope() {
    if (!Get.isRegistered<UserDataController>()) {
      return;
    }
    _userDataController = Get.find<UserDataController>();
    activeSemesterId.value = _normalizeId(
      _userDataController!.semesterId.value,
    );
    _profileWatcher = everAll(
      [
        _userDataController!.semesterId,
        _userDataController!.role,
        _userDataController!.isTeacher,
        _userDataController!.teacherSubjectIds,
        _userDataController!.teacherSubjectNames,
      ],
      (_) {
        activeSemesterId.value = _normalizeId(
          _userDataController!.semesterId.value,
        );
        _applySemesterFilter();
        unawaited(_loadProgressForActiveScope());
      },
    );
  }

  void _bindAuthUser() {
    if (!Get.isRegistered<AuthController>()) {
      return;
    }
    _authController = Get.find<AuthController>();
    _authWatcher = ever(_authController!.user, (_) {
      _applySemesterFilter();
      unawaited(_loadProgressForActiveScope());
    });
  }

  void _applySemesterFilter() {
    if (isTeacherScopedView) {
      final List<SyllabusRecord> filtered = allItems
          .where(_matchesTeacherSubjectSelection)
          .toList();
      visibleItems.assignAll(filtered);
      if (filtered.isEmpty) {
        completedTopicMap.clear();
      }
      return;
    }

    final String semesterId = activeSemesterId.value;
    if (semesterId.isEmpty) {
      visibleItems.clear();
      completedTopicMap.clear();
      return;
    }

    final List<SyllabusRecord> filtered = allItems
        .where((item) => _matchesSemester(item, semesterId))
        .toList();
    visibleItems.assignAll(filtered);
  }

  bool _matchesTeacherSubjectSelection(SyllabusRecord record) {
    final UserDataController? userData = _userDataController;
    if (userData == null) {
      return false;
    }

    final Set<String> subjectIds = userData.teacherSubjectIds
        .map(_normalizeId)
        .where((value) => value.isNotEmpty)
        .toSet();
    final Set<String> subjectNames = userData.teacherSubjectNames
        .map((value) => value.trim().toLowerCase())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (subjectIds.isEmpty && subjectNames.isEmpty) {
      return false;
    }

    return subjectIds.contains(_normalizeId(record.id)) ||
        subjectNames.contains(record.title.trim().toLowerCase());
  }

  bool _matchesSemester(SyllabusRecord record, String semesterId) {
    if (record.forSemesterIds.isEmpty) {
      return false;
    }
    for (final id in record.forSemesterIds) {
      if (_normalizeId(id) == semesterId) {
        return true;
      }
    }
    return false;
  }

  String topicCompletionKey(
    SyllabusRecord record,
    SyllabusUnit unit,
    SyllabusTopic topic,
  ) {
    return '${record.id}::${unit.id}::${topic.id}'.toLowerCase();
  }

  bool isTopicCompleted(
    SyllabusRecord record,
    SyllabusUnit unit,
    SyllabusTopic topic,
  ) {
    return completedTopicMap[topicCompletionKey(record, unit, topic)] == true;
  }

  Future<void> setTopicCompleted(
    SyllabusRecord record,
    SyllabusUnit unit,
    SyllabusTopic topic,
    bool completed,
  ) async {
    final String key = topicCompletionKey(record, unit, topic);
    if (completed) {
      completedTopicMap[key] = true;
    } else {
      completedTopicMap.remove(key);
    }
    completedTopicMap.refresh();
    await _persistProgress();
  }

  int completedTopicsCount(SyllabusRecord record) {
    int done = 0;
    for (final unit in record.units) {
      for (final topic in unit.topics) {
        if (isTopicCompleted(record, unit, topic)) {
          done++;
        }
      }
    }
    return done;
  }

  int totalTopicsCount(SyllabusRecord record) => record.totalTopics;

  double completionPercent(SyllabusRecord record) {
    final int total = totalTopicsCount(record);
    if (total == 0) {
      return 0;
    }
    return completedTopicsCount(record) / total;
  }

  int completedTopicsInUnit(SyllabusRecord record, SyllabusUnit unit) {
    int done = 0;
    for (final topic in unit.topics) {
      if (isTopicCompleted(record, unit, topic)) {
        done++;
      }
    }
    return done;
  }

  int totalTopicsInUnit(SyllabusUnit unit) => unit.topics.length;

  double unitCompletionPercent(SyllabusRecord record, SyllabusUnit unit) {
    final int total = totalTopicsInUnit(unit);
    if (total == 0) {
      return 0;
    }
    return completedTopicsInUnit(record, unit) / total;
  }

  Future<void> _loadProgressForActiveScope() async {
    final String scope = _buildProgressScope();
    _activeProgressScope = scope;
    if (scope.isEmpty) {
      completedTopicMap.clear();
      return;
    }

    final Set<String> stored = await SyllabusProgressService.readCompletedKeys(
      scope,
    );
    final Set<String> valid = _filterToKnownTopicKeys(stored);
    completedTopicMap
      ..clear()
      ..addEntries(valid.map((key) => MapEntry(key, true)));

    if (valid.length != stored.length) {
      await SyllabusProgressService.saveCompletedKeys(scope, valid);
    }
  }

  Future<void> _persistProgress() async {
    if (_activeProgressScope.isEmpty) {
      return;
    }
    final Set<String> keys = completedTopicMap.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toSet();
    await SyllabusProgressService.saveCompletedKeys(_activeProgressScope, keys);
  }

  Set<String> _filterToKnownTopicKeys(Set<String> keys) {
    final Set<String> known = <String>{};
    for (final record in visibleItems) {
      for (final unit in record.units) {
        for (final topic in unit.topics) {
          known.add(topicCompletionKey(record, unit, topic));
        }
      }
    }
    return keys.where(known.contains).toSet();
  }

  String _buildProgressScope() {
    final String semesterId = activeSemesterId.value;
    final String userId = _authController?.user.value?.uid ?? '';
    return SyllabusProgressService.buildScope(
      semesterId: semesterId,
      userId: userId,
    );
  }

  String _normalizeId(String raw) => raw.trim().toLowerCase();
}
