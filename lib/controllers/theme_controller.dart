import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends GetxController {
  static const String _themeModeKey = 'theme_mode';
  static const String _seedColorKey = 'theme_seed_color';

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final Rx<Color> seedColor = Rx<Color>(Colors.red);
  SharedPreferences? _prefs;
  bool _loaded = false;

  static const List<Color> availableColors = <Color>[
    Color(0xFFB3261E),
    Color(0xFFE65100),
    Color(0xFFFF8F00),
    Color(0xFF827717),
    Color(0xFF2E7D32),
    Color(0xFF00695C),
    Color(0xFF00838F),
    Color(0xFF0277BD),
    Color(0xFF1565C0),
    Color(0xFF283593),
    Color(0xFF3949AB),
    Color(0xFF5E35B1),
    Color(0xFF7B1FA2),
    Color(0xFFAD1457),
    Color(0xFFC2185B),
    Color(0xFFD81B60),
    Color(0xFF6D4C41),
    Color(0xFF4E342E),
    Color(0xFF455A64),
    Color(0xFF546E7A),
    Color(0xFF00897B),
    Color(0xFF00ACC1),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFF7CB342),
    Color(0xFFF4511E),
    Color(0xFFFB8C00),
    Color(0xFFFF7043),
    Color(0xFF8E24AA),
    Color(0xFFEC407A),
  ];

  @override
  void onInit() {
    super.onInit();
    unawaited(loadPersistedPreferences());
  }

  Future<void> loadPersistedPreferences() async {
    if (_loaded) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _loaded = true;

    final savedMode = prefs.getInt(_themeModeKey);
    if (savedMode != null &&
        savedMode >= 0 &&
        savedMode < ThemeMode.values.length) {
      themeMode.value = ThemeMode.values[savedMode];
    }

    final savedSeedColor = prefs.getInt(_seedColorKey);
    if (savedSeedColor != null) {
      seedColor.value = Color(savedSeedColor);
    }
  }

  Future<void> updateTheme(ThemeMode mode) async {
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    await _setInt(_themeModeKey, mode.index);
  }

  Future<void> updateSeedColor(Color color) async {
    seedColor.value = color;
    await _setInt(_seedColorKey, color.toARGB32());
  }

  Future<void> _setInt(String key, int value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    await prefs.setInt(key, value);
  }
}
