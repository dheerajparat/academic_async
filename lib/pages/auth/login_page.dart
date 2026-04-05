import 'package:academic_async/controllers/auth_controller.dart';
import 'package:academic_async/controllers/auth_form_controller.dart';
import 'package:academic_async/controllers/firebase/syllabus_get.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginPage extends GetView<AuthController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthFormController formController = Get.find<AuthFormController>();
    final SyllabusGet syllabusGet = Get.find<SyllabusGet>();
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              colors.primary.withValues(alpha: 0.18),
              colors.tertiary.withValues(alpha: 0.12),
              colors.surface,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -40,
              child: _GlowOrb(
                size: 220,
                color: colors.primary.withValues(alpha: 0.15),
              ),
            ),
            Positioned(
              left: -50,
              bottom: 60,
              child: _GlowOrb(
                size: 180,
                color: colors.tertiary.withValues(alpha: 0.14),
              ),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Obx(
                      () => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AuthHero(colors: colors),
                          const SizedBox(height: 18),
                          Card(
                            elevation: 0,
                            color: colors.surface.withValues(alpha: 0.94),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                              side: BorderSide(
                                color: colors.outlineVariant.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: !formController.isRoleLoaded.value
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 40,
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          formController.isLoginMode.value
                                              ? 'Welcome back'
                                              : 'Create your academic hub',
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w700,
                                            color: colors.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          formController.isLoginMode.value
                                              ? 'Sign in to manage classes, attendance, syllabus, and reminders.'
                                              : 'Set up your student or teacher account in one clean flow.',
                                          style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        SegmentedButton<bool>(
                                          showSelectedIcon: false,
                                          segments: const [
                                            ButtonSegment<bool>(
                                              value: true,
                                              icon: Icon(Icons.login_rounded),
                                              label: Text('Login'),
                                            ),
                                            ButtonSegment<bool>(
                                              value: false,
                                              icon: Icon(
                                                Icons.person_add_alt_1_rounded,
                                              ),
                                              label: Text('Signup'),
                                            ),
                                          ],
                                          selected: {
                                            formController.isLoginMode.value,
                                          },
                                          onSelectionChanged:
                                              (Set<bool> selection) {
                                                final bool shouldLogin =
                                                    selection.first;
                                                if (shouldLogin !=
                                                    formController
                                                        .isLoginMode
                                                        .value) {
                                                  formController.toggleMode();
                                                }
                                              },
                                        ),
                                        const SizedBox(height: 18),
                                        if (formController
                                            .selectedRole
                                            .value
                                            .isNotEmpty)
                                          _RoleStatusBanner(
                                            role: formController
                                                .selectedRole
                                                .value,
                                            onChange: formController.changeRole,
                                          ),
                                        if (formController
                                                .shouldPromptRoleSelection
                                                .value ||
                                            formController
                                                .selectedRole
                                                .value
                                                .isEmpty) ...[
                                          Text(
                                            'Choose how you want to continue',
                                            style: TextStyle(
                                              color: colors.onSurface,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: _RoleOptionCard(
                                                  icon: Icons.school_rounded,
                                                  title: 'Student',
                                                  subtitle:
                                                      'Attendance, syllabus, and academic schedule',
                                                  selected:
                                                      formController
                                                          .selectedRole
                                                          .value ==
                                                      'student',
                                                  onTap: () => formController
                                                      .chooseRole('student'),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: _RoleOptionCard(
                                                  icon: Icons.badge_rounded,
                                                  title: 'Teacher',
                                                  subtitle:
                                                      'Manage teaching requests and subject mapping',
                                                  selected:
                                                      formController
                                                          .selectedRole
                                                          .value ==
                                                      'teacher',
                                                  onTap: () => formController
                                                      .chooseRole('teacher'),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 18),
                                        ],
                                        if (formController
                                            .selectedRole
                                            .value
                                            .isNotEmpty) ...[
                                          if (!formController
                                              .isLoginMode
                                              .value) ...[
                                            TextField(
                                              controller:
                                                  formController.nameController,
                                              decoration: _fieldDecoration(
                                                context,
                                                labelText:
                                                    formController
                                                            .selectedRole
                                                            .value ==
                                                        'teacher'
                                                    ? 'Teacher name'
                                                    : 'Full name',
                                                icon: Icons.person_rounded,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            if (formController
                                                    .selectedRole
                                                    .value ==
                                                'student')
                                              ..._buildStudentSignupFields(
                                                context: context,
                                                syllabusGet: syllabusGet,
                                                formController: formController,
                                              ),
                                            if (formController
                                                    .selectedRole
                                                    .value ==
                                                'teacher')
                                              ..._buildTeacherSignupFields(
                                                context: context,
                                                formController: formController,
                                              ),
                                          ],
                                          TextField(
                                            controller:
                                                formController.emailController,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            decoration: _fieldDecoration(
                                              context,
                                              labelText: 'Email',
                                              icon: Icons.email_rounded,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          TextField(
                                            controller: formController
                                                .passwordController,
                                            obscureText: formController
                                                .obscurePassword
                                                .value,
                                            decoration:
                                                _fieldDecoration(
                                                  context,
                                                  labelText: 'Password',
                                                  icon: Icons.lock_rounded,
                                                ).copyWith(
                                                  suffixIcon: IconButton(
                                                    onPressed: formController
                                                        .togglePasswordVisibility,
                                                    icon: Icon(
                                                      formController
                                                              .obscurePassword
                                                              .value
                                                          ? Icons
                                                                .visibility_rounded
                                                          : Icons
                                                                .visibility_off_rounded,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                          if (formController.isLoginMode.value)
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                onPressed:
                                                    controller.isLoading.value
                                                    ? null
                                                    : () async {
                                                        await controller
                                                            .sendPasswordResetEmail(
                                                              email: formController
                                                                  .emailController
                                                                  .text,
                                                            );
                                                      },
                                                icon: const Icon(
                                                  Icons.mark_email_read_rounded,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  'Forgot password?',
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 12),
                                          FilledButton.icon(
                                            style: FilledButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 15,
                                                  ),
                                            ),
                                            onPressed:
                                                controller.isLoading.value
                                                ? null
                                                : () => _handleSubmit(
                                                    formController:
                                                        formController,
                                                    syllabusGet: syllabusGet,
                                                  ),
                                            icon: controller.isLoading.value
                                                ? const SizedBox(
                                                    height: 18,
                                                    width: 18,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                : Icon(
                                                    formController
                                                            .isLoginMode
                                                            .value
                                                        ? Icons.login_rounded
                                                        : Icons
                                                              .rocket_launch_rounded,
                                                  ),
                                            label: Text(
                                              _ctaText(
                                                role: formController
                                                    .selectedRole
                                                    .value,
                                                isLogin: formController
                                                    .isLoginMode
                                                    .value,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          TextButton(
                                            onPressed:
                                                formController.toggleMode,
                                            child: Text(
                                              formController.isLoginMode.value
                                                  ? 'New here? Switch to signup'
                                                  : 'Already have an account? Switch to login',
                                            ),
                                          ),
                                          if (!formController
                                                  .isLoginMode
                                                  .value &&
                                              formController
                                                      .selectedRole
                                                      .value ==
                                                  'teacher')
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 6,
                                              ),
                                              child: Text(
                                                'Teacher accounts require developer approval before the first login.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit({
    required AuthFormController formController,
    required SyllabusGet syllabusGet,
  }) async {
    final String role = formController.selectedRole.value;
    if (role.isEmpty) {
      Get.snackbar('Role', 'Please choose Student or Teacher first');
      return;
    }

    final String email = formController.emailController.text.trim();
    final String password = formController.passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      Get.snackbar('Validation', 'Email and password are required');
      return;
    }

    if (formController.isLoginMode.value) {
      await controller.signIn(email: email, password: password);
      return;
    }

    final String name = formController.nameController.text.trim();
    if (name.isEmpty) {
      Get.snackbar('Validation', 'Name is required');
      return;
    }

    if (role == 'student') {
      final String registrationNo = formController.registrationNoController.text
          .trim();
      final String branch = syllabusGet.selectedBranchName.value;
      final String semester = syllabusGet.selectedSemesterName.value;
      final String branchId = syllabusGet.selectedBranchId.value;
      final String semesterId = syllabusGet.selectedSemesterId.value;

      if (registrationNo.isEmpty) {
        Get.snackbar('Validation', 'Registration No is required');
        return;
      }
      if (branchId.isEmpty || semesterId.isEmpty) {
        Get.snackbar('Validation', 'Please select branch and semester');
        return;
      }

      await controller.signUpStudent(
        name: name,
        email: email,
        password: password,
        registrationNo: registrationNo,
        branch: branch,
        branchId: branchId,
        semester: semester,
        semesterId: semesterId,
      );
      return;
    }

    final List<String> teacherSubjectIds = formController
        .selectedTeacherSubjectIds
        .toList();
    final List<String> teacherSubjectNames =
        formController.selectedTeacherSubjectNames;
    if (teacherSubjectIds.isEmpty) {
      Get.snackbar('Validation', 'Please select at least one subject');
      return;
    }

    await controller.signUpTeacherRequest(
      name: name,
      email: email,
      password: password,
      teacherSubjectIds: teacherSubjectIds,
      teacherSubjectNames: teacherSubjectNames,
    );
  }

  List<Widget> _buildStudentSignupFields({
    required BuildContext context,
    required SyllabusGet syllabusGet,
    required AuthFormController formController,
  }) {
    return [
      TextField(
        controller: formController.registrationNoController,
        decoration: _fieldDecoration(
          context,
          labelText: 'Registration No',
          icon: Icons.badge_rounded,
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey<String>('branch_${syllabusGet.selectedBranchId.value}'),
        initialValue: syllabusGet.selectedBranchId.value.isEmpty
            ? null
            : syllabusGet.selectedBranchId.value,
        decoration: _fieldDecoration(
          context,
          labelText: 'Branch',
          icon: Icons.account_tree_rounded,
        ),
        items: syllabusGet.branchItems
            .map(
              (Map<String, String> branch) => DropdownMenuItem<String>(
                value: branch['id']!,
                child: Text(branch['name']!),
              ),
            )
            .toList(),
        onChanged: syllabusGet.isLoadingBranches.value
            ? null
            : (String? branchId) async {
                if (branchId == null || branchId.trim().isEmpty) {
                  return;
                }
                final Map<String, String>? branch = syllabusGet.findBranchById(
                  branchId,
                );
                if (branch == null) {
                  return;
                }
                await syllabusGet.selectBranch(
                  branchId: branch['id']!,
                  branchName: branch['name']!,
                );
              },
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        key: ValueKey<String>(
          'semester_${syllabusGet.selectedSemesterId.value}',
        ),
        initialValue: syllabusGet.selectedSemesterId.value.isEmpty
            ? null
            : syllabusGet.selectedSemesterId.value,
        decoration: _fieldDecoration(
          context,
          labelText: 'Semester',
          icon: Icons.layers_rounded,
        ),
        items: syllabusGet.semesterItems
            .map(
              (Map<String, String> semester) => DropdownMenuItem<String>(
                value: semester['id']!,
                child: Text(semester['name']!),
              ),
            )
            .toList(),
        onChanged: syllabusGet.isLoadingSemesters.value
            ? null
            : (String? semesterId) {
                if (semesterId == null || semesterId.trim().isEmpty) {
                  return;
                }
                final Map<String, String>? semester = syllabusGet
                    .findSemesterById(semesterId);
                if (semester == null) {
                  return;
                }
                syllabusGet.selectSemester(
                  semesterId: semester['id']!,
                  semesterName: semester['name']!,
                );
              },
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _buildTeacherSignupFields({
    required BuildContext context,
    required AuthFormController formController,
  }) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select the subjects you teach',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'These are pulled from the syllabus collection so your request stays aligned with the academic structure.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.3),
            ),
            if (formController.isLoadingTeacherSubjects.value) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 3),
            ],
            if (formController.teacherSubjectsError.value != null) ...[
              const SizedBox(height: 8),
              Text(
                formController.teacherSubjectsError.value!,
                style: TextStyle(color: colors.error),
              ),
            ],
            if (formController.teacherSubjectOptions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: formController.teacherSubjectOptions.map((subject) {
                  final bool selected = formController.selectedTeacherSubjectIds
                      .contains(subject.id);
                  return FilterChip(
                    label: Text(subject.name),
                    selected: selected,
                    onSelected: (_) =>
                        formController.toggleTeacherSubject(subject.id),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton.icon(
                  onPressed: formController.loadTeacherSubjects,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reload'),
                ),
                const Spacer(),
                Text(
                  '${formController.selectedTeacherSubjectIds.length} selected',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String labelText,
    required IconData icon,
  }) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: labelText,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.primary, width: 1.6),
      ),
    );
  }

  String _ctaText({required String role, required bool isLogin}) {
    if (isLogin) {
      return role == 'teacher' ? 'Login as Teacher' : 'Login as Student';
    }
    return role == 'teacher' ? 'Request Teacher Signup' : 'Sign Up as Student';
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.primary,
            colors.tertiary.withValues(alpha: 0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Academic Async',
              style: GoogleFonts.spaceGrotesk(
                color: colors.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'One place for events, attendance, syllabus, and routine.',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: colors.onPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Stay on top of your academic flow with a cleaner login, sharper schedule tools, and a workspace built for campus life.',
            style: TextStyle(
              color: colors.onPrimary.withValues(alpha: 0.9),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeroPill(label: 'Attendance'),
              _HeroPill(label: 'Routine'),
              _HeroPill(label: 'Syllabus'),
              _HeroPill(label: 'Events'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RoleStatusBanner extends StatelessWidget {
  const _RoleStatusBanner({required this.role, required this.onChange});

  final String role;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            role == 'teacher' ? Icons.badge_rounded : Icons.school_rounded,
            color: colors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Continuing as ${role == 'teacher' ? 'Teacher' : 'Student'}',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(onPressed: onChange, child: const Text('Change')),
        ],
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer.withValues(alpha: 0.78)
              : colors.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? colors.primary : colors.onSurface),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
