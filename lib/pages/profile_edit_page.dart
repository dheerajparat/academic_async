import 'package:academic_async/controllers/auth_controller.dart';
import 'package:academic_async/controllers/get_user_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final UserDataController _userDataController = Get.find<UserDataController>();
  final AuthController _authController = Get.find<AuthController>();

  late final TextEditingController _nameController;
  late final TextEditingController _registrationNoController;

  final List<_IdNameOption> _branchOptions = <_IdNameOption>[];
  final List<_IdNameOption> _semesterOptions = <_IdNameOption>[];
  final List<_IdNameOption> _teacherSubjectOptions = <_IdNameOption>[];
  final Set<String> _selectedTeacherSubjectIds = <String>{};

  bool _isLoadingBranches = false;
  bool _isLoadingSemesters = false;
  bool _isLoadingTeacherSubjects = false;
  bool _isSaving = false;
  String _selectedBranchId = '';
  String _selectedSemesterId = '';
  String _teacherSubjectsError = '';

  bool get _isTeacherProfile => _userDataController.isTeacherProfile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: _userDataController.name.value,
    );
    _registrationNoController = TextEditingController(
      text: _userDataController.registrationNo.value,
    );
    _selectedBranchId = _userDataController.branchId.value;
    _selectedSemesterId = _userDataController.semesterId.value;
    _selectedTeacherSubjectIds.addAll(_userDataController.teacherSubjectIds);

    if (_isTeacherProfile) {
      _loadTeacherSubjects();
    } else {
      _loadBranches();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _registrationNoController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoadingBranches = true;
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection('branches').get();
      final List<_IdNameOption> options =
          snapshot.docs
              .map(
                (doc) => _IdNameOption(
                  id: doc.id,
                  name: _readString(doc.data()['name'], fallback: 'Unknown'),
                ),
              )
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _branchOptions
          ..clear()
          ..addAll(options);
        if (!_branchOptions.any((item) => item.id == _selectedBranchId) &&
            _branchOptions.isNotEmpty) {
          _selectedBranchId = _branchOptions.first.id;
        }
      });

      await _loadSemestersForBranch(_selectedBranchId);
    } catch (_) {
      if (!mounted) {
        return;
      }
      Get.snackbar('Profile', 'Unable to load branches right now');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingBranches = false;
        });
      }
    }
  }

  Future<void> _loadSemestersForBranch(String branchId) async {
    setState(() {
      _isLoadingSemesters = true;
    });

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('branches')
          .doc(branchId)
          .collection('semesters')
          .get();

      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('semesters')
            .where('branch_id', isEqualTo: branchId)
            .get();
      }
      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('semesters')
            .where('branchId', isEqualTo: branchId)
            .get();
      }

      final List<_IdNameOption> options =
          snapshot.docs
              .map(
                (doc) => _IdNameOption(
                  id: doc.id,
                  name: _readString(
                    doc.data()['name'],
                    fallback: 'Unknown Semester',
                  ),
                ),
              )
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _semesterOptions
          ..clear()
          ..addAll(options);
        if (!_semesterOptions.any((item) => item.id == _selectedSemesterId) &&
            _semesterOptions.isNotEmpty) {
          _selectedSemesterId = _semesterOptions.first.id;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      Get.snackbar('Profile', 'Unable to load semesters right now');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSemesters = false;
        });
      }
    }
  }

  Future<void> _loadTeacherSubjects() async {
    setState(() {
      _isLoadingTeacherSubjects = true;
      _teacherSubjectsError = '';
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection('syllabus').get();
      final Map<String, _IdNameOption> mapped = <String, _IdNameOption>{};
      for (final doc in snapshot.docs) {
        final Map<String, dynamic> data = doc.data();
        final String title = _readString(
          data['title'],
          fallback: _readString(data['name']),
        );
        if (title.isEmpty) {
          continue;
        }
        mapped[doc.id] = _IdNameOption(id: doc.id, name: title);
      }

      final List<_IdNameOption> options = mapped.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) {
        return;
      }

      setState(() {
        final Set<String> selectedNames = _userDataController
            .teacherSubjectNames
            .map((value) => value.trim().toLowerCase())
            .where((value) => value.isNotEmpty)
            .toSet();
        _teacherSubjectOptions
          ..clear()
          ..addAll(options);
        if (_selectedTeacherSubjectIds.isEmpty && selectedNames.isNotEmpty) {
          for (final _IdNameOption item in _teacherSubjectOptions) {
            if (selectedNames.contains(item.name.trim().toLowerCase())) {
              _selectedTeacherSubjectIds.add(item.id);
            }
          }
        }
        _selectedTeacherSubjectIds.removeWhere(
          (id) => !_teacherSubjectOptions.any((item) => item.id == id),
        );
        if (_teacherSubjectOptions.isEmpty) {
          _teacherSubjectsError = 'No syllabus subjects found for selection';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _teacherSubjectsError = 'Unable to load teacher subjects right now';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingTeacherSubjects = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) {
      return;
    }

    final String trimmedName = _nameController.text.trim();
    if (trimmedName.isEmpty) {
      Get.snackbar('Profile', 'Name is required');
      return;
    }

    if (!_isTeacherProfile) {
      if (_registrationNoController.text.trim().isEmpty) {
        Get.snackbar('Profile', 'Registration No is required');
        return;
      }
      if (_selectedBranchId.trim().isEmpty ||
          _selectedSemesterId.trim().isEmpty) {
        Get.snackbar('Profile', 'Please select branch and semester');
        return;
      }
    }

    if (_isTeacherProfile && _selectedTeacherSubjectIds.isEmpty) {
      Get.snackbar('Profile', 'Please select at least one subject');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final _IdNameOption? branch = _branchOptions.firstWhereOrNull(
        (item) => item.id == _selectedBranchId,
      );
      final _IdNameOption? semester = _semesterOptions.firstWhereOrNull(
        (item) => item.id == _selectedSemesterId,
      );
      final List<String> teacherSubjectIds = _selectedTeacherSubjectIds.toList()
        ..sort();
      final List<String> teacherSubjectNames = _teacherSubjectOptions
          .where((item) => _selectedTeacherSubjectIds.contains(item.id))
          .map((item) => item.name)
          .toList();

      final bool didUpdate = await _userDataController.updateCurrentProfile(
        name: trimmedName,
        registrationNo: _registrationNoController.text.trim(),
        branch: branch?.name ?? '',
        branchId: _selectedBranchId,
        semester: semester?.name ?? '',
        semesterId: _selectedSemesterId,
        teacherSubjectIds: teacherSubjectIds,
        teacherSubjectNames: teacherSubjectNames,
      );

      if (!mounted) {
        return;
      }

      if (!didUpdate) {
        Get.snackbar('Profile', 'Unable to save profile changes');
        return;
      }

      Get.snackbar('Profile', 'Profile updated successfully');
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        Get.snackbar('Profile', 'Unable to save profile changes');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final String email = _userDataController.email.value.trim();
    if (email.isEmpty) {
      Get.snackbar('Account', 'No email found for this account');
      return;
    }
    await _authController.sendPasswordResetEmail(email: email);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isBusy =
        _isSaving ||
        _isLoadingBranches ||
        _isLoadingSemesters ||
        _isLoadingTeacherSubjects;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: colors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Login account',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _userDataController.email.value.isEmpty
                        ? 'No email available'
                        : _userDataController.email.value,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _sendPasswordReset,
                        icon: const Icon(Icons.lock_reset_rounded),
                        label: const Text('Reset password'),
                      ),
                      Chip(
                        avatar: const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Email change is not in this form'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: colors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profile details',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_isTeacherProfile) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Teaching subjects',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Syllabus page me sirf yehi selected subjects dikhaye jayenge.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    if (_isLoadingTeacherSubjects) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (_teacherSubjectsError.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _teacherSubjectsError,
                        style: TextStyle(color: colors.error),
                      ),
                    ],
                    if (_teacherSubjectOptions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _teacherSubjectOptions.map((subject) {
                          final bool isSelected = _selectedTeacherSubjectIds
                              .contains(subject.id);
                          return FilterChip(
                            label: Text(subject.name),
                            selected: isSelected,
                            onSelected: (bool value) {
                              setState(() {
                                if (value) {
                                  _selectedTeacherSubjectIds.add(subject.id);
                                } else {
                                  _selectedTeacherSubjectIds.remove(subject.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _registrationNoController,
                      decoration: const InputDecoration(
                        labelText: 'Registration No',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>(
                        'profile_branch_${_selectedBranchId}_${_branchOptions.length}',
                      ),
                      initialValue:
                          _branchOptions.any(
                            (item) => item.id == _selectedBranchId,
                          )
                          ? _selectedBranchId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Branch',
                        border: OutlineInputBorder(),
                      ),
                      items: _branchOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: _isLoadingBranches
                          ? null
                          : (String? value) async {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedBranchId = value;
                                _selectedSemesterId = '';
                              });
                              await _loadSemestersForBranch(value);
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>(
                        'profile_semester_${_selectedSemesterId}_${_semesterOptions.length}',
                      ),
                      initialValue:
                          _semesterOptions.any(
                            (item) => item.id == _selectedSemesterId,
                          )
                          ? _selectedSemesterId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Semester',
                        border: OutlineInputBorder(),
                      ),
                      items: _semesterOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item.id,
                              child: Text(item.name),
                            ),
                          )
                          .toList(),
                      onChanged: _isLoadingSemesters
                          ? null
                          : (String? value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedSemesterId = value;
                              });
                            },
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: isBusy ? null : _saveProfile,
              icon: Icon(
                _isSaving ? Icons.hourglass_top_rounded : Icons.save_rounded,
              ),
              label: Text(_isSaving ? 'Saving...' : 'Save changes'),
            ),
          ),
        ],
      ),
    );
  }

  String _readString(dynamic value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }
    if (value is String) {
      final String trimmed = value.trim();
      return trimmed.isEmpty ? fallback : trimmed;
    }
    final String normalized = value.toString().trim();
    return normalized.isEmpty ? fallback : normalized;
  }
}

class _IdNameOption {
  const _IdNameOption({required this.id, required this.name});

  final String id;
  final String name;
}
