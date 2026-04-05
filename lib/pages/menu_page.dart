import 'package:academic_async/controllers/menu_controller.dart';
import 'package:academic_async/pages/routine/routine_page.dart';
import 'package:academic_async/widgets/today_routine_card.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MenuPage extends GetView<MenuControllerX> {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Obx(
      () => ListView(
        children: [
          if (controller.showRoutineInMenu.value) ...[
            TodayRoutineCard(onTap: () => Get.to(() => const RoutinePage())),
            const SizedBox(height: 8),
          ],
          Card(
            color: colors.surface,
            child: SwitchListTile(
              value: controller.notificationsEnabled.value,
              onChanged: (value) async {
                await controller.toggleNotifications(value);
              },
              secondary: Icon(
                Icons.notifications_rounded,
                color: colors.primary,
              ),
              title: Text(
                'Notifications',
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Enable attendance and class alerts',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ),
          Card(
            color: colors.surface,
            child: SwitchListTile(
              value: controller.remindersEnabled.value,
              onChanged: (value) async {
                await controller.toggleReminders(value);
              },
              secondary: Icon(Icons.alarm_rounded, color: colors.primary),
              title: Text(
                'Reminders',
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Daily study reminder',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ),
          Card(
            color: colors.surface,
            child: ListTile(
              leading: Icon(Icons.info_outline_rounded, color: colors.primary),
              title: Text(
                controller.showRoutineInMenu.value
                    ? 'Routine is available directly on this menu page'
                    : 'Enable routine from Settings if you want it here',
                style: TextStyle(color: colors.onSurface),
              ),
              subtitle: Text(
                controller.showRoutineInMenu.value
                    ? 'Tap the routine card above to open the full timetable.'
                    : 'Settings > Show routine in menu',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
