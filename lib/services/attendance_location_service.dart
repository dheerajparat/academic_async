import 'package:geolocator/geolocator.dart';

enum AttendanceLocationStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class AttendanceLocationPoint {
  const AttendanceLocationPoint({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}

class AttendanceLocationResult {
  const AttendanceLocationResult({required this.status, this.point});

  final AttendanceLocationStatus status;
  final AttendanceLocationPoint? point;

  bool get isSuccess =>
      status == AttendanceLocationStatus.success && point != null;
}

class AttendanceLocationService {
  static Future<AttendanceLocationResult> resolveCurrentPreciseLocation({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final bool servicesEnabled = await Geolocator.isLocationServiceEnabled();
    if (!servicesEnabled) {
      return const AttendanceLocationResult(
        status: AttendanceLocationStatus.serviceDisabled,
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return const AttendanceLocationResult(
        status: AttendanceLocationStatus.permissionDenied,
      );
    }
    if (permission == LocationPermission.deniedForever) {
      return const AttendanceLocationResult(
        status: AttendanceLocationStatus.permissionDeniedForever,
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: timeout,
        ),
      );
      return AttendanceLocationResult(
        status: AttendanceLocationStatus.success,
        point: AttendanceLocationPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy,
        ),
      );
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) {
        return const AttendanceLocationResult(
          status: AttendanceLocationStatus.unavailable,
        );
      }
      return AttendanceLocationResult(
        status: AttendanceLocationStatus.success,
        point: AttendanceLocationPoint(
          latitude: last.latitude,
          longitude: last.longitude,
          accuracyMeters: last.accuracy,
        ),
      );
    }
  }

  static Future<AttendanceLocationPoint?> getCurrentPreciseLocation({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final result = await resolveCurrentPreciseLocation(timeout: timeout);
    return result.point;
  }

  static Future<bool> openDeviceLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  static Future<bool> openApplicationSettings() {
    return Geolocator.openAppSettings();
  }

  static Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }
}
