import 'package:academic_async/controllers/routine_controller.dart';
import 'package:academic_async/pages/routine/add_routine_page.dart';
import 'package:academic_async/pages/routine/import_routine_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

class RoutinePage extends GetView<RoutineController> {
  const RoutinePage({super.key});

  static const double _cellWidth = 136;
  static const double _cellHeight = 66;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Obx(
              () => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    controller.showTodayOnly.value ? 'Single day' : 'Full week',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Switch.adaptive(
                    value: controller.showTodayOnly.value,
                    onChanged: (bool value) {
                      controller.showTodayOnly.value = value;
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        final List<String> periods = controller.periods;
        final List<String> visibleDayKeys = controller.showTodayOnly.value
            ? <String>[controller.today]
            : controller.dayKeys;
        final int todayClasses = periods.where((String period) {
          final String? subject = controller.routine[period]?[controller.today];
          return subject != null &&
              subject.trim().isNotEmpty &&
              subject.trim() != '-';
        }).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          children: [
            _RoutineHero(
              colors: colors,
              periodsCount: periods.length,
              todayClasses: todayClasses,
              todayLabel: controller.dayLabel(controller.today),
              todayOnly: controller.showTodayOnly.value,
            ),
            const SizedBox(height: 14),
            // _RoutineDaysStrip(
            //   colors: colors,
            //   dayKeys: controller.dayKeys,
            //   highlightedDayKey: controller.today,
            //   todayOnly: controller.showTodayOnly.value,
            //   dayLabelOf: controller.dayLabel,
            // ),
            const SizedBox(height: 14),
            if (periods.isEmpty)
              const _EmptyRoutineCard()
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        controller.showTodayOnly.value
                            ? 'Focused view for ${controller.dayLabel(controller.today)}'
                            : 'Weekly timetable',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (!controller.showTodayOnly.value)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Color.alphaBlend(
                            colors.primary.withValues(alpha: 0.10),
                            colors.surfaceContainerHighest,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: colors.outlineVariant.withValues(
                              alpha: 0.45,
                            ),
                          ),
                        ),
                        child: Text(
                          'Scroll sideways for all days',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.08),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _HeaderCell(
                              text: 'Period / Day',
                              shortLabel: 'GRID',
                              isLeading: true,
                              isTrailing: visibleDayKeys.isEmpty,
                              width: _cellWidth,
                              height: _cellHeight,
                              backgroundColor: colors.surfaceContainerHighest,
                              foregroundColor: colors.onSurface,
                              borderColor: colors.outlineVariant,
                            ),
                            ...visibleDayKeys.asMap().entries.map(
                              (MapEntry<int, String> entry) => _HeaderCell(
                                isLeading: false,
                                isTrailing:
                                    entry.key == visibleDayKeys.length - 1,
                                text: controller.dayLabel(entry.value),
                                shortLabel: _shortDayLabel(
                                  controller.dayLabel(entry.value),
                                ),
                                width: _cellWidth,
                                height: _cellHeight,
                                backgroundColor: entry.value == controller.today
                                    ? colors.primaryContainer
                                    : colors.secondaryContainer.withValues(
                                        alpha: 0.82,
                                      ),
                                foregroundColor: entry.value == controller.today
                                    ? colors.onPrimaryContainer
                                    : colors.onSecondaryContainer,
                                borderColor: colors.outlineVariant,
                              ),
                            ),
                          ],
                        ),
                        ...periods.asMap().entries.map(
                          (MapEntry<int, String> entry) => Row(
                            children: [
                              _SideCell(
                                text: entry.value.toUpperCase(),
                                width: _cellWidth,
                                height: _cellHeight,
                                colors: colors,
                                striped: entry.key.isEven,
                              ),
                              ...visibleDayKeys.map(
                                (String day) => _DataCell(
                                  text:
                                      controller.routine[entry.value]?[day] ??
                                      '-',
                                  width: _cellWidth,
                                  height: _cellHeight,
                                  colors: colors,
                                  highlight: day == controller.today,
                                  striped: entry.key.isEven,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      }),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        onPressed: () => _openRoutineActions(context),
        icon: const Icon(Icons.edit_calendar_rounded),
        label: const Text('Manage Routine'),
      ),
    );
  }

  Future<void> _openRoutineActions(BuildContext context) async {
    final ColorScheme colors = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: colors.surface,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RoutineActionTile(
                  colors: colors,
                  icon: Icons.edit_calendar_rounded,
                  title: 'Add routine entry',
                  subtitle: 'Manually add or update one period/day slot',
                  onTap: () {
                    Get.back();
                    Get.to(() => const AddRoutinePage());
                  },
                ),
                const SizedBox(height: 10),
                _RoutineActionTile(
                  colors: colors,
                  icon: Icons.file_download_outlined,
                  title: 'Import routine JSON',
                  subtitle: 'Import from file, QR code, URL, or clipboard',
                  onTap: () {
                    Get.back();
                    Get.to(() => const ImportRoutinePage());
                  },
                ),
                const SizedBox(height: 10),
                _RoutineActionTile(
                  colors: colors,
                  icon: Icons.copy_all_rounded,
                  title: 'Copy current routine JSON',
                  subtitle: 'Keep a backup or share the current timetable',
                  onTap: () async {
                    await _copyRoutineJson();
                    if (context.mounted) {
                      Get.back();
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyRoutineJson() async {
    final String jsonText = controller.exportRoutineJson(pretty: true);
    await Clipboard.setData(ClipboardData(text: jsonText));
    Get.snackbar(
      'Copied',
      'The current routine JSON has been copied to the clipboard.',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}

class _RoutineHero extends StatelessWidget {
  const _RoutineHero({
    required this.colors,
    required this.periodsCount,
    required this.todayClasses,
    required this.todayLabel,
    required this.todayOnly,
  });

  final ColorScheme colors;
  final int periodsCount;
  final int todayClasses;
  final String todayLabel;
  final bool todayOnly;

  @override
  Widget build(BuildContext context) {
    final Color foreground = _foregroundForBackground(
      Color.lerp(colors.primary, colors.tertiary, 0.35) ?? colors.primary,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            colors.primary,
            colors.tertiary.withValues(alpha: 0.92),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.24),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.grid_view_rounded, color: foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class Routine',
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      todayOnly
                          ? 'Showing a focused schedule for $todayLabel.'
                          : 'Your full weekly timetable with a highlighted view for today.',
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.88),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(
                icon: Icons.today_rounded,
                label: '$todayLabel • $todayClasses classes',
                foregroundColor: foreground,
              ),
              _HeroPill(
                icon: Icons.view_week_rounded,
                label: '$periodsCount periods planned',
                foregroundColor: foreground,
              ),
              _HeroPill(
                icon: todayOnly
                    ? Icons.filter_alt_rounded
                    : Icons.dashboard_customize_rounded,
                label: todayOnly ? 'Today only mode' : 'Weekly mode',
                foregroundColor: foreground,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({
    required this.icon,
    required this.label,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: foregroundColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foregroundColor, size: 16),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRoutineCard extends StatelessWidget {
  const _EmptyRoutineCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 54,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'No routine available yet',
              style: TextStyle(
                color: colors.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use the Manage Routine button below to add your first entry or import a timetable JSON.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.text,
    required this.shortLabel,
    required this.isLeading,
    required this.isTrailing,
    required this.width,
    required this.height,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final String text;
  final String shortLabel;
  final bool isLeading;
  final bool isTrailing;
  final double width;
  final double height;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: isLeading ? const Radius.circular(18) : Radius.zero,
          topRight: isTrailing ? const Radius.circular(18) : Radius.zero,
        ),
        border: Border.all(color: borderColor.withValues(alpha: 0.55)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            shortLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foregroundColor.withValues(alpha: 0.80),
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideCell extends StatelessWidget {
  const _SideCell({
    required this.text,
    required this.width,
    required this.height,
    required this.colors,
    required this.striped,
  });

  final String text;
  final double width;
  final double height;
  final ColorScheme colors;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: striped
            ? colors.secondaryContainer.withValues(alpha: 0.5)
            : colors.surfaceContainerHighest.withValues(alpha: 0.6),
        border: Border(
          right: BorderSide(color: colors.outlineVariant),
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell({
    required this.text,
    required this.width,
    required this.height,
    required this.colors,
    required this.highlight,
    required this.striped,
  });

  final String text;
  final double width;
  final double height;
  final ColorScheme colors;
  final bool highlight;
  final bool striped;

  @override
  Widget build(BuildContext context) {
    final bool isEmpty = text == '-' || text.isEmpty;

    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlight
            ? colors.primary.withValues(alpha: 0.12)
            : striped
            ? colors.surfaceContainerLow
            : colors.surface,
        border: Border(
          right: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isEmpty ? colors.outline : colors.onSurface,
          fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _RoutineActionTile extends StatelessWidget {
  const _RoutineActionTile({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final ColorScheme colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: colors.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _foregroundForBackground(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black87;
}

String _shortDayLabel(String label) {
  final String trimmed = label.trim();
  if (trimmed.isEmpty) {
    return 'DAY';
  }
  return trimmed
      .substring(0, trimmed.length < 3 ? trimmed.length : 3)
      .toUpperCase();
}
