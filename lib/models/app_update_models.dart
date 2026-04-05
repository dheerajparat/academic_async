class AppVersionInfo {
  const AppVersionInfo({
    required this.appName,
    required this.packageName,
    required this.version,
    required this.buildNumber,
  });

  final String appName;
  final String packageName;
  final String version;
  final String buildNumber;

  String get displayVersion =>
      buildNumber.trim().isEmpty ? version : '$version+$buildNumber';
}

class DeviceAbiInfo {
  const DeviceAbiInfo({required this.supportedAbis});

  final List<String> supportedAbis;

  String get primaryAbi => supportedAbis.isEmpty ? '' : supportedAbis.first;

  String get displayLabel =>
      primaryAbi.isEmpty ? 'Universal fallback' : primaryAbi;
}

class AppReleaseInfo {
  const AppReleaseInfo({
    required this.versionTag,
    required this.downloadUrl,
    required this.assetName,
    required this.releaseNotes,
    required this.htmlUrl,
    required this.publishedAt,
    required this.isNewerThanCurrent,
    required this.selectionLabel,
    required this.matchedDeviceAbi,
  });

  final String versionTag;
  final String downloadUrl;
  final String assetName;
  final String releaseNotes;
  final String htmlUrl;
  final DateTime? publishedAt;
  final bool isNewerThanCurrent;
  final String selectionLabel;
  final String matchedDeviceAbi;

  bool get hasDownloadAsset => downloadUrl.trim().isNotEmpty;
}
