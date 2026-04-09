import 'package:academic_async/controllers/attendance_controller.dart';
import 'package:get/get.dart';

class AttendanceGuard {
  AttendanceGuard._();

  static bool canProceed({
    required String actionLabel,
    bool showMessage = true,
  }) {
    if (!Get.isRegistered<AttendanceController>()) {
      return true;
    }
    final AttendanceController controller = Get.find<AttendanceController>();
    return controller.canPerformProtectedAction(
      actionLabel: actionLabel,
      showMessage: showMessage,
    );
  }
}
