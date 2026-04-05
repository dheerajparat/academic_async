import 'dart:async';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MenuControllerX extends GetxController {
  static const String _notificationsEnabledKey = 'menu_notifications_enabled';
  static const String _remindersEnabledKey = 'menu_reminders_enabled';
  static const String _showRoutineInMenuKey = 'menu_show_routine_in_menu';

  final RxBool notificationsEnabled = true.obs;
  final RxBool remindersEnabled = false.obs;
  final RxBool showRoutineInMenu = true.obs;
  SharedPreferences? _prefs;

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadPersistedPreferences());
  }

  Future<void> toggleNotifications(bool value) async {
    notificationsEnabled.value = value;
    await _setBool(_notificationsEnabledKey, value);
  }

  Future<void> toggleReminders(bool value) async {
    remindersEnabled.value = value;
    await _setBool(_remindersEnabledKey, value);
  }

  Future<void> toggleShowRoutineInMenu(bool value) async {
    showRoutineInMenu.value = value;
    await _setBool(_showRoutineInMenuKey, value);
  }

  Future<void> _loadPersistedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;

    notificationsEnabled.value =
        prefs.getBool(_notificationsEnabledKey) ?? notificationsEnabled.value;
    remindersEnabled.value =
        prefs.getBool(_remindersEnabledKey) ?? remindersEnabled.value;
    showRoutineInMenu.value =
        prefs.getBool(_showRoutineInMenuKey) ?? showRoutineInMenu.value;
  }

  Future<void> _setBool(String key, bool value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    await prefs.setBool(key, value);
  }
}
