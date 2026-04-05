import 'package:academic_async/models/event_record.dart';
import 'package:academic_async/services/event_cache_service.dart';
import 'package:academic_async/services/home_widget_service.dart';
import 'package:academic_async/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class EventSyncService {
  static const Duration _minIncrementalSyncGap = Duration(minutes: 10);
  static const Duration _fullRefreshInterval = Duration(hours: 12);
  static Future<List<EventRecord>>? _inFlightSync;
  static bool _inFlightSyncIncludesSideEffects = false;

  static Future<List<EventRecord>> loadCachedForCurrentUser() async {
    final cached = await EventCacheService.readCachedEvents();
    return _filterByUserContext(cached);
  }

  static Future<List<EventRecord>> syncEvents({
    bool forceFull = false,
    bool sideEffects = true,
  }) async {
    final Future<List<EventRecord>>? inFlight = _inFlightSync;
    if (inFlight != null) {
      final List<EventRecord> result = await inFlight;
      if (sideEffects && !_inFlightSyncIncludesSideEffects) {
        await _applySideEffects(result);
      }
      return result;
    }

    _inFlightSyncIncludesSideEffects = sideEffects;
    final Future<List<EventRecord>> syncFuture = _runSyncEvents(
      forceFull: forceFull,
      sideEffects: sideEffects,
    );
    _inFlightSync = syncFuture;

    try {
      return await syncFuture;
    } finally {
      if (identical(_inFlightSync, syncFuture)) {
        _inFlightSync = null;
        _inFlightSyncIncludesSideEffects = false;
      }
    }
  }

  static Future<List<EventRecord>> _runSyncEvents({
    required bool forceFull,
    required bool sideEffects,
  }) async {
    if (Firebase.apps.isEmpty) {
      return loadCachedForCurrentUser();
    }

    final List<EventRecord> cached = await EventCacheService.readCachedEvents();
    final List<EventRecord> filteredCached = await _filterByUserContext(cached);
    final int lastSyncMillis = await EventCacheService.readLastSyncMillis();
    final int nowMillis = DateTime.now().millisecondsSinceEpoch;

    if (!forceFull &&
        cached.isNotEmpty &&
        _isRecentSync(lastSyncMillis, nowMillis)) {
      if (sideEffects) {
        await _applySideEffects(filteredCached);
      }
      return filteredCached;
    }

    final bool shouldFullRefresh =
        forceFull ||
        cached.isEmpty ||
        lastSyncMillis == 0 ||
        _isFullRefreshDue(lastSyncMillis, nowMillis);

    debugPrint(
      'Event sync started. fullRefresh=$shouldFullRefresh cached=${cached.length}',
    );

    final List<EventRecord> remote;
    try {
      remote = await _fetchRemoteEvents(
        forceFull: shouldFullRefresh,
        lastSyncMillis: lastSyncMillis,
      );

      final List<EventRecord> nextCache = shouldFullRefresh
          ? _sortRecords(remote)
          : _mergeRecords(cached, remote);

      await EventCacheService.saveCachedEvents(nextCache);
      await EventCacheService.saveLastSyncMillis(nowMillis);

      final List<EventRecord> filtered = await _filterByUserContext(nextCache);
      if (sideEffects) {
        await _applySideEffects(filtered);
      }
      return filtered;
    } catch (_) {
      if (sideEffects) {
        await _applySideEffects(filteredCached);
      } else {
        await HomeWidgetService.updateUpcomingEventsWidget(filteredCached);
      }
      return filteredCached;
    }
  }

  static Future<List<EventRecord>> _fetchRemoteEvents({
    required bool forceFull,
    required int lastSyncMillis,
  }) async {
    final collection = FirebaseFirestore.instance.collection('events');

    if (forceFull) {
      final snapshot = await collection.get();
      return _recordsFromSnapshots([snapshot]);
    }

    final Timestamp since = Timestamp.fromMillisecondsSinceEpoch(
      lastSyncMillis,
    );

    try {
      final updatedSnapshot = await collection
          .where('updated_at', isGreaterThan: since)
          .get();
      final createdSnapshot = await collection
          .where('created_at', isGreaterThan: since)
          .get();
      return _recordsFromSnapshots([updatedSnapshot, createdSnapshot]);
    } catch (_) {
      final snapshot = await collection.get();
      return _recordsFromSnapshots([snapshot]);
    }
  }

  static List<EventRecord> _recordsFromSnapshots(
    List<QuerySnapshot<Map<String, dynamic>>> snapshots,
  ) {
    final Map<String, EventRecord> mapped = {};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        final record = EventRecord.fromFirestore(doc.id, doc.data());
        if (record != null) {
          mapped[doc.id] = record;
        }
      }
    }

    return mapped.values.toList();
  }

  static Future<List<EventRecord>> _filterByUserContext(
    List<EventRecord> records,
  ) async {
    final context = await EventCacheService.readUserContext();
    final branchId = context['branch_id'] ?? '';
    final semesterId = context['semester_id'] ?? '';

    final filtered = records.where((event) {
      final matchesBranch =
          branchId.isEmpty ||
          event.branchId.isEmpty ||
          event.branchId == branchId;
      final matchesSemester =
          semesterId.isEmpty ||
          event.semesterId.isEmpty ||
          event.semesterId == semesterId;
      return matchesBranch && matchesSemester;
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    return filtered;
  }

  static Future<void> _applySideEffects(List<EventRecord> events) async {
    await NotificationService.scheduleEventReminders(events);
    await HomeWidgetService.updateUpcomingEventsWidget(events);
  }

  static bool _isRecentSync(int lastSyncMillis, int nowMillis) {
    return nowMillis - lastSyncMillis < _minIncrementalSyncGap.inMilliseconds;
  }

  static bool _isFullRefreshDue(int lastSyncMillis, int nowMillis) {
    return nowMillis - lastSyncMillis > _fullRefreshInterval.inMilliseconds;
  }

  static List<EventRecord> _mergeRecords(
    List<EventRecord> cached,
    List<EventRecord> incoming,
  ) {
    final Map<String, EventRecord> merged = <String, EventRecord>{
      for (final EventRecord record in cached) record.id: record,
    };

    for (final EventRecord record in incoming) {
      merged[record.id] = record;
    }

    return _sortRecords(merged.values.toList());
  }

  static List<EventRecord> _sortRecords(List<EventRecord> records) {
    records.sort((a, b) => a.date.compareTo(b.date));
    return records;
  }

  static Map<DateTime, List<String>> toEventMap(List<EventRecord> records) {
    final Map<DateTime, List<String>> mapped = {};

    for (final record in records) {
      final date = record.normalizedDate;
      mapped[date] = [...(mapped[date] ?? []), record.displayText];
    }

    return mapped;
  }
}
