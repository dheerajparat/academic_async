import 'package:academic_async/firebase_options.dart';
import 'package:academic_async/services/event_sync_service.dart';
import 'package:academic_async/services/notification_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

const String kEventsSyncTaskName = 'events_background_sync';

@pragma('vm:entry-point')
void backgroundTaskDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.initialize();
    await EventSyncService.syncEvents(forceFull: false, sideEffects: true);
    return Future.value(true);
  });
}

class BackgroundService {
  static Future<void> initializeAndRegister() async {
    await Workmanager().initialize(backgroundTaskDispatcher);
    await Workmanager().registerPeriodicTask(
      'events_sync_unique_work',
      kEventsSyncTaskName,
      frequency: const Duration(hours: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
