import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SyllabusGet extends GetxController {
  final RxList<Map<String, String>> branchItems = <Map<String, String>>[].obs;
  final RxList<Map<String, String>> semesterItems = <Map<String, String>>[].obs;

  final RxString selectedBranchId = ''.obs;
  final RxString selectedBranchName = ''.obs;
  final RxString selectedSemesterId = ''.obs;
  final RxString selectedSemesterName = ''.obs;
  final RxBool isLoadingBranches = false.obs;
  final RxBool isLoadingSemesters = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadBranches();
  }

  Future<void> loadBranches() async {
    try {
      isLoadingBranches.value = true;
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection('branches').get();

      branchItems.clear();
      for (final doc in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        branchItems.add({
          'id': doc.id,
          'name': (data['name'] as String?) ?? 'Unknown',
        });
      }

      if (branchItems.isNotEmpty) {
        await selectBranch(
          branchId: branchItems.first['id']!,
          branchName: branchItems.first['name']!,
        );
      } else {
        clearSemesters();
      }
    } catch (_) {
      branchItems.clear();
      clearSemesters();
    } finally {
      isLoadingBranches.value = false;
    }
  }

  Future<void> selectBranch({
    required String branchId,
    required String branchName,
  }) async {
    selectedBranchId.value = branchId;
    selectedBranchName.value = branchName;
    await loadSemestersForBranch(branchId);
  }

  Future<void> loadSemestersForBranch(String branchId) async {
    try {
      isLoadingSemesters.value = true;
      semesterItems.clear();

      final QuerySnapshot<Map<String, dynamic>> subCollectionSnapshot =
          await FirebaseFirestore.instance
              .collection('branches')
              .doc(branchId)
              .collection('semesters')
              .get();

      if (subCollectionSnapshot.docs.isNotEmpty) {
        for (final doc in subCollectionSnapshot.docs) {
          final data = doc.data();
          semesterItems.add({
            'id': doc.id,
            'name': (data['name'] as String?) ?? 'Unknown Semester',
          });
        }
      } else {
        final QuerySnapshot<Map<String, dynamic>> querySnapshot =
            await FirebaseFirestore.instance
                .collection('semesters')
                .where('branch_id', isEqualTo: branchId)
                .get();

        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          semesterItems.add({
            'id': doc.id,
            'name': (data['name'] as String?) ?? 'Unknown Semester',
          });
        }
      }

      if (semesterItems.isNotEmpty) {
        selectedSemesterId.value = semesterItems.first['id']!;
        selectedSemesterName.value = semesterItems.first['name']!;
      } else {
        selectedSemesterId.value = '';
        selectedSemesterName.value = '';
      }
    } catch (_) {
      clearSemesters();
    } finally {
      isLoadingSemesters.value = false;
    }
  }

  void selectSemester({
    required String semesterId,
    required String semesterName,
  }) {
    selectedSemesterId.value = semesterId;
    selectedSemesterName.value = semesterName;
  }

  void clearSemesters() {
    semesterItems.clear();
    selectedSemesterId.value = '';
    selectedSemesterName.value = '';
  }

  Map<String, String>? findBranchByName(String branchName) {
    try {
      return branchItems.firstWhere((item) => item['name'] == branchName);
    } catch (_) {
      return null;
    }
  }

  Map<String, String>? findBranchById(String branchId) {
    try {
      return branchItems.firstWhere((item) => item['id'] == branchId);
    } catch (_) {
      return null;
    }
  }

  Map<String, String>? findSemesterByName(String semesterName) {
    try {
      return semesterItems.firstWhere((item) => item['name'] == semesterName);
    } catch (_) {
      return null;
    }
  }

  Map<String, String>? findSemesterById(String semesterId) {
    try {
      return semesterItems.firstWhere((item) => item['id'] == semesterId);
    } catch (_) {
      return null;
    }
  }
}
