import 'dart:convert';

import 'package:academic_async/models/event_record.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  static const String _androidWidgetName = 'UpcomingEventsWidgetProvider';
  static const String _qualifiedAndroidWidgetName =
      'com.parat.academicasync.UpcomingEventsWidgetProvider';
  static const int _maxWidgetItems = 20;

  static Future<void> updateUpcomingEventsWidget(
    List<EventRecord> events,
  ) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final upcoming =
          events.where((e) => !e.normalizedDate.isBefore(today)).toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      final lines = upcoming.take(5).map((e) {
        final d = e.normalizedDate;
        return '${_weekdayLabel(d.weekday)}, ${d.day}/${d.month} - ${e.displayText}';
      }).toList();
      final widgetItems = upcoming.take(_maxWidgetItems).map((e) {
        final d = e.normalizedDate;
        return '${_weekdayLabel(d.weekday)}, ${d.day}/${d.month} - ${e.displayText}';
      }).toList();

      final subtitle = widgetItems.isEmpty
          ? 'No events scheduled'
          : '${widgetItems.length} upcoming event${widgetItems.length == 1 ? '' : 's'}';
      final emptyState = widgetItems.isEmpty ? 'No upcoming events' : '';

      await HomeWidget.saveWidgetData<String>(
        'upcoming_title',
        'Upcoming Events',
      );
      await HomeWidget.saveWidgetData<String>('upcoming_subtitle', subtitle);
      await HomeWidget.saveWidgetData<String>(
        'upcoming_empty_message',
        emptyState,
      );
      await HomeWidget.saveWidgetData<String>(
        'upcoming_items_json',
        jsonEncode(widgetItems),
      );
      await HomeWidget.saveWidgetData<String>(
        'upcoming_content',
        lines.isEmpty ? 'No upcoming events' : lines.join('\n'),
      );

      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        qualifiedAndroidName: _qualifiedAndroidWidgetName,
      );
    } catch (error, stackTrace) {
      debugPrint('Home widget update failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Mon';
      case DateTime.tuesday:
        return 'Tue';
      case DateTime.wednesday:
        return 'Wed';
      case DateTime.thursday:
        return 'Thu';
      case DateTime.friday:
        return 'Fri';
      case DateTime.saturday:
        return 'Sat';
      case DateTime.sunday:
      default:
        return 'Sun';
    }
  }
}
