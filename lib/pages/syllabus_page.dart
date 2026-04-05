import 'package:academic_async/controllers/syllabus_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SyllabusPage extends GetView<SyllabusController> {
  const SyllabusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Obx(() {
      if (controller.isLoading.value && controller.visibleItems.isEmpty) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }

      if (controller.errorMessage.value.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                controller.errorMessage.value,
                style: TextStyle(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: controller.refreshData,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }

      if (controller.requiresSemesterProfile &&
          controller.activeSemesterId.value.isEmpty) {
        return Center(
          child: Text(
            'Your semester is not available yet. Please complete profile data.',
            style: TextStyle(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        );
      }

      if (controller.visibleItems.isEmpty) {
        return Center(
          child: Text(
            controller.isTeacherScopedView
                ? controller.teacherSubjectLabels.isEmpty
                      ? 'No subjects are mapped to your teacher profile yet.'
                      : 'No syllabus found for your selected teaching subjects.'
                : 'No syllabus available for your semester.',
            style: TextStyle(color: colors.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: controller.refreshData,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            _syllabusPageBottomPadding(context),
          ),
          itemCount: controller.visibleItems.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = controller.visibleItems[index];
            final int totalTopics = controller.totalTopicsCount(item);
            final int completedTopics = controller.completedTopicsCount(item);
            final double progress = controller.completionPercent(item);
            final String percentText = '${(progress * 100).round()}%';
            return Card(
              color: colors.surface,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => controller.openTopics(item),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.menu_book_rounded, color: colors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            percentText,
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(999),
                        backgroundColor: colors.primary.withValues(alpha: 0.14),
                        color: colors.primary,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$completedTopics/$totalTopics topics completed',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

double _syllabusPageBottomPadding(BuildContext context) {
  final double safeBottom = MediaQuery.of(context).viewPadding.bottom;
  return safeBottom + 128;
}
