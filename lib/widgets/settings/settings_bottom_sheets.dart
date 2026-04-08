import 'package:academic_async/controllers/attendance_controller.dart';
import 'package:academic_async/controllers/auth_controller.dart';
import 'package:academic_async/controllers/theme_controller.dart';
import 'package:academic_async/controllers/get_user_data.dart';
import 'package:academic_async/pages/profile_edit_page.dart';
import 'package:academic_async/widgets/settings/settings_components.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppearanceSheet extends GetView<ThemeController> {
  const AppearanceSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Obx(
          () => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Appearance',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Theme Mode',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      icon: Icon(Icons.settings_suggest_rounded),
                      label: Text('System'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded),
                      label: Text('Light'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded),
                      label: Text('Dark'),
                    ),
                  ],
                  selected: {controller.themeMode.value},
                  onSelectionChanged: (selection) async {
                    await controller.updateTheme(selection.first);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'Theme Color',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${ThemeController.availableColors.length} accent colors available',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final int crossAxisCount = constraints.maxWidth >= 520
                        ? 5
                        : constraints.maxWidth >= 360
                        ? 4
                        : 3;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ThemeController.availableColors.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.05,
                      ),
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        final Color color =
                            ThemeController.availableColors[index];
                        final bool isSelected =
                            controller.seedColor.value == color;
                        return ThemePreviewCard(
                          color: color,
                          isSelected: isSelected,
                          onTap: () async {
                            await controller.updateSeedColor(color);
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AccountSheet extends StatelessWidget {
  const AccountSheet({super.key, required this.authController});

  final AuthController authController;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String? email = authController.user.value?.email;
    final UserDataController userDataController =
        Get.find<UserDataController>();
    final AttendanceController attendanceController =
        Get.find<AttendanceController>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Account',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(email ?? 'No account signed in'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: userDataController.isProfileLoaded.value
                  ? () async {
                      if (context.mounted) {
                        Navigator.of(context).maybePop();
                      }
                      await Get.to<void>(() => const ProfileEditPage());
                    }
                  : null,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Edit Profile'),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: email == null
                  ? null
                  : () async {
                      if (!attendanceController.canPerformProtectedAction(
                        actionLabel: 'logging out',
                      )) {
                        return;
                      }
                      await authController.signOut();
                      if (context.mounted) {
                        Navigator.of(context).maybePop();
                      }
                    },
              icon: Icon(Icons.logout_rounded, color: colorScheme.error),
              label: Text(
                'Logout',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
