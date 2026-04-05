import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class RoutineWidgetService {
  static const String _androidWidgetName = 'RoutineTodayWidgetProvider';
  static const String _qualifiedAndroidWidgetName =
      'com.parat.academicasync.RoutineTodayWidgetProvider';

  static Future<void> updateRoutineWidget(
    Map<String, Map<String, String>> routine,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    try {
      final Map<String, Map<String, String>> plainRoutine = routine.map(
        (String period, Map<String, String> dayMap) =>
            MapEntry(period, Map<String, String>.from(dayMap)),
      );

      await HomeWidget.saveWidgetData<String>(
        'routine_json',
        jsonEncode(plainRoutine),
      );
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        qualifiedAndroidName: _qualifiedAndroidWidgetName,
      );
    } catch (error, stackTrace) {
      debugPrint('Routine widget update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
