import 'package:academic_async/controllers/get_user_data.dart';
import 'package:academic_async/services/event_cache_service.dart';
import 'package:academic_async/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';

class AuthController extends GetxController {
  final Rxn<User> user = Rxn<User>();
  final RxBool isLoading = false.obs;

  FirebaseAuth? get _authOrNull =>
      Firebase.apps.isEmpty ? null : FirebaseAuth.instance;
  FirebaseFirestore? get _firestoreOrNull =>
      Firebase.apps.isEmpty ? null : FirebaseFirestore.instance;

  @override
  void onInit() {
    super.onInit();
    final auth = _authOrNull;
    if (auth != null) {
      user.bindStream(auth.authStateChanges());
    }
    ever<User?>(user, (firebaseUser) {
      if (!Get.isRegistered<UserDataController>()) {
        return;
      }

      final UserDataController userDataController =
          Get.find<UserDataController>();
      if (firebaseUser == null) {
        userDataController.clear();
      } else {
        userDataController.loadUserDataFromUid(firebaseUser.uid);
      }
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    final auth = _authOrNull;
    if (auth == null) {
      Get.snackbar('Firebase', 'Firebase is not initialized on this platform');
      return;
    }

    try {
      isLoading.value = true;
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      await _handlePostLoginApprovalState(credential.user);
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Login failed', e.message ?? 'Unable to login');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    final auth = _authOrNull;
    if (auth == null) {
      Get.snackbar('Firebase', 'Firebase is not initialized on this platform');
      return;
    }

    final String normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      Get.snackbar('Reset password', 'Please enter your email first');
      return;
    }

    try {
      isLoading.value = true;
      await auth.sendPasswordResetEmail(email: normalizedEmail);
      Get.snackbar(
        'Reset link sent',
        'A password reset link has been sent to $normalizedEmail',
      );
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Reset failed', e.message ?? 'Unable to send reset email');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signUpStudent({
    required String name,
    required String email,
    required String password,
    required String registrationNo,
    required String branch,
    required String branchId,
    required String semester,
    required String semesterId,
  }) async {
    final auth = _authOrNull;
    if (auth == null) {
      Get.snackbar('Firebase', 'Firebase is not initialized on this platform');
      return;
    }

    try {
      isLoading.value = true;
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final userName = name.trim();
      if (credential.user != null && userName.isNotEmpty) {
        await credential.user!.updateDisplayName(userName);
      }

      await _upsertStudentDoc(
        firebaseUser: credential.user,
        name: userName,
        registrationNo: registrationNo.trim(),
        branch: branch,
        branchId: branchId,
        semester: semester,
        semesterId: semesterId,
      );
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Signup failed', e.message ?? 'Unable to create account');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signUpTeacherRequest({
    required String name,
    required String email,
    required String password,
    required List<String> teacherSubjectIds,
    required List<String> teacherSubjectNames,
  }) async {
    final auth = _authOrNull;
    if (auth == null) {
      Get.snackbar('Firebase', 'Firebase is not initialized on this platform');
      return;
    }

    final List<String> normalizedSubjectIds = teacherSubjectIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    final List<String> normalizedSubjectNames = teacherSubjectNames
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedSubjectIds.isEmpty) {
      Get.snackbar('Validation', 'Please select at least one subject');
      return;
    }

    try {
      isLoading.value = true;
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final userName = name.trim();
      if (credential.user != null && userName.isNotEmpty) {
        await credential.user!.updateDisplayName(userName);
      }

      await _upsertTeacherPendingDoc(
        firebaseUser: credential.user,
        name: userName,
        teacherSubjectIds: normalizedSubjectIds,
        teacherSubjectNames: normalizedSubjectNames,
      );

      await auth.signOut();
      Get.snackbar(
        'Request sent',
        'Teacher signup request submitted for developer approval',
      );
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Signup failed', e.message ?? 'Unable to create account');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _upsertStudentDoc({
    required User? firebaseUser,
    required String name,
    required String registrationNo,
    required String branch,
    required String branchId,
    required String semester,
    required String semesterId,
  }) async {
    final firestore = _firestoreOrNull;
    if (firestore == null || firebaseUser == null) {
      return;
    }

    final DocumentReference<Map<String, dynamic>> ref = firestore
        .collection('users')
        .doc(firebaseUser.uid);

    final existing = await ref.get();
    await ref.set({
      'name': name.isEmpty
          ? (firebaseUser.displayName ??
                firebaseUser.email?.split('@').first ??
                'Student')
          : name,
      'email': firebaseUser.email ?? '',
      'registration_no': registrationNo,
      'branch': branch,
      'branch_id': branchId,
      'semester': semester,
      'semester_id': semesterId,
      'role': 'student',
      'requested_role': 'student',
      'approval_status': 'approved',
      'is_teacher': false,
      if (!existing.exists) 'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (Get.isRegistered<UserDataController>()) {
      await Get.find<UserDataController>().loadUserDataFromUid(
        firebaseUser.uid,
      );
    }
  }

  Future<void> _upsertTeacherPendingDoc({
    required User? firebaseUser,
    required String name,
    required List<String> teacherSubjectIds,
    required List<String> teacherSubjectNames,
  }) async {
    final firestore = _firestoreOrNull;
    if (firestore == null || firebaseUser == null) {
      return;
    }

    final String normalizedName = name.isEmpty
        ? (firebaseUser.displayName ??
              firebaseUser.email?.split('@').first ??
              'Teacher')
        : name;
    final String email = firebaseUser.email ?? '';

    await firestore.collection('users').doc(firebaseUser.uid).set({
      'name': normalizedName,
      'email': email,
      'role': 'teacher_pending',
      'requested_role': 'teacher',
      'approval_status': 'pending',
      'is_teacher': false,
      'teacher_subject_ids': teacherSubjectIds,
      'teacher_subject_names': teacherSubjectNames,
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await firestore
        .collection('teacher_signup_requests')
        .doc(firebaseUser.uid)
        .set({
          'uid': firebaseUser.uid,
          'name': normalizedName,
          'email': email,
          'teacher_subject_ids': teacherSubjectIds,
          'teacher_subject_names': teacherSubjectNames,
          'status': 'pending',
          'requested_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _handlePostLoginApprovalState(User? firebaseUser) async {
    final firestore = _firestoreOrNull;
    final auth = _authOrNull;
    if (firebaseUser == null || firestore == null || auth == null) {
      return;
    }

    final doc = await firestore.collection('users').doc(firebaseUser.uid).get();
    final data = doc.data() ?? const <String, dynamic>{};
    final String role = _asString(data['role']).toLowerCase();
    final String requestedRole = _asString(
      data['requested_role'],
    ).toLowerCase();
    final String approvalStatus = _asString(
      data['approval_status'],
    ).toLowerCase();

    final bool teacherContext =
        role.startsWith('teacher') || requestedRole == 'teacher';
    final bool pending =
        approvalStatus == 'pending' || role == 'teacher_pending';
    if (teacherContext && pending) {
      await auth.signOut();
      Get.snackbar(
        'Approval pending',
        'Developer approval is required before teacher login',
      );
      return;
    }

    if (teacherContext && approvalStatus == 'rejected') {
      await auth.signOut();
      Get.snackbar(
        'Approval rejected',
        'Teacher request rejected. Contact app developer.',
      );
    }
  }

  String _asString(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value.trim();
    }
    return value.toString().trim();
  }

  Future<void> signOut() async {
    final auth = _authOrNull;
    if (auth == null) {
      return;
    }
    await auth.signOut();
    await EventCacheService.clearUserContext();
    await NotificationService.clearAll();
  }
}
