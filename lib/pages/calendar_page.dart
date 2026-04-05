import 'package:academic_async/controllers/calendar_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarPage extends GetView<CalendarController> {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Obx(() {
      final DateTime selectedDate = controller.selectedDay.value;
      final DateTime focusedDate = controller.focusedDay.value;
      final bool monthView = controller.isMonthView.value;
      final List<MapEntry<DateTime, List<String>>> monthGroups = controller
          .getMonthEventGroups(focusedDate);
      final List<String> selectedEvents = controller.getEventsForDay(
        selectedDate,
      );

      return ListView(
        children: [
          Card(
            color: colors.surface,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: TableCalendar<String>(
                firstDay: DateTime(2020, 1, 1),
                lastDay: DateTime(2035, 12, 31),
                focusedDay: focusedDate,
                calendarFormat: controller.calendarFormat.value,
                selectedDayPredicate: (day) =>
                    isSameDay(controller.selectedDay.value, day),
                eventLoader: controller.getEventsForDay,
                startingDayOfWeek: StartingDayOfWeek.monday,
                availableGestures: AvailableGestures.all,
                onDaySelected: controller.onDaySelected,
                onPageChanged: controller.onPageChanged,
                onFormatChanged: controller.onFormatChanged,
                headerStyle: HeaderStyle(
                  formatButtonVisible: true,
                  titleCentered: true,
                  formatButtonDecoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  formatButtonTextStyle: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  titleTextStyle: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  leftChevronIcon: Icon(
                    Icons.chevron_left_rounded,
                    color: colors.primary,
                  ),
                  rightChevronIcon: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.primary,
                  ),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: TextStyle(color: colors.onSurfaceVariant),
                  weekendStyle: TextStyle(color: colors.primary),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  markerDecoration: BoxDecoration(
                    color: colors.tertiary,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: TextStyle(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  defaultTextStyle: TextStyle(color: colors.onSurface),
                  weekendTextStyle: TextStyle(color: colors.onSurface),
                ),
              ),
            ),
          ),
          if (controller.isLoading.value)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          const SizedBox(height: 12),
          _SectionHeader(
            title: monthView
                ? 'Month events (${focusedDate.month}/${focusedDate.year})'
                : 'Events for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
            action: !monthView
                ? OutlinedButton(
                    onPressed: controller.showMonthEvents,
                    child: const Text('View month events'),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          if (monthView) ...[
            if (monthGroups.isEmpty)
              _EmptyEventCard(text: 'No events in this month.', colors: colors)
            else
              ...monthGroups.map((group) {
                return _DateEventCard(
                  date: group.key,
                  events: group.value,
                  colors: colors,
                );
              }),
          ] else ...[
            if (selectedEvents.isEmpty)
              _EmptyEventCard(text: 'No events for this day.', colors: colors)
            else
              ...selectedEvents.asMap().entries.map((entry) {
                final int index = entry.key;
                final String event = entry.value;
                return _SingleEventCard(
                  title: 'Event ${index + 1}',
                  event: event,
                  colors: colors,
                );
              }),
          ],
          const SizedBox(height: 16),
        ],
      );
    });
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
        action ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _DateEventCard extends StatelessWidget {
  const _DateEventCard({
    required this.date,
    required this.events,
    required this.colors,
  });

  final DateTime date;
  final List<String> events;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${date.day}/${date.month}/${date.year}',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${events.length} event(s)',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...events.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.event_note_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SingleEventCard extends StatelessWidget {
  const _SingleEventCard({
    required this.title,
    required this.event,
    required this.colors,
  });

  final String title;
  final String event;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(Icons.event_available_rounded, color: colors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(event),
      ),
    );
  }
}

class _EmptyEventCard extends StatelessWidget {
  const _EmptyEventCard({required this.text, required this.colors});

  final String text;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text, style: TextStyle(color: colors.onSurfaceVariant)),
      ),
    );
  }
}
