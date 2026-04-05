import 'package:academic_async/models/event_record.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const String _scheduledEventIdsKey =
      'scheduled_event_notification_ids';
  static const String _deliveredLateReminderKeysKey =
      'delivered_late_event_reminder_keys';

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: settings, // ← required named arg
      onDidReceiveNotificationResponse: (NotificationResponse response) {},
    );

    await _configureLocalTimeZone();
    _initialized = true;
  }

  static Future<void> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
  }

  static Future<void> clearAll() async {
    try {
      await initialize();
      await _plugin.cancelAll();
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_scheduledEventIdsKey);
      await prefs.remove(_deliveredLateReminderKeysKey);
    } catch (error, stackTrace) {
      debugPrint('Notification clearAll failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> scheduleEventReminders(List<EventRecord> events) async {
    await initialize();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final Set<int> previouslyScheduledIds =
        (prefs.getStringList(_scheduledEventIdsKey) ?? const <String>[])
            .map((String raw) => int.tryParse(raw))
            .whereType<int>()
            .toSet();
    for (final int notificationId in previouslyScheduledIds) {
      await _plugin.cancel(id: notificationId);
    }

    final now = DateTime.now();
    final DateTime todayStart = DateTime(now.year, now.month, now.day);
    final Set<String> deliveredLateReminderKeys =
        (prefs.getStringList(_deliveredLateReminderKeysKey) ?? const <String>[])
            .toSet();
    final Set<String> retainedLateReminderKeys = <String>{};
    final Set<int> scheduledIds = <int>{};
    final NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        'event_reminders_channel',
        'Event Reminders',
        channelDescription: 'Reminder one day before event',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    for (final event in events) {
      final eventDate = DateTime(
        event.date.year,
        event.date.month,
        event.date.day,
      );
      if (!eventDate.isAfter(todayStart)) {
        continue;
      }

      final notificationTime = DateTime(
        eventDate.year,
        eventDate.month,
        eventDate.day,
        9,
      ).subtract(const Duration(days: 1));
      final String reminderKey = _lateReminderKey(event);

      if (deliveredLateReminderKeys.contains(reminderKey)) {
        retainedLateReminderKeys.add(reminderKey);
      }

      final int id = _stableNotificationId(event.id);
      if (notificationTime.isAfter(now)) {
        scheduledIds.add(id);
        await _plugin.zonedSchedule(
          id: id,
          title: 'Upcoming Event',
          body:
              '${event.displayText} कल है (${eventDate.day}/${eventDate.month})',
          scheduledDate: tz.TZDateTime.from(notificationTime, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
        continue;
      }

      final bool isLateReminderWindow =
          !now.isBefore(notificationTime) && now.isBefore(eventDate);
      if (!isLateReminderWindow ||
          deliveredLateReminderKeys.contains(reminderKey)) {
        continue;
      }

      await _plugin.show(
        id: id,
        title: 'Upcoming Event',
        body:
            '${event.displayText} कल है (${eventDate.day}/${eventDate.month})',
        notificationDetails: details,
      );
      retainedLateReminderKeys.add(reminderKey);
    }

    await prefs.setStringList(
      _scheduledEventIdsKey,
      scheduledIds.map((int id) => id.toString()).toList(),
    );
    await prefs.setStringList(
      _deliveredLateReminderKeysKey,
      retainedLateReminderKeys.toList(),
    );
  }

  static Future<void> _configureLocalTimeZone() async {
    tz.initializeTimeZones();
    try {
      final dynamic timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String identifier = _extractTimezoneIdentifier(timezoneInfo);
      try {
        tz.setLocalLocation(tz.getLocation(identifier));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  static String _extractTimezoneIdentifier(dynamic value) {
    if (value is String) {
      final normalized = value.trim();
      return normalized.isEmpty ? 'UTC' : normalized;
    }

    try {
      final dynamic identifier = value?.identifier;
      if (identifier is String && identifier.trim().isNotEmpty) {
        return identifier.trim();
      }
    } catch (_) {}

    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? 'UTC' : normalized;
  }

  static int _stableNotificationId(String seed) {
    int hash = 0;
    for (final code in seed.codeUnits) {
      hash = 31 * hash + code;
    }
    return hash.abs() % 2147483647;
  }

  static String _lateReminderKey(EventRecord event) {
    final DateTime eventDate = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
    );
    return '${event.id}|${eventDate.toIso8601String()}';
  }
}
