import 'dart:async';

import 'package:academic_async/models/developer_profile.dart';
import 'package:academic_async/services/developer_cache_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsController extends GetxController {
  final RxList<DeveloperProfile> developers = <DeveloperProfile>[].obs;
  final RxBool isDevelopersLoading = true.obs;
  final RxnString developersError = RxnString();
  final RxString appName = 'Academic Async'.obs;
  final RxString appVersion = 'Unknown'.obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _developersSubscription;

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadAppMetadata());
    unawaited(_loadCachedDevelopers());
    _listenDevelopers();
  }

  @override
  void onClose() {
    _developersSubscription?.cancel();
    super.onClose();
  }

  String get platformLabel {
    if (kIsWeb) {
      return 'Web';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

  void _listenDevelopers() {
    if (Firebase.apps.isEmpty) {
      isDevelopersLoading.value = false;
      developersError.value = developers.isEmpty
          ? 'Firebase is not initialized'
          : 'Showing saved data (offline)';
      return;
    }

    isDevelopersLoading.value = developers.isEmpty;
    developersError.value = null;

    _developersSubscription = FirebaseFirestore.instance
        .collection('developers')
        .snapshots()
        .listen(_onDevelopersSnapshot, onError: _onDevelopersError);
  }

  Future<void> _loadAppMetadata() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final String resolvedName = info.appName.trim();
      final String resolvedVersion = info.version.trim();
      final String resolvedBuild = info.buildNumber.trim();

      if (resolvedName.isNotEmpty) {
        appName.value = resolvedName;
      }
      if (resolvedVersion.isNotEmpty) {
        appVersion.value = resolvedBuild.isEmpty
            ? resolvedVersion
            : '$resolvedVersion+$resolvedBuild';
      }
    } catch (_) {
      // Keep fallback values when platform package metadata isn't available.
    }
  }

  Future<void> _loadCachedDevelopers() async {
    final cached = await DeveloperCacheService.readCachedDevelopers();
    if (cached.isEmpty) {
      return;
    }

    developers.assignAll(cached);
    isDevelopersLoading.value = false;
    developersError.value = 'Showing saved data (offline)';
  }

  void _onDevelopersSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final parsed =
        snapshot.docs
            .map(
              (doc) =>
                  DeveloperProfile.fromMap(doc.data(), fallbackName: doc.id),
            )
            .where((item) => item.hasContent)
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

    developers.assignAll(parsed);
    isDevelopersLoading.value = false;
    developersError.value = null;
    unawaited(DeveloperCacheService.saveCachedDevelopers(parsed));
  }

  void _onDevelopersError(Object error) {
    isDevelopersLoading.value = false;
    developersError.value = developers.isEmpty
        ? 'Unable to load developers (no saved data)'
        : 'Showing saved data (offline)';
    unawaited(_loadCachedDevelopers());
  }
}
