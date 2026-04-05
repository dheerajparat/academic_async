import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherSubjectOption {
  const TeacherSubjectOption({required this.id, required this.name});

  final String id;
  final String name;
}

class AuthFormController extends GetxController {
  static const String _preferredAuthRoleKey = 'preferred_auth_role';

  final TextEditingController nameController = TextEditingController();
  final TextEditingController registrationNoController =
      TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final RxBool isLoginMode = true.obs;
  final RxBool obscurePassword = true.obs;
  final RxBool isRoleLoaded = false.obs;
  final RxString selectedRole = ''.obs;
  final RxBool shouldPromptRoleSelection = false.obs;

  final RxList<TeacherSubjectOption> teacherSubjectOptions =
      <TeacherSubjectOption>[].obs;
  final RxList<String> selectedTeacherSubjectIds = <String>[].obs;
  final RxBool isLoadingTeacherSubjects = false.obs;
  final RxnString teacherSubjectsError = RxnString();

  @override
  void onInit() {
    super.onInit();
    unawaited(_restoreRolePreference());
  }

  void toggleMode() {
    isLoginMode.value = !isLoginMode.value;
    if (!isLoginMode.value && selectedRole.value == 'teacher') {
      unawaited(loadTeacherSubjects());
    }
  }

  void togglePasswordVisibility() {
    obscurePassword.value = !obscurePassword.value;
  }

  Future<void> chooseRole(String role) async {
    final normalized = role.trim().toLowerCase();
    if (normalized != 'teacher' && normalized != 'student') {
      return;
    }
    selectedRole.value = normalized;
    shouldPromptRoleSelection.value = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredAuthRoleKey, normalized);

    if (!isLoginMode.value && normalized == 'teacher') {
      await loadTeacherSubjects();
    }
  }

  void changeRole() {
    shouldPromptRoleSelection.value = true;
  }

  Future<void> loadTeacherSubjects() async {
    if (isLoadingTeacherSubjects.value) {
      return;
    }

    if (Firebase.apps.isEmpty) {
      teacherSubjectOptions.clear();
      teacherSubjectsError.value = 'Firebase is not initialized';
      return;
    }

    isLoadingTeacherSubjects.value = true;
    teacherSubjectsError.value = null;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('syllabus')
          .get();

      final Map<String, TeacherSubjectOption> deduped = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final title = _asString(
          data['title'],
          fallback: _asString(data['name']),
        );
        if (title.isEmpty) {
          continue;
        }
        deduped[doc.id] = TeacherSubjectOption(id: doc.id, name: title);
      }

      final List<TeacherSubjectOption> sorted = deduped.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      teacherSubjectOptions.assignAll(sorted);

      final Set<String> availableIds = sorted.map((e) => e.id).toSet();
      selectedTeacherSubjectIds.removeWhere((id) => !availableIds.contains(id));
      if (sorted.isEmpty) {
        teacherSubjectsError.value = 'No subjects found in syllabus collection';
      }
    } catch (_) {
      teacherSubjectsError.value = 'Unable to load subjects';
    } finally {
      isLoadingTeacherSubjects.value = false;
    }
  }

  void toggleTeacherSubject(String subjectId) {
    final id = subjectId.trim();
    if (id.isEmpty) {
      return;
    }
    if (selectedTeacherSubjectIds.contains(id)) {
      selectedTeacherSubjectIds.remove(id);
    } else {
      selectedTeacherSubjectIds.add(id);
    }
    selectedTeacherSubjectIds.refresh();
  }

  List<String> get selectedTeacherSubjectNames {
    final selected = selectedTeacherSubjectIds.toSet();
    return teacherSubjectOptions
        .where((subject) => selected.contains(subject.id))
        .map((subject) => subject.name)
        .toList();
  }

  Future<void> _restoreRolePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final String savedRole =
        prefs.getString(_preferredAuthRoleKey)?.trim().toLowerCase() ?? '';
    if (savedRole == 'teacher' || savedRole == 'student') {
      selectedRole.value = savedRole;
      shouldPromptRoleSelection.value = false;
      if (!isLoginMode.value && savedRole == 'teacher') {
        await loadTeacherSubjects();
      }
    } else {
      selectedRole.value = '';
      shouldPromptRoleSelection.value = true;
    }
    isRoleLoaded.value = true;
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

  @override
  void onClose() {
    nameController.dispose();
    registrationNoController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
