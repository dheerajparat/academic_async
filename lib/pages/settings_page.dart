import 'package:academic_async/controllers/auth_controller.dart';
import 'package:academic_async/controllers/menu_controller.dart';
import 'package:academic_async/controllers/settings_controller.dart';
import 'package:academic_async/controllers/update_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:academic_async/widgets/settings/settings_bottom_sheets.dart';
import 'package:academic_async/widgets/settings/settings_components.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final MenuControllerX menuController = Get.find<MenuControllerX>();
    final UpdateController updateController = Get.find<UpdateController>();

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
            Obx(
              () => SettingsGroup(
                children: [
                  ListTile(
                    leading: const Icon(Icons.system_update_alt_rounded),
                    trailing: updateController.isChecking.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    title: const Text(
                      'App Updates',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      updateController.errorMessage.value ??
                          (updateController.statusMessage.value.isNotEmpty
                              ? updateController.statusMessage.value
                              : 'Current: ${updateController.currentVersionLabel.value}'),
                    ),
                    onTap: updateController.isChecking.value
                        ? null
                        : () => updateController.checkForUpdates(),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Installed: ${updateController.currentVersionLabel.value}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Device ABI: ${updateController.deviceAbiLabel.value}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Latest release: ${updateController.latestVersionLabel}',
                        ),
                        if (updateController.latestRelease.value != null) ...[
                          if (updateController.latestRelease.value!.assetName
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Selected APK: ${updateController.latestRelease.value!.assetName}',
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            updateController
                                .latestRelease
                                .value!
                                .selectionLabel,
                          ),
                        ],
                        if (updateController.latestRelease.value?.publishedAt !=
                            null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Published: ${_formatUpdateDate(updateController.latestRelease.value!.publishedAt!)}',
                            ),
                          ),
                        if (updateController.isDownloading.value) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: updateController.downloadProgress.value <= 0
                                ? null
                                : updateController.downloadProgress.value,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            updateController.downloadProgress.value <= 0
                                ? 'Downloading update...'
                                : 'Downloading ${(updateController.downloadProgress.value * 100).round()}%',
                          ),
                        ],
                        if (updateController.latestRelease.value?.releaseNotes
                                .trim()
                                .isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'Release notes',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _shortReleaseNotes(
                              updateController
                                  .latestRelease
                                  .value!
                                  .releaseNotes,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: updateController.isChecking.value
                                  ? null
                                  : () => updateController.checkForUpdates(),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Check now'),
                            ),
                            if (updateController.isUpdateAvailable)
                              FilledButton.icon(
                                onPressed: updateController.isDownloading.value
                                    ? null
                                    : updateController.downloadAndInstallUpdate,
                                icon: Icon(
                                  updateController.supportsInAppInstall
                                      ? Icons.download_for_offline_rounded
                                      : Icons.open_in_new_rounded,
                                ),
                                label: Text(
                                  updateController.supportsInAppInstall &&
                                          updateController.hasDownloadAsset
                                      ? 'Download & Install'
                                      : 'Open Release',
                                ),
                              ),
                            if (updateController.latestRelease.value != null)
                              OutlinedButton.icon(
                                onPressed: updateController.openReleasePage,
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('Release page'),
                              ),
                          ],
                        ),
                        if (!updateController.supportsInAppInstall) ...[
                          const SizedBox(height: 12),
                          const Text(
                            'In-app APK install is supported on Android only. Other platforms will open the release page.',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _shortReleaseNotes(String raw) {
  final List<String> lines = raw
      .trim()
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .take(5)
      .toList();
  return lines.join('\n');
}

String _formatUpdateDate(DateTime value) {
  final DateTime local = value.toLocal();
  final String year = local.year.toString().padLeft(4, '0');
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
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
