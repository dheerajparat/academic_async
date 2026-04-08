import 'dart:convert';
import 'dart:io';

import 'package:academic_async/config/app_update_config.dart';
import 'package:academic_async/models/app_update_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdatePermissionRequiredException implements Exception {
  const AppUpdatePermissionRequiredException();

  @override
  String toString() => 'App install permission is required';
}

class AppUpdateService {
  AppUpdateService._();

  static const MethodChannel _channel = MethodChannel(
    'academic_async/update_installer',
  );
  static const String _updatesDirectoryName = 'updates';

  static bool get isAndroidSideloadSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<AppVersionInfo> loadCurrentVersion() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    return AppVersionInfo(
      appName: info.appName,
      packageName: info.packageName,
      version: info.version.trim(),
      buildNumber: info.buildNumber.trim(),
    );
  }

  static Future<DeviceAbiInfo> loadDeviceAbiInfo() async {
    if (!isAndroidSideloadSupported) {
      return const DeviceAbiInfo(supportedAbis: <String>[]);
    }

    final List<dynamic>? raw = await _channel.invokeListMethod<dynamic>(
      'getSupportedAbis',
    );
    final List<String> supportedAbis = (raw ?? const <dynamic>[])
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();
    return DeviceAbiInfo(supportedAbis: supportedAbis);
  }

  static Future<AppReleaseInfo?> fetchLatestRelease({
    required AppVersionInfo currentVersion,
    DeviceAbiInfo? deviceAbiInfo,
  }) async {
    if (!AppUpdateConfig.isConfigured) {
      return null;
    }

    final DeviceAbiInfo abiInfo = deviceAbiInfo ?? await loadDeviceAbiInfo();

    final Uri uri = Uri.parse(AppUpdateConfig.latestReleaseApiUrl);
    final http.Response response = await http.get(
      uri,
      headers: const <String, String>{
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'GitHub update check failed with status ${response.statusCode}',
        uri: uri,
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Invalid GitHub release response');
    }

    final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
    final String versionTag = _readString(
      map['tag_name'],
      fallback: _readString(map['name']),
    );
    if (versionTag.isEmpty) {
      return null;
    }

    final List<Map<String, dynamic>> assets =
        (map['assets'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map<dynamic, dynamic>>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

    final _AssetMatch? apkAsset = _selectBestApkAsset(assets, abiInfo);

    return AppReleaseInfo(
      versionTag: versionTag,
      downloadUrl: apkAsset == null
          ? ''
          : _readString(
              apkAsset.asset['browser_download_url'],
              fallback: _readString(apkAsset.asset['url']),
            ),
      assetName: apkAsset == null
          ? ''
          : _readString(
              apkAsset.asset['name'],
              fallback: AppUpdateConfig.apkAssetName,
            ),
      releaseNotes: _readString(map['body']),
      htmlUrl: _readString(
        map['html_url'],
        fallback: AppUpdateConfig.releasesPageUrl,
      ),
      publishedAt: _tryParseDate(map['published_at']),
      isNewerThanCurrent: _isRemoteVersionNewer(
        currentVersion.displayVersion,
        versionTag,
      ),
      selectionLabel: apkAsset?.selectionLabel ?? 'No compatible APK found',
      matchedDeviceAbi: apkAsset?.matchedDeviceAbi ?? abiInfo.primaryAbi,
    );
  }

  static Future<String> downloadReleaseApk({
    required AppReleaseInfo release,
    ValueChanged<double>? onProgress,
  }) async {
    if (!isAndroidSideloadSupported) {
      throw UnsupportedError('In-app APK install is supported on Android only');
    }
    if (!release.hasDownloadAsset) {
      throw const HttpException('No APK asset found on the latest release');
    }

    final Directory updatesDir = Directory(
      await _resolveUpdateStorageDirectoryPath(),
    );
    if (!updatesDir.existsSync()) {
      await updatesDir.create(recursive: true);
    }

    final String assetName = _sanitizeFileName(release.assetName);
    final File file = File('${updatesDir.path}/$assetName');
    if (file.existsSync()) {
      await file.delete();
    }

    final http.Client client = http.Client();
    try {
      final http.StreamedResponse response = await client.send(
        http.Request('GET', Uri.parse(release.downloadUrl)),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'APK download failed with status ${response.statusCode}',
          uri: Uri.parse(release.downloadUrl),
        );
      }

      final IOSink sink = file.openWrite();
      try {
        final int totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;

        await for (final List<int> chunk in response.stream) {
          receivedBytes += chunk.length;
          sink.add(chunk);
          if (totalBytes > 0 && onProgress != null) {
            onProgress(receivedBytes / totalBytes);
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
    } finally {
      client.close();
    }

    onProgress?.call(1);
    return file.path;
  }

  static Future<bool> canRequestPackageInstalls() async {
    if (!isAndroidSideloadSupported) {
      return false;
    }
    final bool? value = await _channel.invokeMethod<bool>(
      'canRequestPackageInstalls',
    );
    return value ?? false;
  }

  static Future<void> openUnknownAppSourcesSettings() async {
    if (!isAndroidSideloadSupported) {
      return;
    }
    await _channel.invokeMethod<void>('openUnknownAppSourcesSettings');
  }

  static Future<void> installDownloadedApk(String apkPath) async {
    if (!isAndroidSideloadSupported) {
      throw UnsupportedError('In-app APK install is supported on Android only');
    }

    try {
      await _channel.invokeMethod<void>('installApk', <String, dynamic>{
        'path': apkPath,
      });
    } on PlatformException catch (error) {
      if (error.code == 'install_permission_required') {
        throw const AppUpdatePermissionRequiredException();
      }
      rethrow;
    }
  }

  static Future<void> openReleasePage({String? url}) async {
    final Uri uri = Uri.parse(
      (url == null || url.trim().isEmpty)
          ? AppUpdateConfig.releasesPageUrl
          : url,
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<String> _resolveUpdateStorageDirectoryPath() async {
    if (!isAndroidSideloadSupported) {
      return '${Directory.systemTemp.path}/$_updatesDirectoryName';
    }

    try {
      final String? path = await _channel.invokeMethod<String>(
        'getUpdateStorageDir',
      );
      final String normalized = (path ?? '').trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    } on MissingPluginException {
      debugPrint('Update installer channel missing getUpdateStorageDir');
    } on PlatformException catch (error) {
      debugPrint('Update storage path lookup failed: ${error.message}');
    }

    return '${Directory.systemTemp.path}/$_updatesDirectoryName';
  }

  static String _sanitizeFileName(String value) {
    final String trimmed = value.trim();
    final String fallback = AppUpdateConfig.apkAssetName.trim().isNotEmpty
        ? AppUpdateConfig.apkAssetName.trim()
        : 'app-update.apk';
    final String candidate = trimmed.isEmpty ? fallback : trimmed;
    final String normalized = candidate.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    return normalized.isEmpty ? 'app-update.apk' : normalized;
  }

  static bool _isRemoteVersionNewer(String currentRaw, String remoteRaw) {
    final _ParsedVersion current = _ParsedVersion.parse(currentRaw);
    final _ParsedVersion remote = _ParsedVersion.parse(remoteRaw);
    return remote.compareTo(current) > 0;
  }

  static String _readString(dynamic value, {String fallback = ''}) {
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

  static DateTime? _tryParseDate(dynamic value) {
    final String raw = _readString(value);
    if (raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static Map<String, dynamic>? _findFirstAsset(
    List<Map<String, dynamic>> assets,
    bool Function(Map<String, dynamic> asset) test,
  ) {
    for (final Map<String, dynamic> asset in assets) {
      if (test(asset)) {
        return asset;
      }
    }
    return null;
  }

  static _AssetMatch? _selectBestApkAsset(
    List<Map<String, dynamic>> assets,
    DeviceAbiInfo abiInfo,
  ) {
    final List<Map<String, dynamic>> apkAssets = assets
        .where(
          (asset) => _readString(asset['name']).toLowerCase().endsWith('.apk'),
        )
        .toList();
    if (apkAssets.isEmpty) {
      return null;
    }

    for (final String abi in abiInfo.supportedAbis) {
      final Map<String, dynamic>? abiAsset = _findFirstAsset(
        apkAssets,
        (asset) => _assetMatchesAbi(_readString(asset['name']), abi),
      );
      if (abiAsset != null) {
        return _AssetMatch(
          asset: abiAsset,
          selectionLabel: 'Matched device ABI: $abi',
          matchedDeviceAbi: abi,
        );
      }
    }

    final Map<String, dynamic>? configuredAsset = _findFirstAsset(
      apkAssets,
      (asset) =>
          _readString(asset['name']).toLowerCase() ==
          AppUpdateConfig.apkAssetName.toLowerCase(),
    );
    if (configuredAsset != null) {
      return _AssetMatch(
        asset: configuredAsset,
        selectionLabel: 'Using configured fallback APK',
        matchedDeviceAbi: abiInfo.primaryAbi,
      );
    }

    final Map<String, dynamic>? universalAsset = _findFirstAsset(
      apkAssets,
      (asset) => _assetIsUniversal(_readString(asset['name'])),
    );
    if (universalAsset != null) {
      return _AssetMatch(
        asset: universalAsset,
        selectionLabel: 'Using universal APK fallback',
        matchedDeviceAbi: abiInfo.primaryAbi,
      );
    }

    return _AssetMatch(
      asset: apkAssets.first,
      selectionLabel: 'Using the first APK asset from the release',
      matchedDeviceAbi: abiInfo.primaryAbi,
    );
  }

  static bool _assetIsUniversal(String assetName) {
    final String lowerName = assetName.toLowerCase();
    for (final String keyword in AppUpdateConfig.universalAssetKeywords) {
      if (_containsAssetToken(lowerName, keyword)) {
        return true;
      }
    }
    return false;
  }

  static bool _assetMatchesAbi(String assetName, String abi) {
    final String lowerAssetName = assetName.toLowerCase();
    final String lowerAbi = abi.toLowerCase();

    switch (lowerAbi) {
      case 'arm64-v8a':
        return _matchesAnyPattern(lowerAssetName, const <String>[
          r'(^|[^a-z0-9])(arm64-v8a|arm64_v8a|arm64|aarch64|v8a|abi8a)([^a-z0-9]|$)',
        ]);
      case 'armeabi-v7a':
        return _matchesAnyPattern(lowerAssetName, const <String>[
          r'(^|[^a-z0-9])(armeabi-v7a|armeabi_v7a|armeabi7a|armv7|arm32|v7a|abi7a)([^a-z0-9]|$)',
        ]);
      case 'x86_64':
        return _matchesAnyPattern(lowerAssetName, const <String>[
          r'(^|[^a-z0-9])(x86[-_]?64|x64)([^a-z0-9]|$)',
        ]);
      case 'x86':
        return _matchesAnyPattern(lowerAssetName, const <String>[
              r'(^|[^a-z0-9])x86([^a-z0-9]|$)',
            ]) &&
            !_matchesAnyPattern(lowerAssetName, const <String>[
              r'(^|[^a-z0-9])(x86[-_]?64|x64)([^a-z0-9]|$)',
            ]);
      default:
        return _containsAssetToken(lowerAssetName, lowerAbi);
    }
  }

  static bool _containsAssetToken(String assetName, String token) {
    final RegExp pattern = RegExp(
      '(^|[^a-z0-9])${RegExp.escape(token.toLowerCase())}([^a-z0-9]|\$)',
      caseSensitive: false,
    );
    return pattern.hasMatch(assetName);
  }

  static bool _matchesAnyPattern(String assetName, List<String> patterns) {
    for (final String pattern in patterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(assetName)) {
        return true;
      }
    }
    return false;
  }
}

class _AssetMatch {
  const _AssetMatch({
    required this.asset,
    required this.selectionLabel,
    required this.matchedDeviceAbi,
  });

  final Map<String, dynamic> asset;
  final String selectionLabel;
  final String matchedDeviceAbi;
}

class _ParsedVersion implements Comparable<_ParsedVersion> {
  const _ParsedVersion({required this.parts, required this.build});

  final List<int> parts;
  final int? build;

  factory _ParsedVersion.parse(String raw) {
    String normalized = raw.trim();
    if (normalized.startsWith('v') || normalized.startsWith('V')) {
      normalized = normalized.substring(1);
    }

    final List<String> buildSplit = normalized.split('+');
    final String mainPart = buildSplit.first.split('-').first;
    final List<int> parts = mainPart
        .split('.')
        .map((value) => int.tryParse(value.trim()) ?? 0)
        .toList();
    final int? build = buildSplit.length > 1
        ? int.tryParse(RegExp(r'\d+').firstMatch(buildSplit[1])?.group(0) ?? '')
        : null;

    return _ParsedVersion(parts: parts, build: build);
  }

  @override
  int compareTo(_ParsedVersion other) {
    final int maxLength = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (int index = 0; index < maxLength; index += 1) {
      final int left = index < parts.length ? parts[index] : 0;
      final int right = index < other.parts.length ? other.parts[index] : 0;
      if (left != right) {
        return left.compareTo(right);
      }
    }

    if (build != null && other.build != null) {
      return build!.compareTo(other.build!);
    }
    if (build != null && other.build == null) {
      return build! > 0 ? 1 : 0;
    }
    if (build == null && other.build != null) {
      return other.build! > 0 ? -1 : 0;
    }
    return 0;
  }
}
