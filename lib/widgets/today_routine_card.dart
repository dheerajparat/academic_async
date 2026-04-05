import 'package:academic_async/controllers/routine_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TodayRoutineCard extends GetView<RoutineController> {
  const TodayRoutineCard({
    super.key,
    this.onTap,
    this.maxItems = 4,
    this.showActionHint = true,
  });

  final VoidCallback? onTap;
  final int maxItems;
  final bool showActionHint;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Obx(() {
      final String todayKey = controller.today;
      final String todayLabel = controller.dayLabel(todayKey);
      final List<MapEntry<String, String>> todayItems = controller.periods
          .map((String period) {
            final String? subject = controller.routine[period]?[todayKey];
            if (subject == null || subject.trim().isEmpty || subject == '-') {
              return null;
            }
            return MapEntry(period, subject);
          })
          .whereType<MapEntry<String, String>>()
          .toList();
      final List<MapEntry<String, String>> visibleItems = todayItems
          .take(maxItems)
          .toList();
      final bool hasItems = todayItems.isNotEmpty;

      return Card(
        elevation: 0,
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  colors.primaryContainer.withValues(alpha: 0.95),
                  colors.tertiaryContainer.withValues(alpha: 0.72),
                ],
              ),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.today_rounded, color: colors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today's Routine",
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            todayLabel,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: hasItems
                            ? colors.surface.withValues(alpha: 0.52)
                            : colors.surface.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        hasItems
                            ? '${todayItems.length} class${todayItems.length == 1 ? '' : 'es'}'
                            : 'No classes',
                        style: TextStyle(
                          color: hasItems
                              ? colors.primary
                              : colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                if (!hasItems)
                  Text(
                    'No routine planned for today yet.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  )
                else
                  ...visibleItems.map(
                    (MapEntry<String, String> item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.key.toUpperCase(),
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                item.value,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (todayItems.length > maxItems) ...[
                  const SizedBox(height: 2),
                  Text(
                    '+${todayItems.length - maxItems} more classes',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (onTap != null && showActionHint) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Tap to open the full weekly routine.',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }
}
