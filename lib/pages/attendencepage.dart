import 'package:academic_async/controllers/attendance_controller.dart';
import 'package:academic_async/models/attendance_models.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Attendencepage extends GetView<AttendanceController> {
  const Attendencepage({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Obx(() {
      if (controller.isBootstrapping.value) {
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      }

      if (controller.errorMessage.value.isNotEmpty) {
        return Center(
          child: Text(
            controller.errorMessage.value,
            style: TextStyle(color: colors.error),
            textAlign: TextAlign.center,
          ),
        );
      }

      if (controller.isTeacher.value) {
        return _TeacherAttendanceView(colors: colors, controller: controller);
      }
      return _StudentAttendanceView(colors: colors, controller: controller);
    });
  }
}

class _TeacherAttendanceView extends StatelessWidget {
  const _TeacherAttendanceView({
    required this.colors,
    required this.controller,
  });

  final ColorScheme colors;
  final AttendanceController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int liveNowMillis = controller.liveClockMillis.value;
      final AttendanceEntry? selectedSession =
          controller.selectedTeacherSession;
      final int mappedSubjects = controller.teacherSubjects.length;
      final Color successTone = _successToneColor(colors);
      return RefreshIndicator(
        onRefresh: controller.refreshTeacherReport,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            _attendancePageBottomPadding(context),
          ),
          children: [
            _AttendanceHeroBanner(
              colors: colors,
              icon: Icons.fact_check_rounded,
              title: 'Attendance Desk',
              subtitle:
                  'Create live classroom sessions, monitor attendance marks, and submit final attendance cleanly.',
              accent: colors.primary,
              footer: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    colors: colors,
                    icon: Icons.menu_book_rounded,
                    label:
                        '$mappedSubjects subject${mappedSubjects == 1 ? '' : 's'} mapped',
                  ),
                  _InfoPill(
                    colors: colors,
                    icon: Icons.people_alt_rounded,
                    label:
                        '${controller.selectedTeacherSessionPresentCount} students in selected session',
                  ),
                  _InfoPill(
                    colors: colors,
                    icon: selectedSession?.isFinalized == true
                        ? Icons.task_alt_rounded
                        : controller.isSelectedTeacherSessionLive
                        ? Icons.bolt_rounded
                        : Icons.history_toggle_off_rounded,
                    label: selectedSession == null
                        ? 'No session selected'
                        : selectedSession.isFinalized
                        ? 'Session submitted'
                        : controller.isSelectedTeacherSessionLive
                        ? 'Live session running'
                        : 'Reviewing previous session',
                    tint: selectedSession?.isFinalized == true
                        ? colors.primary
                        : controller.isSelectedTeacherSessionLive
                        ? successTone
                        : colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AttendancePanel(
              colors: colors,
              icon: Icons.play_circle_fill_rounded,
              title: 'Create Live Session',
              subtitle:
                  'Select class context, choose students, and start a direct location-based attendance session.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (controller.teacherSubjects.isEmpty)
                    Text(
                      'No subject mapped to this teacher.',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>(
                            'subject-${controller.selectedSubjectId.value}',
                          ),
                          initialValue:
                              controller.selectedSubjectId.value.isEmpty
                              ? null
                              : controller.selectedSubjectId.value,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Subject',
                            border: OutlineInputBorder(),
                          ),
                          items: controller.createSessionSubjects
                              .map(
                                (subject) => DropdownMenuItem<String>(
                                  value: subject.id,
                                  child: Text(
                                    _buildSubjectDropdownLabel(subject),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              controller.selectTeacherSubject(value);
                            }
                          },
                        ),
                        if (controller
                            .selectedTeacherSubjectContexts
                            .isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: controller
                                  .selectedTeacherSubjectContexts
                                  .map(
                                    (AttendanceSubjectContext context) =>
                                        _InfoPill(
                                          colors: colors,
                                          icon: Icons.account_tree_rounded,
                                          label:
                                              context.semesterWithBranchLabel,
                                        ),
                                  )
                                  .toList(),
                            ),
                          ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>(
                            'branch-${controller.selectedBranchId.value}',
                          ),
                          initialValue:
                              controller.selectedBranchId.value.isEmpty
                              ? null
                              : controller.selectedBranchId.value,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Branch',
                            border: OutlineInputBorder(),
                          ),
                          items: controller.branchOptions
                              .map(
                                (AttendanceOption option) =>
                                    DropdownMenuItem<String>(
                                      value: option.id,
                                      child: Text(option.label),
                                    ),
                              )
                              .toList(),
                          onChanged: controller.isLoadingAttendanceContext.value
                              ? null
                              : (String? value) {
                                  if (value != null) {
                                    controller.selectAttendanceBranch(value);
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>(
                            'semester-${controller.selectedSemesterId.value}',
                          ),
                          initialValue:
                              controller.selectedSemesterId.value.isEmpty
                              ? null
                              : controller.selectedSemesterId.value,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Semester',
                            border: OutlineInputBorder(),
                          ),
                          items: controller.semesterOptions
                              .map(
                                (AttendanceOption option) =>
                                    DropdownMenuItem<String>(
                                      value: option.id,
                                      child: Text(option.label),
                                    ),
                              )
                              .toList(),
                          onChanged: controller.isLoadingAttendanceContext.value
                              ? null
                              : (String? value) {
                                  if (value != null) {
                                    controller.selectAttendanceSemester(value);
                                  }
                                },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey<int>(
                                  controller.qrValidityMinutes.value,
                                ),
                                initialValue:
                                    controller.qrValidityMinutes.value,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Session Window (min)',
                                  border: OutlineInputBorder(),
                                ),
                                items: controller.qrValidityMinuteOptions
                                    .map(
                                      (minutes) => DropdownMenuItem<int>(
                                        value: minutes,
                                        child: Text('$minutes min'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    controller.setQrValidityMinutes(value);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey<int>(
                                  controller.qrGraceDelaySeconds.value,
                                ),
                                initialValue:
                                    controller.qrGraceDelaySeconds.value,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Grace (sec)',
                                  border: OutlineInputBorder(),
                                ),
                                items: controller.qrGraceDelaySecondOptions
                                    .map(
                                      (seconds) => DropdownMenuItem<int>(
                                        value: seconds,
                                        child: Text('$seconds sec'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    controller.setQrGraceDelaySeconds(value);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _tintedSurface(
                              colors,
                              colors.primary,
                              opacity: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.near_me_rounded,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Selected branch and semester ke students, jinke profile me ye subject mapped hai, wahi attendance dekh payenge aur 50m ke andar mark kar payenge.',
                                  style: TextStyle(
                                    color: colors.onSurface,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: controller.isGeneratingQr.value
                          ? null
                          : controller.generateAttendanceSession,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        controller.isGeneratingQr.value
                            ? 'Generating...'
                            : 'Start Attendance Session',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (selectedSession != null) ...[
              const SizedBox(height: 12),
              _AttendancePanel(
                colors: colors,
                icon: Icons.radar_rounded,
                title: 'Selected Session',
                subtitle:
                    'Review timing, location, assigned students, and submission state of the selected session.',
                trailing: _SessionStatusChip(
                  colors: colors,
                  label: selectedSession.isFinalized
                      ? 'Submitted'
                      : controller.isSelectedTeacherSessionLive
                      ? _formatRemainingTime(
                          controller.selectedTeacherSessionSecondsLeft,
                        )
                      : 'Expired',
                  tone: selectedSession.isFinalized
                      ? _PanelTone.primary
                      : controller.isSelectedTeacherSessionLive
                      ? _PanelTone.success
                      : _PanelTone.error,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          colors: colors,
                          icon: Icons.book_rounded,
                          label: selectedSession.subjectName,
                        ),
                        _InfoPill(
                          colors: colors,
                          icon: Icons.people_alt_rounded,
                          label:
                              '${controller.selectedTeacherSessionPresentCount} present',
                          tint: colors.primary,
                        ),
                        _InfoPill(
                          colors: colors,
                          icon: Icons.place_rounded,
                          label:
                              '${selectedSession.allowedRadiusMeters.toStringAsFixed(0)}m radius',
                        ),
                        _InfoPill(
                          colors: colors,
                          icon: Icons.schedule_rounded,
                          label:
                              '${selectedSession.validForSeconds}s + ${selectedSession.graceDelaySeconds}s delay',
                        ),
                        _InfoPill(
                          colors: colors,
                          icon: Icons.account_tree_rounded,
                          label:
                              '${selectedSession.semester} • ${selectedSession.branch}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SessionInfoRow(
                      colors: colors,
                      icon: Icons.location_searching_rounded,
                      label:
                          'Teacher GPS: ${selectedSession.generateLatitude.toStringAsFixed(6)}, ${selectedSession.generateLongitude.toStringAsFixed(6)}',
                    ),
                    const SizedBox(height: 8),
                    _SessionInfoRow(
                      colors: colors,
                      icon: Icons.play_circle_outline_rounded,
                      label:
                          'Started: ${_formatDateTime(selectedSession.startTimeMillis)}',
                    ),
                    if (selectedSession.isFinalized &&
                        selectedSession.finalizedAtMillis > 0) ...[
                      const SizedBox(height: 8),
                      _SessionInfoRow(
                        colors: colors,
                        icon: Icons.task_alt_rounded,
                        label:
                            'Submitted: ${_formatDateTime(selectedSession.finalizedAtMillis)}',
                      ),
                    ],
                    if (controller.isSelectedTeacherSessionLive &&
                        controller.activeEntry.value?.id ==
                            selectedSession.id) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: controller.qrExtendMinuteOptions
                            .map(
                              (minutes) => OutlinedButton.icon(
                                onPressed: controller.isExtendingQr.value
                                    ? null
                                    : () => controller.extendActiveQrByMinutes(
                                        minutes,
                                      ),
                                icon: const Icon(Icons.add_alarm_rounded),
                                label: Text('+${minutes}m'),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (!selectedSession.isFinalized)
                          FilledButton.icon(
                            onPressed: controller.isMutatingTeacherSession.value
                                ? null
                                : () async {
                                    final bool confirmed =
                                        await _confirmFinalizeSession() ??
                                        false;
                                    if (confirmed) {
                                      await controller
                                          .finalizeSelectedSession();
                                    }
                                  },
                            icon: const Icon(Icons.task_alt_rounded),
                            label: Text(
                              controller.isMutatingTeacherSession.value
                                  ? 'Submitting...'
                                  : 'Final Submit',
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _tintedSurface(
                          colors,
                          selectedSession.isFinalized
                              ? colors.primary
                              : colors.secondary,
                          opacity: 0.10,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              (selectedSession.isFinalized
                                      ? colors.primary
                                      : colors.secondary)
                                  .withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        selectedSession.isFinalized
                            ? 'This session is locked. Students can no longer mark attendance.'
                            : 'Selected branch and semester ke subject-matched students ko ye session dikhai dega, aur location/time sahi hone par attendance mark hogi.',
                        style: TextStyle(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _AttendancePanel(
                colors: colors,
                icon: Icons.groups_2_rounded,
                title: 'Marked Students',
                subtitle:
                    'Every valid attendance mark is listed here. Remove only incorrect entries before final submit.',
                child: controller.selectedTeacherSessionStudents.isEmpty
                    ? _EmptySectionState(
                        colors: colors,
                        icon: Icons.person_search_rounded,
                        title: 'No student marked yet',
                        subtitle:
                            'When assigned students mark attendance near you, their names and time will appear here.',
                      )
                    : Column(
                        children: controller.selectedTeacherSessionStudents
                            .map(
                              (scan) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _StudentScanTile(
                                  colors: colors,
                                  scan: scan,
                                  isLocked: selectedSession.isFinalized,
                                  onRemove: selectedSession.isFinalized
                                      ? null
                                      : () async {
                                          final bool confirmed =
                                              await _confirmRemoveStudent(
                                                scan.name.isEmpty
                                                    ? scan.uid
                                                    : scan.name,
                                              ) ??
                                              false;
                                          if (confirmed) {
                                            await controller
                                                .removeStudentFromSelectedSession(
                                                  scan.uid,
                                                );
                                          }
                                        },
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
            const SizedBox(height: 12),
            _AttendancePanel(
              colors: colors,
              icon: Icons.dashboard_customize_rounded,
              title: 'Teacher Overview',
              subtitle:
                  'High-level classroom activity across all attendance sessions.',
              child: Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: 'Sessions',
                      value: '${controller.totalTeacherSessionsCreated}',
                      icon: Icons.layers_rounded,
                      colors: colors,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                      label: 'Students',
                      value: '${controller.totalTeacherStudentsPresent}',
                      icon: Icons.people_alt_rounded,
                      colors: colors,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                      label: 'Days',
                      value: '${controller.totalTeacherDaysCovered}',
                      icon: Icons.calendar_month_rounded,
                      colors: colors,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AttendancePanel(
              colors: colors,
              icon: Icons.analytics_rounded,
              title: 'Subject-wise Report',
              subtitle:
                  'Track how many sessions were created and the average turnout per subject.',
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    onPressed: controller.isLoadingTeacherReport.value
                        ? null
                        : controller.refreshTeacherReport,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  IconButton(
                    tooltip: 'Save Excel report',
                    onPressed: controller.isExportingTeacherReport.value
                        ? null
                        : controller.exportTeacherExcelReport,
                    icon: Icon(
                      controller.isExportingTeacherReport.value
                          ? Icons.hourglass_top_rounded
                          : Icons.save_alt_rounded,
                    ),
                  ),
                ],
              ),
              child: Column(
                children: [
                  if (controller.isLoadingTeacherReport.value)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (controller.teacherReport.isEmpty)
                    _EmptySectionState(
                      colors: colors,
                      icon: Icons.bar_chart_rounded,
                      title: 'No report data yet',
                      subtitle:
                          'Generate and run attendance sessions to start building the report.',
                    )
                  else
                    ...controller.teacherReport.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ReportSubjectTile(colors: colors, report: item),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AttendancePanel(
              colors: colors,
              icon: Icons.history_edu_rounded,
              title: 'Session History',
              subtitle:
                  'Tap any session to inspect its details and marked students.',
              child: controller.teacherSessions.isEmpty
                  ? _EmptySectionState(
                      colors: colors,
                      icon: Icons.history_rounded,
                      title: 'No session created yet',
                      subtitle:
                          'Your created sessions will appear here for quick review.',
                    )
                  : Column(
                      children: controller.teacherSessions
                          .take(25)
                          .map(
                            (session) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _TeacherSessionHistoryTile(
                                colors: colors,
                                session: session,
                                nowMillis: liveNowMillis,
                                isSelected:
                                    controller.selectedTeacherSessionId.value ==
                                    session.id,
                                onTap: () =>
                                    controller.selectTeacherSession(session.id),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      );
    });
  }
}

class _StudentAttendanceView extends StatelessWidget {
  const _StudentAttendanceView({
    required this.colors,
    required this.controller,
  });

  final ColorScheme colors;
  final AttendanceController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final int liveNowMillis = controller.liveClockMillis.value;
      final int presentDays = controller.studentDailyRecords
          .where((e) => e.wasPresent)
          .length;
      final Color heroForeground = _contentColorForBackground(colors.secondary);
      final Color heroButtonForeground = _contentColorForBackground(
        heroForeground,
      );
      return RefreshIndicator(
        onRefresh: controller.refreshStudentData,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            _attendancePageBottomPadding(context),
          ),
          children: [
            _AttendanceHeroBanner(
              colors: colors,
              icon: Icons.school_rounded,
              title: 'Attendance Snapshot',
              subtitle:
                  'Assigned live sessions appear here directly. Move near your teacher and mark attendance without any QR step.',
              accent: colors.secondary,
              footer: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${controller.overallStudentPercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: heroForeground,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: heroForeground,
                          foregroundColor: heroButtonForeground,
                        ),
                        onPressed: controller.isLoadingStudentData.value
                            ? null
                            : controller.refreshStudentData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                          controller.isLoadingStudentData.value
                              ? 'Refreshing...'
                              : 'Refresh',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoPill(
                        colors: colors,
                        icon: Icons.today_rounded,
                        label:
                            'Present days: $presentDays / ${controller.studentDailyRecords.length}',
                        foregroundOverride: heroForeground,
                        backgroundOverride: heroForeground.withValues(
                          alpha: 0.14,
                        ),
                      ),
                      _InfoPill(
                        colors: colors,
                        icon: Icons.radar_rounded,
                        label:
                            '${controller.availableStudentSessions.length} live session${controller.availableStudentSessions.length == 1 ? '' : 's'} available',
                        foregroundOverride: heroForeground,
                        backgroundOverride: heroForeground.withValues(
                          alpha: 0.14,
                        ),
                      ),
                      if (controller.lastScanMessage.value.trim().isNotEmpty)
                        _InfoPill(
                          colors: colors,
                          icon: Icons.verified_rounded,
                          label: controller.lastScanMessage.value,
                          foregroundOverride: heroForeground,
                          backgroundOverride: heroForeground.withValues(
                            alpha: 0.14,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AttendancePanel(
              colors: colors,
              icon: Icons.fact_check_rounded,
              title: 'Available Attendance',
              subtitle:
                  'Only sessions matching your branch and semester are shown here. Tap mark attendance when you are near your teacher.',
              child: controller.availableStudentSessions.isEmpty
                  ? _EmptySectionState(
                      colors: colors,
                      icon: Icons.notifications_active_outlined,
                      title: 'No live session available',
                      subtitle:
                          'When your teacher starts an attendance session for your subject, it will appear here automatically.',
                    )
                  : Column(
                      children: controller.availableStudentSessions
                          .map(
                            (AttendanceEntry entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _AvailableSessionTile(
                                colors: colors,
                                session: entry,
                                nowMillis: liveNowMillis,
                                isBusy: controller.isProcessingScan.value,
                                onMark: () => controller
                                    .markAttendanceForSession(entry.id),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 12),
            _AttendancePanel(
              colors: colors,
              icon: Icons.timeline_rounded,
              title: 'Day-wise Attendance',
              subtitle:
                  'Each day is marked present if you attended at least one scheduled class.',
              trailing: IconButton(
                onPressed: controller.refreshStudentData,
                icon: const Icon(Icons.refresh_rounded),
              ),
              child: controller.studentDailyRecords.isEmpty
                  ? _EmptySectionState(
                      colors: colors,
                      icon: Icons.event_busy_rounded,
                      title: 'No daily attendance records',
                      subtitle:
                          'Your class-wise attendance will roll up into this daily timeline.',
                    )
                  : Column(
                      children: controller.studentDailyRecords
                          .take(30)
                          .map(
                            (record) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _StudentDayTile(
                                colors: colors,
                                record: record,
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
            const SizedBox(height: 12),
            _AttendancePanel(
              colors: colors,
              icon: Icons.pie_chart_rounded,
              title: 'Subject-wise Attendance',
              subtitle:
                  'Your percentage and class-day count broken down subject by subject.',
              trailing: IconButton(
                onPressed: controller.refreshStudentData,
                icon: const Icon(Icons.refresh_rounded),
              ),
              child: Column(
                children: [
                  if (controller.isLoadingStudentData.value)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (controller.studentSummaries.isEmpty)
                    _EmptySectionState(
                      colors: colors,
                      icon: Icons.auto_graph_rounded,
                      title: 'No attendance records yet',
                      subtitle:
                          'Once you start marking classes, subject percentages will appear here.',
                    )
                  else
                    ...controller.studentSummaries.map(
                      (summary) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _StudentSummaryTile(
                          colors: colors,
                          summary: summary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _AttendancePanel(
              colors: colors,
              icon: Icons.history_rounded,
              title: 'Recent Attendance Marks',
              subtitle:
                  'A quick log of your latest successful attendance marks.',
              child: controller.studentHistory.isEmpty
                  ? _EmptySectionState(
                      colors: colors,
                      icon: Icons.fact_check_rounded,
                      title: 'No attendance history available',
                      subtitle:
                          'Successful attendance marks will appear here with date and time.',
                    )
                  : Column(
                      children: controller.studentHistory
                          .take(25)
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RecentScanTile(
                                colors: colors,
                                item: item,
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      );
    });
  }
}

class _StudentSummaryTile extends StatelessWidget {
  const _StudentSummaryTile({required this.colors, required this.summary});

  final ColorScheme colors;
  final SubjectAttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final double progress = ((summary.percentage / 100).clamp(
      0.0,
      1.0,
    )).toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.subjectName,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _SessionStatusChip(
                colors: colors,
                label: '${summary.percentage.toStringAsFixed(1)}%',
                tone: summary.percentage >= 75
                    ? _PanelTone.success
                    : summary.percentage >= 40
                    ? _PanelTone.primary
                    : _PanelTone.error,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            color: colors.primary,
          ),
          const SizedBox(height: 8),
          Text(
            'Present: ${summary.presentDays} / ${summary.totalClassDays} class days',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailableSessionTile extends StatelessWidget {
  const _AvailableSessionTile({
    required this.colors,
    required this.session,
    required this.nowMillis,
    required this.isBusy,
    required this.onMark,
  });

  final ColorScheme colors;
  final AttendanceEntry session;
  final int nowMillis;
  final bool isBusy;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final int secondsLeft = ((session.validUntilMillis - nowMillis) / 1000)
        .ceil();
    final String teacherName = session.teacherName.trim().isEmpty
        ? 'Teacher'
        : session.teacherName.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  session.subjectName,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _SessionStatusChip(
                colors: colors,
                label: _formatRemainingTime(secondsLeft),
                tone: _PanelTone.success,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(
                colors: colors,
                icon: Icons.person_pin_rounded,
                label: teacherName,
              ),
              _InfoPill(
                colors: colors,
                icon: Icons.place_rounded,
                label:
                    '${session.allowedRadiusMeters.toStringAsFixed(0)}m radius',
              ),
              _InfoPill(
                colors: colors,
                icon: Icons.schedule_rounded,
                label: _formatTime(session.startTimeMillis),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy ? null : onMark,
              icon: const Icon(Icons.verified_rounded),
              label: Text(isBusy ? 'Checking location...' : 'Mark Attendance'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.colors,
  });

  final String label;
  final String value;
  final IconData icon;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.16),
            colors.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colors.primary, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

enum _PanelTone { primary, success, error }

class _AttendanceHeroBanner extends StatelessWidget {
  const _AttendanceHeroBanner({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.footer,
  });

  final ColorScheme colors;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final Color accentBlend =
        Color.lerp(accent, colors.tertiary, 0.45) ?? accent;
    final Color foreground = _contentColorForBackground(
      Color.lerp(accent, accentBlend, 0.5) ?? accent,
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent, accentBlend],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: foreground.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: foreground, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w900,
              fontSize: 24,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.88),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          footer,
        ],
      ),
    );
  }
}

class _AttendancePanel extends StatelessWidget {
  const _AttendancePanel({
    required this.colors,
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final ColorScheme colors;
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.40),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colors.primary.withValues(alpha: 0.20),
                      colors.secondary.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: colors.primary),
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
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SessionStatusChip extends StatelessWidget {
  const _SessionStatusChip({
    required this.colors,
    required this.label,
    required this.tone,
  });

  final ColorScheme colors;
  final String label;
  final _PanelTone tone;

  @override
  Widget build(BuildContext context) {
    final Color toneColor;
    switch (tone) {
      case _PanelTone.primary:
        toneColor = colors.primary;
        break;
      case _PanelTone.success:
        toneColor = _successToneColor(colors);
        break;
      case _PanelTone.error:
        toneColor = colors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _tintedSurface(colors, toneColor),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: toneColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: toneColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.colors,
    required this.icon,
    required this.label,
    this.tint,
    this.backgroundOverride,
    this.foregroundOverride,
  });

  final ColorScheme colors;
  final IconData icon;
  final String label;
  final Color? tint;
  final Color? backgroundOverride;
  final Color? foregroundOverride;

  @override
  Widget build(BuildContext context) {
    final Color effectiveTint = tint ?? colors.primary;
    final Color background =
        backgroundOverride ?? _tintedSurface(colors, effectiveTint);
    final Color foreground = foregroundOverride ?? colors.onSurface;
    final Color iconColor = foregroundOverride ?? effectiveTint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: effectiveTint.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionInfoRow extends StatelessWidget {
  const _SessionInfoRow({
    required this.colors,
    required this.icon,
    required this.label,
  });

  final ColorScheme colors;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _StudentScanTile extends StatelessWidget {
  const _StudentScanTile({
    required this.colors,
    required this.scan,
    required this.isLocked,
    this.onRemove,
  });

  final ColorScheme colors;
  final AttendanceStudentScan scan;
  final bool isLocked;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final String displayName = scan.name.isEmpty ? scan.uid : scan.name;
    final String trimmed = displayName.trim();
    final String initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: Text(
              initial,
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(
                      colors: colors,
                      icon: Icons.schedule_rounded,
                      label: _formatTime(scan.scanTimeMillis),
                      tint: colors.primary,
                    ),
                    if (scan.distanceMeters != null)
                      _InfoPill(
                        colors: colors,
                        icon: Icons.straighten_rounded,
                        label: '${scan.distanceMeters!.toStringAsFixed(1)}m',
                        tint: _successToneColor(colors),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (!isLocked && onRemove != null)
            IconButton(
              tooltip: 'Remove student',
              onPressed: onRemove,
              icon: Icon(Icons.delete_outline_rounded, color: colors.error),
            ),
        ],
      ),
    );
  }
}

class _ReportSubjectTile extends StatelessWidget {
  const _ReportSubjectTile({required this.colors, required this.report});

  final ColorScheme colors;
  final TeacherSubjectReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.book_rounded, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.subjectName,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sessions: ${report.totalSessionsCreated} • Days: ${report.totalClassDays} • Avg present: ${report.avgPresentPerSession.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _SessionStatusChip(
            colors: colors,
            label: '${report.totalPresentScans}',
            tone: _PanelTone.primary,
          ),
        ],
      ),
    );
  }
}

class _TeacherSessionHistoryTile extends StatelessWidget {
  const _TeacherSessionHistoryTile({
    required this.colors,
    required this.session,
    required this.nowMillis,
    required this.isSelected,
    required this.onTap,
  });

  final ColorScheme colors;
  final AttendanceEntry session;
  final int nowMillis;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int secondsLeft = ((session.validUntilMillis - nowMillis) / 1000)
        .ceil();
    final bool isLive = !session.isFinalized && secondsLeft > 0;
    final _PanelTone tone = session.isFinalized
        ? _PanelTone.primary
        : isLive
        ? _PanelTone.success
        : session.isExpired
        ? _PanelTone.error
        : _PanelTone.success;
    final String label = session.isFinalized
        ? 'Submitted'
        : isLive
        ? _formatRemainingTime(secondsLeft)
        : session.isExpired
        ? 'Closed'
        : 'Live';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? colors.primary.withValues(alpha: 0.10)
                : colors.surfaceContainerHighest.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? colors.primary.withValues(alpha: 0.26)
                  : colors.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    '${session.presentCount}',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.subjectName,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${session.dateKey} • ${_formatTime(session.startTimeMillis)} • ${session.presentCount} present',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SessionStatusChip(colors: colors, label: label, tone: tone),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudentDayTile extends StatelessWidget {
  const _StudentDayTile({required this.colors, required this.record});

  final ColorScheme colors;
  final StudentDailyAttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final Color successTone = _successToneColor(colors);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: record.wasPresent
            ? _tintedSurface(colors, successTone, opacity: 0.08)
            : colors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: record.wasPresent
              ? successTone.withValues(alpha: 0.18)
              : colors.error.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: record.wasPresent
                  ? _tintedSurface(colors, successTone, opacity: 0.12)
                  : colors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              record.wasPresent
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: record.wasPresent ? successTone : colors.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.dateKey,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  record.wasPresent
                      ? _buildDailyAttendanceSubtitle(record)
                      : 'Absent • ${record.scheduledSessionCount} session scheduled',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _SessionStatusChip(
            colors: colors,
            label: record.wasPresent ? 'Present' : 'Absent',
            tone: record.wasPresent ? _PanelTone.success : _PanelTone.error,
          ),
        ],
      ),
    );
  }
}

class _RecentScanTile extends StatelessWidget {
  const _RecentScanTile({required this.colors, required this.item});

  final ColorScheme colors;
  final StudentAttendanceHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.history_rounded, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subjectName,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.dateKey} • ${_formatTime(item.displayTimeMillis)}',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySectionState extends StatelessWidget {
  const _EmptySectionState({
    required this.colors,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final ColorScheme colors;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: colors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

Color _tintedSurface(ColorScheme colors, Color tint, {double opacity = 0.14}) {
  return Color.alphaBlend(
    tint.withValues(alpha: opacity),
    colors.surfaceContainerHighest,
  );
}

Color _contentColorForBackground(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black87;
}

Color _successToneColor(ColorScheme colors) {
  return Color.lerp(colors.primary, const Color(0xFF2E7D32), 0.55) ??
      const Color(0xFF2E7D32);
}

String _buildDailyAttendanceSubtitle(StudentDailyAttendanceRecord record) {
  if (record.attendedClasses.isEmpty) {
    return 'Present';
  }
  final classes = record.attendedClasses
      .map(
        (item) =>
            '${item.subjectName} (${_formatTime(item.displayTimeMillis)})',
      )
      .join(', ');
  return '${record.attendedSessionCount}/${record.scheduledSessionCount} sessions • $classes';
}

double _attendancePageBottomPadding(BuildContext context) {
  final double safeBottom = MediaQuery.of(context).viewPadding.bottom;
  return safeBottom + 128;
}

Future<bool?> _confirmRemoveStudent(String studentName) {
  return Get.dialog<bool>(
    AlertDialog(
      title: const Text('Remove Student'),
      content: Text(
        'Remove $studentName from this attendance session? This will also remove the student from the final report.',
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back<bool>(result: false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Get.back<bool>(result: true),
          child: const Text('Remove'),
        ),
      ],
    ),
    barrierDismissible: true,
  );
}

Future<bool?> _confirmFinalizeSession() {
  return Get.dialog<bool>(
    AlertDialog(
      title: const Text('Final Submit Attendance'),
      content: const Text(
        'After final submit, students will not be able to mark attendance for this session. You can still view it, but live edits will stop.',
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back<bool>(result: false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Get.back<bool>(result: true),
          child: const Text('Submit'),
        ),
      ],
    ),
    barrierDismissible: true,
  );
}

String _formatTime(int millis) {
  if (millis <= 0) {
    return '--:--';
  }
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  final String h = dt.hour.toString().padLeft(2, '0');
  final String m = dt.minute.toString().padLeft(2, '0');
  final String s = dt.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

String _formatRemainingTime(int totalSeconds) {
  if (totalSeconds <= 0) {
    return 'Expired';
  }
  final int minutes = totalSeconds ~/ 60;
  final int seconds = totalSeconds % 60;
  if (minutes <= 0) {
    return '${seconds}s left';
  }
  return '${minutes}m ${seconds}s left';
}

String _formatDateTime(int millis) {
  if (millis <= 0) {
    return '--';
  }
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  final String y = dt.year.toString().padLeft(4, '0');
  final String mon = dt.month.toString().padLeft(2, '0');
  final String d = dt.day.toString().padLeft(2, '0');
  return '$y-$mon-$d ${_formatTime(millis)}';
}

String _buildSubjectDropdownLabel(AttendanceSubject subject) {
  if (subject.contexts.isEmpty) {
    return subject.name;
  }

  final List<String> labels = subject.contexts
      .map(
        (AttendanceSubjectContext context) => context.semesterWithBranchLabel,
      )
      .where((String value) => value.trim().isNotEmpty)
      .toList();
  if (labels.isEmpty) {
    return subject.name;
  }

  final List<String> visible = labels.take(2).toList();
  final String suffix = labels.length > 2 ? ' +${labels.length - 2} more' : '';
  return '${subject.name} (${visible.join(', ')})$suffix';
}
