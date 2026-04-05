import 'dart:async';

import 'package:academic_async/services/event_sync_service.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarController extends GetxController {
  final Rx<DateTime> focusedDay = DateTime.now().obs;
  final Rx<DateTime> selectedDay = DateTime.now().obs;
  final Rx<CalendarFormat> calendarFormat = CalendarFormat.month.obs;
  final RxBool isLoading = false.obs;
  final RxBool isMonthView = true.obs;

  final RxMap<DateTime, List<String>> events = <DateTime, List<String>>{}.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadCachedThenSync());
  }

  Future<void> _loadCachedThenSync() async {
    isLoading.value = true;

    final cached = await EventSyncService.loadCachedForCurrentUser().timeout(
      const Duration(seconds: 3),
      onTimeout: () => const [],
    );
    _applyEventMap(EventSyncService.toEventMap(cached));

    await fetchfromFirebase();
  }

  Future<void> fetchfromFirebase() async {
    try {
      final synced = await EventSyncService.syncEvents(
        forceFull: false,
        sideEffects: false,
      ).timeout(const Duration(seconds: 5), onTimeout: () => const []);
      _applyEventMap(EventSyncService.toEventMap(synced));
    } finally {
      isLoading.value = false;
    }
  }

  DateTime _normalize(DateTime day) {
    return DateTime(day.year, day.month, day.day);
  }

  List<String> getEventsForDay(DateTime day) {
    return events[_normalize(day)] ?? const [];
  }

  List<MapEntry<DateTime, List<String>>> getMonthEventGroups(DateTime month) {
    final int targetYear = month.year;
    final int targetMonth = month.month;

    final List<MapEntry<DateTime, List<String>>> grouped = [];
    final sortedKeys = events.keys.toList()..sort((a, b) => a.compareTo(b));

    for (final date in sortedKeys) {
      if (date.year == targetYear && date.month == targetMonth) {
        grouped.add(MapEntry(date, events[date] ?? const []));
      }
    }

    return grouped;
  }

  void onDaySelected(DateTime selected, DateTime focused) {
    selectedDay.value = selected;
    focusedDay.value = focused;
    isMonthView.value = false;
  }

  void onPageChanged(DateTime focused) {
    focusedDay.value = focused;
    isMonthView.value = true;
  }

  void onFormatChanged(CalendarFormat format) {
    calendarFormat.value = format;
  }

  void showMonthEvents() {
    isMonthView.value = true;
  }

  void _applyEventMap(Map<DateTime, List<String>> mapped) {
    events
      ..clear()
      ..addAll(mapped)
      ..refresh();
  }
}
