import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AttendanceLockService {
  AttendanceLockService._();

  static const MethodChannel _channel = MethodChannel(
    'academic_async/attendance_lock',
  );
  static bool _channelUnavailable = false;

  static Future<bool> setAttendanceLock(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    if (_channelUnavailable) {
      return false;
    }
    try {
      final dynamic raw = await _channel.invokeMethod<dynamic>(
        'setAttendanceLock',
        <String, dynamic>{'enabled': enabled},
      );
      if (raw is bool) {
        return raw;
      }
      return true;
    } on MissingPluginException {
      _channelUnavailable = true;
      debugPrint(
        'Attendance lock channel unavailable. Falling back without strict device lock.',
      );
      return false;
    } on PlatformException catch (error, stackTrace) {
      debugPrint(
        'Attendance lock channel failed: ${error.code} ${error.message}',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } catch (error, stackTrace) {
      debugPrint('Attendance lock failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }
}
