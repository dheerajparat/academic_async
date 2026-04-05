import 'package:academic_async/controllers/update_controller.dart';
import 'package:academic_async/widgets/markdownview.dart';
import 'package:academic_async/widgets/settings/settings_components.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AppUpdateSection extends GetView<UpdateController> {
  const AppUpdateSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SettingsGroup(
        children: [
          _ExpandableSettingsTile(
            leading: const Icon(Icons.system_update_alt_rounded),
            title: 'App Updates',
            subtitle:
                controller.errorMessage.value ??
                (controller.statusMessage.value.isNotEmpty
                    ? controller.statusMessage.value
                    : 'Current: ${controller.currentVersionLabel.value}'),
            initiallyExpanded: false,
            headerTrailing: controller.isChecking.value
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Installed: ${controller.currentVersionLabel.value}'),
                  const SizedBox(height: 4),
                  Text('Device ABI: ${controller.deviceAbiLabel.value}'),
                  const SizedBox(height: 4),
                  Text('Latest release: ${controller.latestVersionLabel}'),
                  if (controller.latestRelease.value != null) ...[
                    if (controller.latestRelease.value!.assetName
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Selected APK: ${controller.latestRelease.value!.assetName}',
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(controller.latestRelease.value!.selectionLabel),
                  ],
                  if (controller.publishedAtLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Published: ${controller.publishedAtLabel}'),
                    ),
                  if (controller.isDownloading.value) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: controller.downloadProgress.value <= 0
                          ? null
                          : controller.downloadProgress.value,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      controller.downloadProgress.value <= 0
                          ? 'Downloading update...'
                          : 'Downloading ${(controller.downloadProgress.value * 100).round()}%',
                    ),
                  ],
                  if (controller.hasReleaseNotes) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Release notes',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    MarkdownView(
                      data: controller.normalizedReleaseNotes(
                        controller.latestRelease.value?.releaseNotes ?? '',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: controller.isChecking.value
                            ? null
                            : () => controller.checkForUpdates(),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Check now'),
                      ),
                      if (controller.isUpdateAvailable)
                        FilledButton.icon(
                          onPressed: controller.isDownloading.value
                              ? null
                              : controller.downloadAndInstallUpdate,
                          icon: Icon(
                            controller.supportsInAppInstall
                                ? Icons.download_for_offline_rounded
                                : Icons.open_in_new_rounded,
                          ),
                          label: Text(
                            controller.supportsInAppInstall &&
                                    controller.hasDownloadAsset
                                ? 'Download & Install'
                                : 'Open Release',
                          ),
                        ),
                      if (controller.latestRelease.value != null)
                        OutlinedButton.icon(
                          onPressed: controller.openReleasePage,
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Release page'),
                        ),
                    ],
                  ),
                  if (!controller.supportsInAppInstall) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'In-app APK install is supported on Android only. Other platforms will open the release page.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableSettingsTile extends StatefulWidget {
  const _ExpandableSettingsTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.child,
    this.headerTrailing,
    this.initiallyExpanded = false,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? headerTrailing;
  final bool initiallyExpanded;

  @override
  State<_ExpandableSettingsTile> createState() => _ExpandableSettingsTileState();
}

class _ExpandableSettingsTileState extends State<_ExpandableSettingsTile> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: widget.leading,
          title: Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(widget.subtitle),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.headerTrailing != null) ...[
                widget.headerTrailing!,
                const SizedBox(width: 8),
              ],
              AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.expand_more_rounded),
              ),
            ],
          ),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _isExpanded
              ? Column(
                  children: [
                    const Divider(height: 1),
                    widget.child,
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
