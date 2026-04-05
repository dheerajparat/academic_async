class AppUpdateConfig {
  const AppUpdateConfig._();

  // Change these defaults if your public GitHub repository or APK asset name
  // differs. You can also override them at build time with:
  // --dart-define=AA_UPDATE_OWNER=...
  // --dart-define=AA_UPDATE_REPO=...
  // --dart-define=AA_UPDATE_ASSET_NAME=...
  static const String githubOwner = String.fromEnvironment(
    'AA_UPDATE_OWNER',
    defaultValue: 'dheerajparat',
  );
  static const String githubRepo = String.fromEnvironment(
    'AA_UPDATE_REPO',
    defaultValue: 'academic_async',
  );
  static const String apkAssetName = String.fromEnvironment(
    'AA_UPDATE_ASSET_NAME',
    defaultValue: 'academic_async.apk',
  );
  static const List<String> universalAssetKeywords = <String>[
    'universal',
    'all',
    'fat',
  ];

  static bool get isConfigured =>
      githubOwner.trim().isNotEmpty && githubRepo.trim().isNotEmpty;

  static String get latestReleaseApiUrl =>
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  static String get repositoryUrl =>
      'https://github.com/$githubOwner/$githubRepo';

  static String get releasesPageUrl => '$repositoryUrl/releases';
}
