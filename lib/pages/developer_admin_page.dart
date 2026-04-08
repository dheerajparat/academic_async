import 'package:academic_async/controllers/attendance_controller.dart';
import 'package:academic_async/controllers/auth_controller.dart';
import 'package:academic_async/controllers/developer_admin_controller.dart';
import 'package:academic_async/models/developer_admin_models.dart';
import 'package:academic_async/models/event_record.dart';
import 'package:academic_async/models/syllabus_record.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class DeveloperAdminPage extends StatelessWidget {
  const DeveloperAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DeveloperAdminController controller =
        Get.isRegistered<DeveloperAdminController>()
        ? Get.find<DeveloperAdminController>()
        : Get.put(DeveloperAdminController(), permanent: true);
    final AuthController authController = Get.find<AuthController>();
    final AttendanceController attendanceController =
        Get.find<AttendanceController>();
    final ColorScheme colors = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Developer Mode'),
          actions: [
            IconButton(
              tooltip: 'Logout',
              onPressed: () async {
                if (!attendanceController.canPerformProtectedAction(
                  actionLabel: 'logging out',
                )) {
                  return;
                }
                await authController.signOut();
              },
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Requests'),
              Tab(text: 'Users'),
              Tab(text: 'Events'),
              Tab(text: 'Syllabus'),
            ],
          ),
        ),
        floatingActionButton: Obx(() {
          if (!controller.isAccessGranted.value) {
            return const SizedBox.shrink();
          }
          return Builder(
            builder: (tabContext) {
              final TabController tabController = DefaultTabController.of(
                tabContext,
              );
              return AnimatedBuilder(
                animation: tabController.animation!,
                builder: (_, _) {
                  final bool isSyllabusTab = tabController.index == 3;
                  return FloatingActionButton(
                    onPressed: () {
                      if (isSyllabusTab) {
                        _openSyllabusEditor(
                          context: context,
                          controller: controller,
                        );
                        return;
                      }
                      _openCreateChooser(context, controller);
                    },
                    child: Icon(
                      isSyllabusTab
                          ? Icons.menu_book_rounded
                          : Icons.add_rounded,
                    ),
                  );
                },
              );
            },
          );
        }),
        body: Obx(() {
          if (!controller.isAccessGranted.value) {
            return Center(
              child: Text(
                controller.errorMessage.value.isEmpty
                    ? 'Developer access required'
                    : controller.errorMessage.value,
                style: TextStyle(color: colors.error),
                textAlign: TextAlign.center,
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: _StatsWrap(controller: controller, colors: colors),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _RequestsTab(controller: controller, colors: colors),
                    _UsersTab(controller: controller, colors: colors),
                    _EventsTab(controller: controller, colors: colors),
                    _SyllabusTab(controller: controller, colors: colors),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

void _openCreateChooser(
  BuildContext context,
  DeveloperAdminController controller,
) {
  Get.bottomSheet<void>(
    SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person_add_alt_1_rounded),
            title: const Text('Add / Edit User'),
            subtitle: const Text(
              'Role, semester, branch, subjects and profile fields',
            ),
            onTap: () {
              Get.back<void>();
              _openUserEditor(context: context, controller: controller);
            },
          ),
          ListTile(
            leading: const Icon(Icons.event_available_rounded),
            title: const Text('Add Event'),
            subtitle: const Text('Create event and assign branch/semester'),
            onTap: () {
              Get.back<void>();
              _openEventEditor(context: context, controller: controller);
            },
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: const Text('Add Syllabus'),
            subtitle: const Text(
              'Create subject with semester, units and topics',
            ),
            onTap: () {
              Get.back<void>();
              _openSyllabusEditor(context: context, controller: controller);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
    backgroundColor: Theme.of(context).colorScheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  );
}

class _StatsWrap extends StatelessWidget {
  const _StatsWrap({required this.controller, required this.colors});

  final DeveloperAdminController controller;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatCard(
            title: 'Users',
            value: '${controller.totalUsersCount}',
            icon: Icons.people_alt_rounded,
            colors: colors,
          ),
          _StatCard(
            title: 'Students',
            value: '${controller.studentCount}',
            icon: Icons.groups_rounded,
            colors: colors,
          ),
          _StatCard(
            title: 'Teachers',
            value: '${controller.teacherCount}',
            icon: Icons.badge_rounded,
            colors: colors,
          ),
          _StatCard(
            title: 'Pending',
            value: '${controller.pendingRequestCount}',
            icon: Icons.pending_actions_rounded,
            colors: colors,
          ),
          _StatCard(
            title: 'Events',
            value: '${controller.totalEventsCount}',
            icon: Icons.event_note_rounded,
            colors: colors,
          ),
          _StatCard(
            title: 'Syllabus',
            value: '${controller.totalSyllabusCount}',
            icon: Icons.menu_book_rounded,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.colors,
  });

  final String title;
  final String value;
  final IconData icon;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Card(
        color: colors.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            children: [
              Icon(icon, color: colors.primary, size: 19),
              const SizedBox(height: 5),
              Text(
                value,
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                title,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({required this.controller, required this.colors});

  final DeveloperAdminController controller;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final requests = controller.pendingTeacherRequests;
      final requestError = controller.requestsErrorMessage.value;

      if (requests.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              requestError.isEmpty
                  ? 'No pending teacher requests'
                  : '$requestError\nRetrying...',
              style: TextStyle(
                color: requestError.isEmpty
                    ? colors.onSurfaceVariant
                    : colors.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final request = requests[index];
          final title = request.name.trim().isEmpty
              ? request.email.trim().isEmpty
                    ? request.uid
                    : request.email.split('@').first
              : request.name;
          return Card(
            color: colors.surface,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.email,
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Subjects',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (request.teacherSubjectNames.isEmpty)
                    Text(
                      'No subjects selected',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    )
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: request.teacherSubjectNames
                          .map((subject) => Chip(label: Text(subject)))
                          .toList(),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: controller.isPerformingAction.value
                            ? null
                            : () => controller.rejectTeacherRequest(request),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Reject'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: controller.isPerformingAction.value
                            ? null
                            : () => controller.approveTeacherRequest(request),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Approve'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({required this.controller, required this.colors});

  final DeveloperAdminController controller;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final users = controller.visibleUsers;
      final userError = controller.usersErrorMessage.value;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: controller.updateUserSearch,
                    decoration: const InputDecoration(
                      labelText: 'Search users',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String>(
                    initialValue: controller.userRoleFilter.value,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(
                        value: 'student',
                        child: Text('Students'),
                      ),
                      DropdownMenuItem(
                        value: 'teacher',
                        child: Text('Teachers'),
                      ),
                      DropdownMenuItem(
                        value: 'developer',
                        child: Text('Developer'),
                      ),
                      DropdownMenuItem(
                        value: 'pending',
                        child: Text('Pending'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return;
                      }
                      controller.updateUserRoleFilter(value);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: users.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        userError.isEmpty
                            ? 'No users found'
                            : '$userError\nRetrying...',
                        style: TextStyle(
                          color: userError.isEmpty
                              ? colors.onSurfaceVariant
                              : colors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
                    itemCount: users.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final user = users[index];
                      final displayName = user.displayName;
                      return Card(
                        color: colors.surface,
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(displayName[0].toUpperCase()),
                          ),
                          title: Text(displayName),
                          subtitle: Text(
                            [
                              user.role,
                              user.email,
                              user.registrationNo,
                              user.branch,
                              user.semester,
                              user.uid,
                            ].where((e) => e.trim().isNotEmpty).join(' • '),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _openUserEditor(
                                  context: context,
                                  controller: controller,
                                  existing: user,
                                );
                                return;
                              }
                              if (value == 'delete') {
                                final bool shouldDelete = await _confirmDelete(
                                  context: context,
                                  title: 'Delete User',
                                  message:
                                      'Delete user record for ${user.displayName}?',
                                );
                                if (shouldDelete) {
                                  await controller.deleteUser(user.uid);
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }
}

class _EventsTab extends StatelessWidget {
  const _EventsTab({required this.controller, required this.colors});

  final DeveloperAdminController controller;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final events = controller.visibleEvents;
      final error = controller.eventsErrorMessage.value;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              onChanged: controller.updateEventSearch,
              decoration: const InputDecoration(
                labelText: 'Search events',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        error.isEmpty
                            ? 'No events found'
                            : '$error\nRetrying...',
                        style: TextStyle(
                          color: error.isEmpty
                              ? colors.onSurfaceVariant
                              : colors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
                    itemCount: events.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Card(
                        color: colors.surface,
                        child: ListTile(
                          leading: const Icon(Icons.event_note_rounded),
                          title: Text(
                            event.displayText.isEmpty
                                ? 'Event'
                                : event.displayText,
                          ),
                          subtitle: Text(
                            [
                              _formatDate(event.date),
                              event.type,
                              event.branch,
                              event.semester,
                              event.id,
                            ].where((e) => e.trim().isNotEmpty).join(' • '),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _openEventEditor(
                                  context: context,
                                  controller: controller,
                                  existing: event,
                                );
                                return;
                              }
                              if (value == 'delete') {
                                final bool shouldDelete = await _confirmDelete(
                                  context: context,
                                  title: 'Delete Event',
                                  message: 'Delete this event?',
                                );
                                if (shouldDelete) {
                                  await controller.deleteEvent(event.id);
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }
}

class _SyllabusTab extends StatelessWidget {
  const _SyllabusTab({required this.controller, required this.colors});

  final DeveloperAdminController controller;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final syllabus = controller.visibleSyllabus;
      final error = controller.syllabusErrorMessage.value;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: TextField(
              onChanged: controller.updateSyllabusSearch,
              decoration: const InputDecoration(
                labelText: 'Search syllabus',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: syllabus.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        error.isEmpty
                            ? 'No syllabus found'
                            : '$error\nRetrying...',
                        style: TextStyle(
                          color: error.isEmpty
                              ? colors.onSurfaceVariant
                              : colors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 110),
                    itemCount: syllabus.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = syllabus[index];
                      final int unitCount = item.units.length;
                      final int topicCount = item.totalTopics;
                      final String semesters = item.forSemesterIds.isEmpty
                          ? 'No semester linked'
                          : item.forSemesterIds.join(', ');
                      return Card(
                        color: colors.surface,
                        child: ListTile(
                          leading: const Icon(Icons.menu_book_rounded),
                          title: Text(item.title),
                          subtitle: Text(
                            [
                                  '$unitCount unit${unitCount == 1 ? '' : 's'}',
                                  '$topicCount topic${topicCount == 1 ? '' : 's'}',
                                  semesters,
                                  item.id,
                                ]
                                .where((value) => value.trim().isNotEmpty)
                                .join(' • '),
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                _openSyllabusEditor(
                                  context: context,
                                  controller: controller,
                                  existing: item,
                                );
                                return;
                              }
                              if (value == 'delete') {
                                final bool shouldDelete = await _confirmDelete(
                                  context: context,
                                  title: 'Delete Syllabus',
                                  message:
                                      'Delete syllabus record "${item.title}"?',
                                );
                                if (shouldDelete) {
                                  await controller.deleteSyllabus(item.id);
                                }
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }
}

Future<void> _openUserEditor({
  required BuildContext context,
  required DeveloperAdminController controller,
  AdminUserRecord? existing,
}) async {
  await Get.bottomSheet<void>(
    _UserEditorSheet(controller: controller, existing: existing),
    backgroundColor: Theme.of(context).colorScheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  );
}

Future<void> _openEventEditor({
  required BuildContext context,
  required DeveloperAdminController controller,
  EventRecord? existing,
}) async {
  await Get.bottomSheet<void>(
    _EventEditorSheet(controller: controller, existing: existing),
    backgroundColor: Theme.of(context).colorScheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
  );
}

Future<void> _openSyllabusEditor({
  required BuildContext context,
  required DeveloperAdminController controller,
  SyllabusRecord? existing,
}) async {
  await Get.to<void>(
    () => _SyllabusEditorPage(controller: controller, existing: existing),
  );
}

class _UserEditorSheet extends StatefulWidget {
  const _UserEditorSheet({required this.controller, this.existing});

  final DeveloperAdminController controller;
  final AdminUserRecord? existing;

  @override
  State<_UserEditorSheet> createState() => _UserEditorSheetState();
}

class _UserEditorSheetState extends State<_UserEditorSheet> {
  static const List<String> _roleOptions = <String>[
    'student',
    'teacher',
    'teacher_pending',
    'developer',
  ];
  static const List<String> _requestedRoleOptions = <String>[
    '',
    'student',
    'teacher',
    'developer',
  ];
  static const List<String> _approvalOptions = <String>[
    '',
    'approved',
    'pending',
    'rejected',
  ];

  late final TextEditingController _uidController;
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _regNoController;
  late final TextEditingController _teacherSubjectIdsController;
  late final TextEditingController _teacherSubjectNamesController;

  final List<_IdNameOption> _branchOptions = <_IdNameOption>[];
  final List<_IdNameOption> _semesterOptions = <_IdNameOption>[];

  bool _isLoadingBranches = false;
  bool _isLoadingSemesters = false;
  String _selectedBranchId = '';
  String _selectedSemesterId = '';
  String _role = 'student';
  String _requestedRole = 'student';
  String _approvalStatus = 'approved';
  bool _isTeacher = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _uidController = TextEditingController(text: existing?.uid ?? '');
    _nameController = TextEditingController(text: existing?.name ?? '');
    _emailController = TextEditingController(text: existing?.email ?? '');
    _regNoController = TextEditingController(
      text: existing?.registrationNo ?? '',
    );
    _teacherSubjectIdsController = TextEditingController(
      text: (existing?.teacherSubjectIds ?? const <String>[]).join(', '),
    );
    _teacherSubjectNamesController = TextEditingController(
      text: (existing?.teacherSubjectNames ?? const <String>[]).join(', '),
    );

    _selectedBranchId = (existing?.branchId ?? '').trim();
    _selectedSemesterId = (existing?.semesterId ?? '').trim();
    _role = _normalizeRole(existing?.role ?? 'student');
    _requestedRole = _normalizeRequestedRole(existing?.requestedRole ?? _role);
    _approvalStatus = _normalizeApprovalStatus(
      existing?.approvalStatus ?? 'approved',
    );
    _isTeacher = existing?.isTeacher ?? (_role == 'teacher');

    _loadBranches();
  }

  @override
  void dispose() {
    _uidController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _regNoController.dispose();
    _teacherSubjectIdsController.dispose();
    _teacherSubjectNamesController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoadingBranches = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('branches')
          .get();
      final options =
          snapshot.docs
              .map(
                (doc) => _IdNameOption(
                  id: doc.id,
                  name: _asString(doc.data()['name'], fallback: 'Unknown'),
                ),
              )
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      if (!mounted) {
        return;
      }

      _branchOptions
        ..clear()
        ..add(const _IdNameOption(id: '', name: 'All / Not set'))
        ..addAll(options);

      if (!_branchOptions.any((item) => item.id == _selectedBranchId)) {
        _selectedBranchId = '';
      }
      await _loadSemestersForBranch(_selectedBranchId);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _branchOptions
        ..clear()
        ..add(const _IdNameOption(id: '', name: 'All / Not set'));
      _semesterOptions
        ..clear()
        ..add(const _IdNameOption(id: '', name: 'All / Not set'));
      _selectedBranchId = '';
      _selectedSemesterId = '';
      Get.snackbar('Developer', 'Unable to load branches');
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
      QuerySnapshot<Map<String, dynamic>> snapshot;
      if (branchId.trim().isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('semesters')
            .get();
      } else {
        snapshot = await FirebaseFirestore.instance
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
      }

      final options =
          snapshot.docs
              .map(
                (doc) => _IdNameOption(
                  id: doc.id,
                  name: _asString(
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
          ..add(const _IdNameOption(id: '', name: 'All / Not set'))
          ..addAll(options);
        if (!_semesterOptions.any((item) => item.id == _selectedSemesterId)) {
          _selectedSemesterId = '';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _semesterOptions
          ..clear()
          ..add(const _IdNameOption(id: '', name: 'All / Not set'));
        _selectedSemesterId = '';
      });
      Get.snackbar('Developer', 'Unable to load semesters');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSemesters = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final uid = _uidController.text.trim();
    if (uid.isEmpty) {
      Get.snackbar('Validation', 'User UID is required');
      return;
    }

    final branchName = _branchOptions
        .firstWhereOrNull((item) => item.id == _selectedBranchId)
        ?.name;
    final semesterName = _semesterOptions
        .firstWhereOrNull((item) => item.id == _selectedSemesterId)
        ?.name;
    final subjectIds = widget.controller.parseListInput(
      _teacherSubjectIdsController.text,
    );
    final subjectNames = widget.controller.parseListInput(
      _teacherSubjectNamesController.text,
    );

    await widget.controller.upsertUser(
      uid: uid,
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      registrationNo: _regNoController.text.trim(),
      branch: _selectedBranchId.isEmpty ? '' : (branchName ?? ''),
      branchId: _selectedBranchId,
      semester: _selectedSemesterId.isEmpty ? '' : (semesterName ?? ''),
      semesterId: _selectedSemesterId,
      role: _role,
      requestedRole: _requestedRole,
      approvalStatus: _approvalStatus,
      isTeacher: _isTeacher,
      teacherSubjectIds: subjectIds,
      teacherSubjectNames: subjectNames,
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final bool isBusy =
        _isLoadingBranches ||
        _isLoadingSemesters ||
        widget.controller.isPerformingAction.value;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              existing == null ? 'Create User' : 'Edit User',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            if (_isLoadingBranches || _isLoadingSemesters) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _uidController,
              readOnly: existing != null,
              decoration: const InputDecoration(
                labelText: 'UID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _regNoController,
              decoration: const InputDecoration(
                labelText: 'Registration No',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _role,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: _roleOptions
                        .map(
                          (role) =>
                              DropdownMenuItem(value: role, child: Text(role)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return;
                      }
                      setState(() {
                        _role = value;
                        if (value == 'teacher') {
                          _requestedRole = 'teacher';
                          _approvalStatus = 'approved';
                          _isTeacher = true;
                        } else if (value == 'teacher_pending') {
                          _requestedRole = 'teacher';
                          _approvalStatus = 'pending';
                          _isTeacher = false;
                        } else if (value == 'student') {
                          _requestedRole = 'student';
                          _isTeacher = false;
                        } else if (value == 'developer') {
                          _requestedRole = 'developer';
                          _isTeacher = false;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _requestedRole,
                    decoration: const InputDecoration(
                      labelText: 'Requested Role',
                      border: OutlineInputBorder(),
                    ),
                    items: _requestedRoleOptions
                        .map(
                          (role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.isEmpty ? '(empty)' : role),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _requestedRole = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _approvalStatus,
                    decoration: const InputDecoration(
                      labelText: 'Approval',
                      border: OutlineInputBorder(),
                    ),
                    items: _approvalOptions
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status.isEmpty ? '(empty)' : status),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _approvalStatus = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isTeacher,
                    onChanged: (value) {
                      setState(() {
                        _isTeacher = value;
                      });
                    },
                    title: const Text('isTeacher'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'branch_${_selectedBranchId}_${_branchOptions.length}',
              ),
              initialValue:
                  _branchOptions.any((item) => item.id == _selectedBranchId)
                  ? _selectedBranchId
                  : '',
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
                  : (value) async {
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
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'semester_${_selectedSemesterId}_${_semesterOptions.length}',
              ),
              initialValue:
                  _semesterOptions.any((item) => item.id == _selectedSemesterId)
                  ? _selectedSemesterId
                  : '',
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
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedSemesterId = value;
                      });
                    },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _teacherSubjectIdsController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Teacher Subject IDs (comma/new line)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _teacherSubjectNamesController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Teacher Subject Names (comma/new line)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: isBusy ? null : _save,
                  child: Text(existing == null ? 'Create' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _normalizeRole(String value) {
    final normalized = value.trim().toLowerCase();
    return _roleOptions.contains(normalized) ? normalized : 'student';
  }

  String _normalizeRequestedRole(String value) {
    final normalized = value.trim().toLowerCase();
    return _requestedRoleOptions.contains(normalized) ? normalized : '';
  }

  String _normalizeApprovalStatus(String value) {
    final normalized = value.trim().toLowerCase();
    return _approvalOptions.contains(normalized) ? normalized : '';
  }
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({required this.controller, this.existing});

  final DeveloperAdminController controller;
  final EventRecord? existing;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  late final TextEditingController _descriptionController;
  late final TextEditingController _typeController;

  final List<_IdNameOption> _branchOptions = <_IdNameOption>[];
  final List<_IdNameOption> _semesterOptions = <_IdNameOption>[];

  bool _isLoadingBranches = false;
  bool _isLoadingSemesters = false;
  String _selectedBranchId = '';
  String _selectedSemesterId = '';
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _descriptionController = TextEditingController(
      text: existing?.description ?? '',
    );
    _typeController = TextEditingController(text: existing?.type ?? 'event');
    _selectedBranchId = (existing?.branchId ?? '').trim();
    _selectedSemesterId = (existing?.semesterId ?? '').trim();
    _selectedDate = existing?.date ?? DateTime.now();
    _loadBranches();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    setState(() {
      _isLoadingBranches = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('branches')
          .get();
      final options =
          snapshot.docs
              .map(
                (doc) => _IdNameOption(
                  id: doc.id,
                  name: _asString(doc.data()['name'], fallback: 'Unknown'),
                ),
              )
              .toList()
            ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );

      if (!mounted) {
        return;
      }

      _branchOptions
        ..clear()
        ..add(const _IdNameOption(id: '', name: 'All / Not set'))
        ..addAll(options);

      if (!_branchOptions.any((item) => item.id == _selectedBranchId)) {
        _selectedBranchId = '';
      }
      await _loadSemestersForBranch(_selectedBranchId);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _branchOptions
        ..clear()
        ..add(const _IdNameOption(id: '', name: 'All / Not set'));
      _semesterOptions
        ..clear()
        ..add(const _IdNameOption(id: '', name: 'All / Not set'));
      _selectedBranchId = '';
      _selectedSemesterId = '';
      Get.snackbar('Developer', 'Unable to load branches');
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
      QuerySnapshot<Map<String, dynamic>> snapshot;
      if (branchId.trim().isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('semesters')
            .get();
      } else {
        snapshot = await FirebaseFirestore.instance
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
      }

      final options =
          snapshot.docs
              .map(
                (doc) => _IdNameOption(
                  id: doc.id,
                  name: _asString(
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
          ..add(const _IdNameOption(id: '', name: 'All / Not set'))
          ..addAll(options);
        if (!_semesterOptions.any((item) => item.id == _selectedSemesterId)) {
          _selectedSemesterId = '';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _semesterOptions
          ..clear()
          ..add(const _IdNameOption(id: '', name: 'All / Not set'));
        _selectedSemesterId = '';
      });
      Get.snackbar('Developer', 'Unable to load semesters');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSemesters = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save() async {
    final branchName = _branchOptions
        .firstWhereOrNull((item) => item.id == _selectedBranchId)
        ?.name;
    final semesterName = _semesterOptions
        .firstWhereOrNull((item) => item.id == _selectedSemesterId)
        ?.name;

    await widget.controller.upsertEvent(
      id: widget.existing?.id ?? '',
      date: _selectedDate,
      description: _descriptionController.text.trim(),
      type: _typeController.text.trim(),
      branch: _selectedBranchId.isEmpty ? '' : (branchName ?? ''),
      branchId: _selectedBranchId,
      semester: _selectedSemesterId.isEmpty ? '' : (semesterName ?? ''),
      semesterId: _selectedSemesterId,
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final bool isBusy =
        _isLoadingBranches ||
        _isLoadingSemesters ||
        widget.controller.isPerformingAction.value;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              existing == null ? 'Create Event' : 'Edit Event',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            if (_isLoadingBranches || _isLoadingSemesters) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 2),
            ],
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(_formatDate(_selectedDate)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description / Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _typeController,
              decoration: const InputDecoration(
                labelText: 'Type (event/holiday/exam...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'event_branch_${_selectedBranchId}_${_branchOptions.length}',
              ),
              initialValue:
                  _branchOptions.any((item) => item.id == _selectedBranchId)
                  ? _selectedBranchId
                  : '',
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
                  : (value) async {
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
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'event_semester_${_selectedSemesterId}_${_semesterOptions.length}',
              ),
              initialValue:
                  _semesterOptions.any((item) => item.id == _selectedSemesterId)
                  ? _selectedSemesterId
                  : '',
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
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedSemesterId = value;
                      });
                    },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: isBusy ? null : _save,
                  child: Text(existing == null ? 'Create' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SyllabusEditorPage extends StatefulWidget {
  const _SyllabusEditorPage({required this.controller, this.existing});

  final DeveloperAdminController controller;
  final SyllabusRecord? existing;

  @override
  State<_SyllabusEditorPage> createState() => _SyllabusEditorPageState();
}

class _SyllabusEditorPageState extends State<_SyllabusEditorPage> {
  late final TextEditingController _idController;
  late final TextEditingController _titleController;
  late final TextEditingController _semesterIdsController;

  final List<_EditableSyllabusUnit> _units = <_EditableSyllabusUnit>[];
  final List<_IdNameOption> _availableSemesters = <_IdNameOption>[];
  final Set<String> _selectedSemesterIds = <String>{};

  bool _isLoadingSemesters = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _idController = TextEditingController(text: existing?.id ?? '');
    _titleController = TextEditingController(text: existing?.title ?? '');
    _selectedSemesterIds.addAll(existing?.forSemesterIds ?? const <String>[]);
    _semesterIdsController = TextEditingController(
      text: _selectedSemesterIds.join(', '),
    );

    if (existing != null) {
      for (int index = 0; index < existing.units.length; index++) {
        _units.add(
          _EditableSyllabusUnit.fromRecord(
            existing.units[index],
            isExpanded: index == 0,
          ),
        );
      }
    }
    if (_units.isEmpty) {
      _units.add(_EditableSyllabusUnit.withBlankTopic(isExpanded: true));
    }

    _loadAvailableSemesters();
  }

  @override
  void dispose() {
    _idController.dispose();
    _titleController.dispose();
    _semesterIdsController.dispose();
    for (final unit in _units) {
      unit.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAvailableSemesters() async {
    setState(() {
      _isLoadingSemesters = true;
    });

    try {
      final branchesSnapshot = await FirebaseFirestore.instance
          .collection('branches')
          .get();
      final Map<String, String> branchNames = <String, String>{
        for (final doc in branchesSnapshot.docs)
          doc.id: _asString(doc.data()['name'], fallback: doc.id),
      };

      final Map<String, _IdNameOption> deduped = <String, _IdNameOption>{};

      for (final branchDoc in branchesSnapshot.docs) {
        final semestersSnapshot = await branchDoc.reference
            .collection('semesters')
            .get();
        for (final semesterDoc in semestersSnapshot.docs) {
          final semesterName = _asString(
            semesterDoc.data()['name'],
            fallback: semesterDoc.id,
          );
          final branchName = branchNames[branchDoc.id] ?? branchDoc.id;
          deduped[semesterDoc.id] = _IdNameOption(
            id: semesterDoc.id,
            name: '$semesterName • $branchName',
          );
        }
      }

      final rootSemestersSnapshot = await FirebaseFirestore.instance
          .collection('semesters')
          .get();
      for (final semesterDoc in rootSemestersSnapshot.docs) {
        final data = semesterDoc.data();
        final semesterName = _asString(data['name'], fallback: semesterDoc.id);
        final branchId = _asString(
          data['branch_id'],
          fallback: _asString(data['branchId']),
        );
        final branchName = branchId.isEmpty
            ? ''
            : (branchNames[branchId] ?? branchId);
        final label = branchName.isEmpty
            ? semesterName
            : '$semesterName • $branchName';
        deduped.putIfAbsent(
          semesterDoc.id,
          () => _IdNameOption(id: semesterDoc.id, name: label),
        );
      }

      if (!mounted) {
        return;
      }

      final options = deduped.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      setState(() {
        _availableSemesters
          ..clear()
          ..addAll(options);
      });
    } catch (_) {
      if (mounted) {
        Get.snackbar('Developer', 'Unable to load semester options');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSemesters = false;
        });
      }
    }
  }

  void _syncSemesterIdsFromText(String raw) {
    setState(() {
      _selectedSemesterIds
        ..clear()
        ..addAll(widget.controller.parseListInput(raw));
    });
  }

  void _toggleSemesterSelection(String semesterId) {
    final normalizedId = semesterId.trim();
    if (normalizedId.isEmpty) {
      return;
    }

    setState(() {
      if (_selectedSemesterIds.contains(normalizedId)) {
        _selectedSemesterIds.remove(normalizedId);
      } else {
        _selectedSemesterIds.add(normalizedId);
      }
      final text = _selectedSemesterIds.join(', ');
      _semesterIdsController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  void _addUnit() {
    setState(() {
      for (final unit in _units) {
        unit.isExpanded = false;
        for (final topic in unit.topics) {
          topic.isExpanded = false;
        }
      }
      _units.add(_EditableSyllabusUnit.withBlankTopic(isExpanded: true));
    });
  }

  void _removeUnit(int index) {
    setState(() {
      final unit = _units.removeAt(index);
      unit.dispose();
    });
  }

  void _addTopic(int unitIndex) {
    setState(() {
      final unit = _units[unitIndex];
      unit.isExpanded = true;
      for (final topic in unit.topics) {
        topic.isExpanded = false;
      }
      unit.topics.add(_EditableSyllabusTopic(isExpanded: true));
    });
  }

  void _removeTopic(int unitIndex, int topicIndex) {
    setState(() {
      final topic = _units[unitIndex].topics.removeAt(topicIndex);
      topic.dispose();
    });
  }

  List<Map<String, dynamic>>? _serializeUnits() {
    final List<Map<String, dynamic>> serialized = <Map<String, dynamic>>[];

    for (int unitIndex = 0; unitIndex < _units.length; unitIndex++) {
      final unit = _units[unitIndex];
      final rawUnitId = unit.idController.text.trim();
      final rawUnitTitle = unit.titleController.text.trim();
      final bool hasTopicInput = unit.topics.any((topic) => !topic.isBlank);
      final bool isBlank =
          rawUnitId.isEmpty && rawUnitTitle.isEmpty && !hasTopicInput;
      if (isBlank) {
        continue;
      }
      if (rawUnitTitle.isEmpty) {
        Get.snackbar('Validation', 'Unit ${unitIndex + 1} title is required');
        return null;
      }

      final List<Map<String, dynamic>> topics = <Map<String, dynamic>>[];
      for (int topicIndex = 0; topicIndex < unit.topics.length; topicIndex++) {
        final topic = unit.topics[topicIndex];
        final rawTopicId = topic.idController.text.trim();
        final rawTopicTitle = topic.titleController.text.trim();
        if (topic.isBlank) {
          continue;
        }
        if (rawTopicTitle.isEmpty) {
          Get.snackbar(
            'Validation',
            'Topic ${topicIndex + 1} title is required in Unit ${unitIndex + 1}',
          );
          return null;
        }

        final topicId = rawTopicId.isEmpty ? 't${topicIndex + 1}' : rawTopicId;
        topics.add({'id': topicId, 'title': rawTopicTitle});
      }

      if (topics.isEmpty) {
        Get.snackbar(
          'Validation',
          'Add at least one topic in Unit ${unitIndex + 1}',
        );
        return null;
      }

      final unitId = rawUnitId.isEmpty ? 'u${unitIndex + 1}' : rawUnitId;
      serialized.add({'id': unitId, 'title': rawUnitTitle, 'topic': topics});
    }

    if (serialized.isEmpty) {
      Get.snackbar('Validation', 'Add at least one unit with topics');
      return null;
    }
    return serialized;
  }

  Future<void> _save() async {
    final units = _serializeUnits();
    if (units == null) {
      return;
    }

    await widget.controller.upsertSyllabus(
      id: _idController.text.trim(),
      title: _titleController.text.trim(),
      semesterIds: widget.controller.parseListInput(
        _semesterIdsController.text,
      ),
      units: units,
    );
  }

  void _toggleUnitExpansion(int unitIndex) {
    setState(() {
      _units[unitIndex].isExpanded = !_units[unitIndex].isExpanded;
    });
  }

  void _toggleTopicExpansion(int unitIndex, int topicIndex) {
    setState(() {
      final topic = _units[unitIndex].topics[topicIndex];
      topic.isExpanded = !topic.isExpanded;
    });
  }

  String _unitLabel(_EditableSyllabusUnit unit, int index) {
    final title = unit.titleController.text.trim();
    return title.isEmpty ? 'Unit ${index + 1}' : title;
  }

  String _topicLabel(_EditableSyllabusTopic topic, int index) {
    final title = topic.titleController.text.trim();
    return title.isEmpty ? 'Topic ${index + 1}' : title;
  }

  Widget _buildTopicCard(
    BuildContext context,
    _EditableSyllabusUnit unit,
    int unitIndex,
    int topicIndex,
  ) {
    final colors = Theme.of(context).colorScheme;
    final topic = unit.topics[topicIndex];
    final topicIdText = topic.idController.text.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        key: ValueKey(topic.localKey),
        color: colors.surfaceContainerLowest,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => _toggleTopicExpansion(unitIndex, topicIndex),
                title: Text(
                  _topicLabel(topic, topicIndex),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  topicIdText.isEmpty
                      ? 'Topic ID auto-generate hoga'
                      : topicIdText,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Delete Topic',
                      onPressed: unit.topics.length == 1
                          ? null
                          : () => _removeTopic(unitIndex, topicIndex),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                    Icon(
                      topic.isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                  ],
                ),
              ),
              if (topic.isExpanded) ...[
                TextField(
                  controller: topic.idController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'topic.id',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: topic.titleController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'topic.title',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitCard(BuildContext context, int unitIndex) {
    final colors = Theme.of(context).colorScheme;
    final unit = _units[unitIndex];
    final unitIdText = unit.idController.text.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        key: ValueKey(unit.localKey),
        color: colors.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => _toggleUnitExpansion(unitIndex),
                title: Text(
                  _unitLabel(unit, unitIndex),
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  '${unit.topics.length} topic(s) • '
                  '${unitIdText.isEmpty ? 'Unit ID auto-generate hoga' : unitIdText}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Delete Unit',
                      onPressed: _units.length == 1
                          ? null
                          : () => _removeUnit(unitIndex),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                    Icon(
                      unit.isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                  ],
                ),
              ),
              if (unit.isExpanded) ...[
                TextField(
                  controller: unit.idController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'unit.id',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unit.titleController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'unit.title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Topics',
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => _addTopic(unitIndex),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add Topic'),
                    ),
                  ],
                ),
                if (unit.topics.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'No topics added yet.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                ...List<Widget>.generate(
                  unit.topics.length,
                  (topicIndex) =>
                      _buildTopicCard(context, unit, unitIndex, topicIndex),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isBusy =
        _isLoadingSemesters || widget.controller.isPerformingAction.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'Create Syllabus' : 'Edit Syllabus'),
        actions: [
          TextButton(
            onPressed: isBusy ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoadingSemesters) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 12),
              ],
              if (existing != null) ...[
                TextField(
                  controller: _idController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Document ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Text(
                  'Document ID Firebase automatically generate karega.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _semesterIdsController,
                minLines: 2,
                maxLines: 4,
                onChanged: _syncSemesterIdsFromText,
                decoration: const InputDecoration(
                  labelText: 'for',
                  border: OutlineInputBorder(),
                  helperText: 'Semester IDs comma ya new line me likho',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selected semester ids: ${_selectedSemesterIds.length}',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              if (_availableSemesters.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Quick select semesters',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableSemesters
                      .map(
                        (semester) => FilterChip(
                          label: Text('${semester.name} (${semester.id})'),
                          selected: _selectedSemesterIds.contains(semester.id),
                          onSelected: (_) =>
                              _toggleSemesterSelection(semester.id),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'unit',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _addUnit,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Unit'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_units.isEmpty)
                Text(
                  'No units added yet.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ...List<Widget>.generate(_units.length, (unitIndex) {
                return _buildUnitCard(context, unitIndex);
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isBusy ? null : _save,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(
                    existing == null ? 'Create Syllabus' : 'Save Changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditableSyllabusUnit {
  _EditableSyllabusUnit({
    String id = '',
    String title = '',
    List<_EditableSyllabusTopic>? topics,
    this.isExpanded = false,
  }) : localKey = UniqueKey().toString(),
       idController = TextEditingController(text: id),
       titleController = TextEditingController(text: title),
       topics = topics ?? <_EditableSyllabusTopic>[];

  factory _EditableSyllabusUnit.fromRecord(
    SyllabusUnit unit, {
    bool isExpanded = false,
  }) {
    return _EditableSyllabusUnit(
      id: unit.id,
      title: unit.title,
      isExpanded: isExpanded,
      topics: unit.topics
          .map(
            (topic) => _EditableSyllabusTopic(id: topic.id, title: topic.title),
          )
          .toList(),
    );
  }

  factory _EditableSyllabusUnit.withBlankTopic({bool isExpanded = false}) {
    return _EditableSyllabusUnit(
      isExpanded: isExpanded,
      topics: <_EditableSyllabusTopic>[
        _EditableSyllabusTopic(isExpanded: true),
      ],
    );
  }

  final String localKey;
  final TextEditingController idController;
  final TextEditingController titleController;
  final List<_EditableSyllabusTopic> topics;
  bool isExpanded;

  void dispose() {
    idController.dispose();
    titleController.dispose();
    for (final topic in topics) {
      topic.dispose();
    }
  }
}

class _EditableSyllabusTopic {
  _EditableSyllabusTopic({
    String id = '',
    String title = '',
    this.isExpanded = false,
  }) : localKey = UniqueKey().toString(),
       idController = TextEditingController(text: id),
       titleController = TextEditingController(text: title);

  final String localKey;
  final TextEditingController idController;
  final TextEditingController titleController;
  bool isExpanded;

  bool get isBlank =>
      idController.text.trim().isEmpty && titleController.text.trim().isEmpty;

  void dispose() {
    idController.dispose();
    titleController.dispose();
  }
}

Future<bool> _confirmDelete({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  return (await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      )) ??
      false;
}

class _IdNameOption {
  const _IdNameOption({required this.id, required this.name});

  final String id;
  final String name;
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  if (value is String) {
    final normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }
  final normalized = value.toString().trim();
  return normalized.isEmpty ? fallback : normalized;
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}
