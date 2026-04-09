import 'package:academic_async/controllers/attendance_controller.dart';
import 'package:academic_async/controllers/auth_controller.dart';
import 'package:academic_async/controllers/get_user_data.dart';
import 'package:academic_async/controllers/home_controller.dart';
import 'package:academic_async/controllers/settings_controller.dart';
import 'package:academic_async/controllers/update_controller.dart';
import 'package:academic_async/models/bottom_nav_item.dart';
import 'package:academic_async/pages/developer_admin_page.dart';
import 'package:academic_async/pages/settings_page.dart';
import 'package:academic_async/services/event_sync_service.dart';
import 'package:academic_async/widgets/custom_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Homepage extends GetView<HomeController> {
  const Homepage({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AuthController authController = Get.find<AuthController>();
    final AttendanceController attendanceController =
        Get.find<AttendanceController>();
    Get.find<UpdateController>();
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final Color accentColor = theme.colorScheme.primary;
    final UserDataController userDataController =
        Get.find<UserDataController>();
    final SettingsController settingsController =
        Get.find<SettingsController>();
    final Color scaffoldGradientEnd = isDarkMode ? Colors.black : Colors.white;
    final Color cardColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color bottomBarColor = isDarkMode
        ? Colors.grey.shade900
        : Colors.white;

    return Obx(() {
      final int selectedIndex = controller.currentIndex.value;
      final List<BottomNavItem> navItems = controller.navItems;
      final bool isDeveloper = userDataController.isDeveloper;
      final bool attendanceLockActive =
          attendanceController.isAttendanceLockActive;
      final int lockSecondsLeft =
          attendanceController.attendanceLockSecondsLeft;
      final String lockDurationLabel =
          attendanceController.attendanceLockDurationLabel;

      return PopScope(
        canPop: !attendanceLockActive,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop && attendanceLockActive) {
            attendanceController.showAttendanceLockMessage(
              actionLabel: 'exiting the app',
            );
          }
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          drawer: _DrawerForAll(
            cardColor: cardColor,
            accentColor: accentColor,
            isDarkMode: isDarkMode,
            textColor: textColor,
            title: userDataController.name.value.isNotEmpty
                ? 'Hello, ${userDataController.name.value}!'
                : 'Hello, Student!',
            email: userDataController.email.value,
            regNum: userDataController.registrationNo.value,
            branch: userDataController.branch.value,
            semester: userDataController.semester.value,
            role: userDataController.role.value,
            currentIndex: selectedIndex,
            isDeveloper: isDeveloper,
            appName: settingsController.appName.value,
            appVersion: settingsController.appVersion.value,
          ),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              navItems[selectedIndex].label,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            iconTheme: IconThemeData(color: textColor),
            actions: [
              if (isDeveloper)
                IconButton(
                  tooltip: 'Developer mode',
                  icon: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: accentColor,
                  ),
                  onPressed: () {
                    Get.to(() => const DeveloperAdminPage());
                  },
                ),
              IconButton(
                icon: Icon(Icons.logout, color: accentColor),
                onPressed: () {
                  if (!attendanceController.canPerformProtectedAction(
                    actionLabel: 'logging out',
                  )) {
                    return;
                  }
                  Get.defaultDialog(
                    title: 'Logout',
                    middleText: 'Are you sure you want to logout?',
                    textCancel: 'Cancel',
                    textConfirm: 'Logout',
                    confirmTextColor: Theme.of(context).colorScheme.onPrimary,
                    onConfirm: () {
                      if (!attendanceController.canPerformProtectedAction(
                        actionLabel: 'logging out',
                      )) {
                        Get.back();
                        return;
                      }
                      authController.signOut();
                      Get.back();
                    },
                  );
                },
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accentColor.withValues(alpha: isDarkMode ? 0.1 : 0.9),
                  scaffoldGradientEnd,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    if (attendanceLockActive)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          lockSecondsLeft > 0
                              ? 'Attendance live hai. $lockDurationLabel tak logout, app exit, aur app switching lock rahega.'
                              : 'Attendance live hai. Logout, app exit, aur app switching temporary lock hai.',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Expanded(child: controller.pages[selectedIndex]),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: CustomBottomNav(
            bottomBarColor: bottomBarColor,
            isDarkMode: isDarkMode,
            navItems: navItems,
            accentColor: accentColor,
          ),
        ),
      );
    });
  }
}

class _DrawerForAll extends StatelessWidget {
  const _DrawerForAll({
    required this.cardColor,
    required this.accentColor,
    required this.isDarkMode,
    required this.textColor,
    required this.title,
    required this.email,
    required this.regNum,
    required this.branch,
    required this.semester,
    required this.role,
    required this.currentIndex,
    required this.isDeveloper,
    required this.appName,
    required this.appVersion,
  });

  final Color cardColor;
  final Color accentColor;
  final bool isDarkMode;
  final Color textColor;
  final String title;
  final String email;
  final String regNum;
  final String branch;
  final String semester;
  final String role;
  final int currentIndex;
  final bool isDeveloper;
  final String appName;
  final String appVersion;

  @override
  Widget build(BuildContext context) {
    final HomeController homeController = Get.find<HomeController>();
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: cardColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: isDarkMode ? 0.6 : 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  email,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withAlpha(200),
                    fontSize: 14,
                  ),
                ),
                if (regNum.isNotEmpty)
                  Text(
                    'Reg No: $regNum',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withAlpha(200),
                      fontSize: 14,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDarkMode ? 0.16 : 0.09),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Academic Snapshot',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DrawerChip(
                        icon: Icons.account_tree_rounded,
                        label: branch.isEmpty ? 'Branch pending' : branch,
                        textColor: textColor,
                      ),
                      _DrawerChip(
                        icon: Icons.layers_rounded,
                        label: semester.isEmpty ? 'Semester pending' : semester,
                        textColor: textColor,
                      ),
                      _DrawerChip(
                        icon: Icons.person_pin_circle_rounded,
                        label: role.isEmpty ? 'Role pending' : role,
                        textColor: textColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Quick Navigation',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          _DrawerActionTile(
            icon: Icons.calendar_today_rounded,
            label: 'Calendar',
            selected: currentIndex == 0,
            accentColor: accentColor,
            textColor: textColor,
            onTap: () {
              Navigator.of(context).pop();
              homeController.changeTab(0);
            },
          ),
          _DrawerActionTile(
            icon: Icons.check_circle_rounded,
            label: 'Attendance',
            selected: currentIndex == 1,
            accentColor: accentColor,
            textColor: textColor,
            onTap: () {
              Navigator.of(context).pop();
              homeController.changeTab(1);
            },
          ),
          _DrawerActionTile(
            icon: Icons.menu_book_rounded,
            label: 'Syllabus',
            selected: currentIndex == 2,
            accentColor: accentColor,
            textColor: textColor,
            onTap: () {
              Navigator.of(context).pop();
              homeController.changeTab(2);
            },
          ),
          _DrawerActionTile(
            icon: Icons.menu_rounded,
            label: 'Menu',
            selected: currentIndex == 3,
            accentColor: accentColor,
            textColor: textColor,
            onTap: () {
              Navigator.of(context).pop();
              homeController.changeTab(3);
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(
              'Useful Tools',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.sync_rounded, color: accentColor),
            title: Text('Refresh events', style: TextStyle(color: textColor)),
            subtitle: Text(
              'Sync your latest academic event list',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            onTap: () async {
              Navigator.of(context).pop();
              await EventSyncService.syncEvents(
                forceFull: true,
                sideEffects: true,
              );
              Get.snackbar(
                'Refreshed',
                'Academic events have been synced again.',
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: accentColor),
            title: Text('Settings', style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.of(context).pop();
              Get.to(() => const SettingsPage());
            },
          ),
          ListTile(
            leading: Icon(Icons.info_outline_rounded, color: accentColor),
            title: Text('About', style: TextStyle(color: textColor)),
            onTap: () {
              Navigator.of(context).pop();
              showAboutDialog(
                context: context,
                applicationName: appName,
                applicationVersion: appVersion,
                applicationLegalese:
                    'Built to simplify routine, syllabus, attendance, and academic planning.',
              );
            },
          ),
          if (isDeveloper)
            ListTile(
              leading: Icon(
                Icons.admin_panel_settings_rounded,
                color: accentColor,
              ),
              title: Text(
                'Developer Admin',
                style: TextStyle(color: textColor),
              ),
              onTap: () {
                Navigator.of(context).pop();
                Get.to(() => const DeveloperAdminPage());
              },
            ),
        ],
      ),
    );
  }
}

class _DrawerChip extends StatelessWidget {
  const _DrawerChip({
    required this.icon,
    required this.label,
    required this.textColor,
  });

  final IconData icon;
  final String label;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerActionTile extends StatelessWidget {
  const _DrawerActionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accentColor,
    required this.textColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color accentColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? accentColor : textColor),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: accentColor, size: 18)
          : null,
      title: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}
