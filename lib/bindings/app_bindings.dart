import 'package:academic_async/controllers/attendance_controller.dart';
import 'package:academic_async/controllers/auth_controller.dart';
import 'package:academic_async/controllers/auth_form_controller.dart';
import 'package:academic_async/controllers/calendar_controller.dart';
import 'package:academic_async/controllers/developer_admin_controller.dart';
import 'package:academic_async/controllers/firebase/syllabus_get.dart';
import 'package:academic_async/controllers/get_user_data.dart';
import 'package:academic_async/controllers/home_controller.dart';
import 'package:academic_async/controllers/menu_controller.dart';
import 'package:academic_async/controllers/routine_controller.dart';
import 'package:academic_async/controllers/settings_controller.dart';
import 'package:academic_async/controllers/syllabus_controller.dart';
import 'package:academic_async/controllers/update_controller.dart';
import 'package:get/get.dart';

class AppBindings extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController(), fenix: true);
    Get.lazyPut<AttendanceController>(
      () => AttendanceController(),
      fenix: true,
    );
    Get.lazyPut<CalendarController>(() => CalendarController(), fenix: true);
    Get.lazyPut<SyllabusController>(() => SyllabusController(), fenix: true);
    Get.lazyPut<MenuControllerX>(() => MenuControllerX(), fenix: true);
    Get.lazyPut<RoutineController>(() => RoutineController(), fenix: true);
    Get.lazyPut<SettingsController>(() => SettingsController(), fenix: true);
    Get.lazyPut<AuthController>(() => AuthController(), fenix: true);
    Get.lazyPut<AuthFormController>(() => AuthFormController(), fenix: true);
    Get.lazyPut<UserDataController>(() => UserDataController(), fenix: true);
    Get.lazyPut<SyllabusGet>(() => SyllabusGet(), fenix: true);
    Get.lazyPut<UpdateController>(() => UpdateController(), fenix: true);
    Get.lazyPut<DeveloperAdminController>(
      () => DeveloperAdminController(),
      fenix: true,
    );
  }
}
