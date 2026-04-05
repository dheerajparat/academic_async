import 'package:academic_async/models/event_record.dart';
import 'package:academic_async/services/event_cache_service.dart';
import 'package:academic_async/services/home_widget_service.dart';
import 'package:academic_async/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class EventSyncService {
  static Future<List<EventRecord>> loadCachedForCurrentUser() async {
    final cached = await EventCacheService.readCachedEvents();
    return _filterByUserContext(cached);
  }

  static Future<List<EventRecord>> syncEvents({
    bool forceFull = false,
    bool sideEffects = true,
  }) async {
    if (Firebase.apps.isEmpty) {
      return loadCachedForCurrentUser();
    }

    final cached = await EventCacheService.readCachedEvents();
    if (sideEffects) {
      final List<EventRecord> filteredCached = await _filterByUserContext(
        cached,
      );
      await NotificationService.scheduleEventReminders(filteredCached);
    }
    final List<EventRecord> remote;

    try {
      remote = await _fetchRemoteEvents(forceFull: true, lastSyncMillis: 0);
      final remoteList = remote..sort((a, b) => a.date.compareTo(b.date));
      await EventCacheService.saveCachedEvents(remoteList);
      await EventCacheService.saveLastSyncMillis(
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      final filteredCached = await _filterByUserContext(cached);
      await HomeWidgetService.updateUpcomingEventsWidget(filteredCached);
      return filteredCached;
    }

    final filtered = await _filterByUserContext(remote);

    if (sideEffects) {
      await NotificationService.scheduleEventReminders(filtered);
    }
    await HomeWidgetService.updateUpcomingEventsWidget(filtered);

    return filtered;
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

  static Map<DateTime, List<String>> toEventMap(List<EventRecord> records) {
    final Map<DateTime, List<String>> mapped = {};

    for (final record in records) {
      final date = record.normalizedDate;
      mapped[date] = [...(mapped[date] ?? []), record.displayText];
    }

    return mapped;
  }
}
