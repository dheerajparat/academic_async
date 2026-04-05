import 'package:academic_async/controllers/auth_controller.dart';
import 'package:academic_async/controllers/menu_controller.dart';
import 'package:academic_async/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:academic_async/widgets/settings/app_update_section.dart';
import 'package:academic_async/widgets/settings/settings_bottom_sheets.dart';
import 'package:academic_async/widgets/settings/settings_components.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final MenuControllerX menuController = Get.find<MenuControllerX>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionHeader(
              title: 'General Settings',
              subtitle: 'Appearance, account and about settings',
            ),
            SettingsGroup(
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  title: const Text(
                    'Appearance',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Theme mode and accent color'),
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const AppearanceSheet(),
                    );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile.adaptive(
                  secondary: const Icon(Icons.calendar_view_week_rounded),
                  title: const Text(
                    'Show routine in menu',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Display the routine shortcut card only on the Menu page',
                  ),
                  value: menuController.showRoutineInMenu.value,
                  onChanged: (bool value) async {
                    await menuController.toggleShowRoutineInMenu(value);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  title: const Text(
                    'Account',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    authController.user.value?.email ?? 'No account signed in',
                  ),
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (_) =>
                          AccountSheet(authController: authController),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  title: const Text(
                    'About',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('App overview and usage'),
                  onTap: () => _showAboutDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Community',
              subtitle: 'Developers and contributors',
            ),
            CommunityGroup(
              isLoading: controller.isDevelopersLoading.value,
              errorMessage: controller.developersError.value,
              developers: controller.developers,
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'App Info',
              subtitle: 'Current build details',
            ),
            SettingsGroup(
              children: [
                const InfoTile(
                  title: 'Application',
                  value: SettingsController.appName,
                  icon: Icons.apps_rounded,
                ),
                const Divider(height: 1),
                const InfoTile(
                  title: 'Version',
                  value: SettingsController.appVersion,
                  icon: Icons.verified_outlined,
                ),
                const Divider(height: 1),
                InfoTile(
                  title: 'Platform',
                  value: controller.platformLabel,
                  icon: Icons.phone_android_rounded,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const SectionHeader(
              title: 'Updates',
              subtitle: 'GitHub release based APK updates with ABI matching',
            ),
            const AppUpdateSection(),
          ],
        ),
      ),
    );
  }
}

void _showAboutDialog(BuildContext context) {
  showAboutDialog(
    context: context,
    applicationName: SettingsController.appName,
    applicationVersion: SettingsController.appVersion,
    applicationLegalese: 'Built for academic planning and reminders.',
    children: const [
      Text(
        'Academic Async helps students track events, schedules, and tasks in one place.',
      ),
    ],
  );
}
