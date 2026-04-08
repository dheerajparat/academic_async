import 'dart:async';
import 'dart:io';

import 'package:academic_async/config/app_update_config.dart';
import 'package:academic_async/models/app_update_models.dart';
import 'package:academic_async/services/app_update_service.dart';
import 'package:academic_async/widgets/markdownview.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class UpdateController extends GetxController with WidgetsBindingObserver {
  final Rxn<AppReleaseInfo> latestRelease = Rxn<AppReleaseInfo>();
  final RxString currentVersionLabel = 'Loading...'.obs;
  final RxString deviceAbiLabel = 'Detecting...'.obs;
  final RxBool isChecking = false.obs;
  final RxBool isDownloading = false.obs;
  final RxDouble downloadProgress = 0.0.obs;
  final RxString statusMessage = ''.obs;
  final RxnString errorMessage = RxnString();

  AppVersionInfo? _currentVersion;
  DeviceAbiInfo? _deviceAbiInfo;
  String _downloadedFilePath = '';
  String _downloadedAssetName = '';
  bool _didPromptThisSession = false;
  bool _isAwaitingInstallPermission = false;
  bool _isOpeningInstaller = false;

  bool get isConfigured => AppUpdateConfig.isConfigured;
  bool get supportsInAppInstall => AppUpdateService.isAndroidSideloadSupported;
  bool get isUpdateAvailable => latestRelease.value?.isNewerThanCurrent == true;
  bool get hasDownloadAsset => latestRelease.value?.hasDownloadAsset == true;
  bool get hasReleaseNotes => normalizedReleaseNotes(
    latestRelease.value?.releaseNotes ?? '',
  ).isNotEmpty;
  String get latestVersionLabel =>
      latestRelease.value?.versionTag.trim().isNotEmpty == true
      ? latestRelease.value!.versionTag
      : 'Not checked yet';
  String get publishedAtLabel {
    final DateTime? publishedAt = latestRelease.value?.publishedAt;
    if (publishedAt == null) {
      return '';
    }
    return formatUpdateDate(publishedAt);
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_bootstrap());
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_resumePendingInstallIfAllowed());
    }
  }

  Future<void> _bootstrap() async {
    await _loadCurrentVersion();
    await _loadDeviceAbiInfo();
    await checkForUpdates(silent: true, promptIfAvailable: true);
  }

  Future<void> _loadCurrentVersion() async {
    try {
      _currentVersion = await AppUpdateService.loadCurrentVersion();
      currentVersionLabel.value = _currentVersion!.displayVersion;
    } catch (_) {
      currentVersionLabel.value = 'Unavailable';
    }
  }

  Future<void> _loadDeviceAbiInfo() async {
    try {
      _deviceAbiInfo = await AppUpdateService.loadDeviceAbiInfo();
      deviceAbiLabel.value = _deviceAbiInfo!.displayLabel;
    } catch (_) {
      deviceAbiLabel.value = 'Universal fallback';
    }
  }

  Future<void> checkForUpdates({
    bool silent = false,
    bool promptIfAvailable = false,
  }) async {
    if (isChecking.value) {
      return;
    }

    if (!isConfigured) {
      latestRelease.value = null;
      statusMessage.value =
          'GitHub update source is not configured for this build';
      if (!silent) {
        errorMessage.value = null;
      }
      return;
    }

    isChecking.value = true;
    if (!silent) {
      errorMessage.value = null;
      statusMessage.value = 'Checking GitHub releases...';
    }

    try {
      _currentVersion ??= await AppUpdateService.loadCurrentVersion();
      currentVersionLabel.value = _currentVersion!.displayVersion;

      final AppReleaseInfo? release = await AppUpdateService.fetchLatestRelease(
        currentVersion: _currentVersion!,
        deviceAbiInfo: _deviceAbiInfo,
      );
      latestRelease.value = release;

      if (release == null) {
        statusMessage.value = 'No published release found yet';
        return;
      }

      if (release.isNewerThanCurrent) {
        statusMessage.value = release.hasDownloadAsset
            ? 'Version ${release.versionTag} is available for ${release.assetName}'
            : 'Version ${release.versionTag} is available, but no matching APK asset was found';
        if (promptIfAvailable) {
          unawaited(_promptForAvailableUpdate(release));
        }
      } else {
        statusMessage.value =
            'You are already on the latest version for ${deviceAbiLabel.value}';
      }
    } catch (error) {
      if (!silent) {
        errorMessage.value = 'Unable to check updates right now';
      }
      statusMessage.value = silent ? statusMessage.value : '';
      debugPrint('Update check failed: $error');
    } finally {
      isChecking.value = false;
    }
  }

  Future<void> downloadAndInstallUpdate() async {
    final AppReleaseInfo? release = latestRelease.value;
    if (release == null) {
      await checkForUpdates();
      return;
    }

    if (!release.isNewerThanCurrent) {
      Get.snackbar('Update', 'You are already on the latest version');
      return;
    }

    if (!release.hasDownloadAsset) {
      await openReleasePage();
      return;
    }

    if (isDownloading.value) {
      return;
    }

    errorMessage.value = null;
    statusMessage.value = 'Downloading ${release.assetName}...';
    isDownloading.value = true;
    downloadProgress.value = 0;
    _isAwaitingInstallPermission = false;

    try {
      final String apkPath;
      if (_downloadedFilePath.trim().isNotEmpty &&
          _downloadedAssetName == release.assetName &&
          File(_downloadedFilePath).existsSync()) {
        apkPath = _downloadedFilePath;
      } else {
        apkPath = await AppUpdateService.downloadReleaseApk(
          release: release,
          onProgress: (double value) {
            downloadProgress.value = value.clamp(0, 1);
          },
        );
        _downloadedFilePath = apkPath;
        _downloadedAssetName = release.assetName;
      }

      statusMessage.value = 'Download complete. Opening installer...';
      await _installDownloadedApk(apkPath);
    } catch (error) {
      if (error is AppUpdatePermissionRequiredException) {
        errorMessage.value =
            'Allow app installs from this source and return to the app. The installer will open automatically.';
        statusMessage.value = 'Waiting for install permission...';
      } else {
        errorMessage.value = 'Unable to download or install the update';
        statusMessage.value = '';
      }
      debugPrint('Update download/install failed: $error');
    } finally {
      isDownloading.value = false;
    }
  }

  Future<void> openReleasePage() async {
    final String? htmlUrl = latestRelease.value?.htmlUrl;
    await AppUpdateService.openReleasePage(url: htmlUrl);
  }

  Future<void> _installDownloadedApk(String apkPath) async {
    if (_isOpeningInstaller) {
      return;
    }

    try {
      final bool canInstall =
          await AppUpdateService.canRequestPackageInstalls();
      if (!canInstall) {
        _isAwaitingInstallPermission = true;
        await _showInstallPermissionDialog();
        throw const AppUpdatePermissionRequiredException();
      }
      _isAwaitingInstallPermission = false;
      _isOpeningInstaller = true;
      errorMessage.value = null;
      await AppUpdateService.installDownloadedApk(apkPath);
      statusMessage.value =
          'Installer opened. Confirm the install to finish updating.';
      Get.snackbar(
        'Update',
        'Android installer opened. Confirm the install to finish updating.',
      );
    } on AppUpdatePermissionRequiredException {
      rethrow;
    } finally {
      _isOpeningInstaller = false;
    }
  }

  Future<void> _resumePendingInstallIfAllowed() async {
    if (!_isAwaitingInstallPermission ||
        _downloadedFilePath.trim().isEmpty ||
        _isOpeningInstaller) {
      return;
    }

    final File apkFile = File(_downloadedFilePath);
    if (!apkFile.existsSync()) {
      _isAwaitingInstallPermission = false;
      return;
    }

    final bool canInstall = await AppUpdateService.canRequestPackageInstalls();
    if (!canInstall) {
      return;
    }

    errorMessage.value = null;
    statusMessage.value = 'Permission granted. Opening installer...';
    try {
      await _installDownloadedApk(_downloadedFilePath);
    } catch (error) {
      errorMessage.value = 'Unable to open the installer after permission';
      statusMessage.value = '';
      debugPrint('Pending install resume failed: $error');
    }
  }

  Future<void> _promptForAvailableUpdate(AppReleaseInfo release) async {
    if (_didPromptThisSession) {
      return;
    }
    if ((Get.isDialogOpen ?? false) || Get.context == null) {
      return;
    }

    _didPromptThisSession = true;
    final BuildContext context = Get.context!;
    final String releaseNotes = normalizedReleaseNotes(release.releaseNotes);
    final double maxDialogHeight = MediaQuery.sizeOf(context).height * 0.6;
    await Get.dialog<void>(
      AlertDialog(
        title: const Text('Update Available'),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxDialogHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current version: ${currentVersionLabel.value}\nLatest version: ${release.versionTag}',
                ),
                if (releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'What changed',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  MarkdownView(data: releaseNotes),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Get.back<void>();
              unawaited(downloadAndInstallUpdate());
            },
            child: Text(
              release.hasDownloadAsset ? 'Update now' : 'Open release',
            ),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  Future<void> _showInstallPermissionDialog() async {
    if (Get.context == null) {
      return;
    }

    await Get.dialog<void>(
      AlertDialog(
        title: const Text('Allow App Install'),
        content: const Text(
          'Android needs permission to install the downloaded APK from this app source. Open settings, allow the permission, then return to the app. The installer will continue automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back<void>(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Get.back<void>();
              await AppUpdateService.openUnknownAppSourcesSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  String normalizedReleaseNotes(String raw) {
    return raw.replaceAll('\r\n', '\n').trim();
  }

  String summarizedReleaseNotes(String raw, {int maxLines = 6}) {
    final String trimmed = normalizedReleaseNotes(raw);
    if (trimmed.isEmpty) {
      return '';
    }
    final List<String> lines = trimmed
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(maxLines)
        .toList();
    return lines.join('\n');
  }

  String formatUpdateDate(DateTime value) {
    final DateTime local = value.toLocal();
    final String year = local.year.toString().padLeft(4, '0');
    final String month = local.month.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
