import 'package:academic_async/controllers/auth_controller.dart';
import 'package:academic_async/controllers/get_user_data.dart';
import 'package:academic_async/pages/auth/login_page.dart';
import 'package:academic_async/pages/homepage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AuthGatePage extends GetView<AuthController> {
  const AuthGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final UserDataController userDataController =
        Get.find<UserDataController>();

    return Obx(() {
      if (controller.user.value == null) {
        return const LoginPage();
      }
      if (!userDataController.isProfileLoaded.value) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      return const Homepage();
    });
  }
}
