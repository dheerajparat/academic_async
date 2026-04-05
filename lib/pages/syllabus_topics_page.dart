import 'package:academic_async/controllers/syllabus_controller.dart';
import 'package:academic_async/models/syllabus_record.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SyllabusTopicsPage extends GetView<SyllabusController> {
  const SyllabusTopicsPage({super.key, required this.record});

  final SyllabusRecord record;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(record.title),
        foregroundColor: colors.primary,
      ),
      body: record.units.isEmpty
          ? Center(
              child: Text(
                'No units/topics added yet.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            )
          : Obx(() {
              // Ensures this observer stays subscribed even if a record has 0 topics.
              final _ = controller.completedTopicMap.length;

              final int overallDone = controller.completedTopicsCount(record);
              final int overallTotal = controller.totalTopicsCount(record);
              final double overallProgress = controller.completionPercent(
                record,
              );

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    color: colors.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overall completion',
                            style: TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: overallProgress,
                            minHeight: 7,
                            borderRadius: BorderRadius.circular(999),
                            backgroundColor: colors.primary.withValues(
                              alpha: 0.14,
                            ),
                            color: colors.primary,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$overallDone/$overallTotal topics completed (${(overallProgress * 100).round()}%)',
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...record.units.map((unit) {
                    final int done = controller.completedTopicsInUnit(
                      record,
                      unit,
                    );
                    final int total = controller.totalTopicsInUnit(unit);
                    final double percent = controller.unitCompletionPercent(
                      record,
                      unit,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        color: colors.surface,
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            initiallyExpanded: false,
                            leading: Icon(
                              Icons.view_agenda_rounded,
                              color: colors.primary,
                            ),
                            title: Text(
                              unit.title,
                              style: TextStyle(
                                color: colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '$done/$total topics • ${(percent * 100).round()}%',
                              style: TextStyle(color: colors.onSurfaceVariant),
                            ),
                            children: unit.topics.map((topic) {
                              final bool isDone = controller.isTopicCompleted(
                                record,
                                unit,
                                topic,
                              );
                              return CheckboxListTile(
                                shape: Border(
                                  top: BorderSide(
                                    width: 0.2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                value: isDone,
                                onChanged: (value) {
                                  controller.setTopicCompleted(
                                    record,
                                    unit,
                                    topic,
                                    value ?? false,
                                  );
                                },
                                title: Text(
                                  topic.title,
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: topic.details.trim().isEmpty
                                    ? null
                                    : Text(
                                        topic.details,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                secondary: topic.details.trim().isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () =>
                                            controller.showTopicDetails(topic),
                                        icon: const Icon(
                                          Icons.info_outline_rounded,
                                        ),
                                      ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }),
    );
  }
}
