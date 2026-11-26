import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/school_features.dart';
import '../../core/theme.dart';
import '../../ui/components.dart';
import '../../ui/quick_sheet.dart';
import '../leave/screen.dart';
import '../attendance/screen.dart';

import 'cover_controller.dart';
export 'cover_controller.dart' show availableTeachers;

Future<void> chooseCover(
  BuildContext context,
  SchoolRecord slot,
  Set<String> absent, {
  required bool preservesDetails,
}) async {
  final c = AppScope.of(context), h = AppScope.of(context).features;
  if (h == null ||
      !c.workspace.isLeadership ||
      slot.fields['class_id'] == null) {
    return;
  }
  final metadata = slot.fields['data'];
  if (!preservesDetails &&
      metadata is Map &&
      metadata.keys.any((k) => k != 'class_id' && k != 'substitute_id')) {
    tell(
      context,
      'Your school needs the period coverage update before changing this lesson.',
    );
    return;
  }
  try {
    final raw =
        await h.gateway.call('erp_staff', {'p_school': h.school}) as List;
    if (!context.mounted || !h.active) return;
    final options = availableTeachers(
      raw.map((r) => Map<String, dynamic>.from(r as Map)).toList(),
      c.timetableItems,
      slot,
      absent,
    );
    final teacher = await quickSheet<String>(
      context,
      (sheet, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(18),
        children: [
          Text('Assign cover', style: textStyle(23, weight: FontWeight.w800)),
          Text(slot.title ?? 'Lesson'),
          const SizedBox(height: 10),
          if (options.isEmpty)
            const Text('No available teachers in the published timetable.'),
          for (final t in options)
            ListTile(
              leading: const Icon(LucideIcons.userRound),
              title: Text(t['name'] ?? 'Teacher'),
              onTap: () => Navigator.pop(sheet, t['id']),
            ),
        ],
      ),
    );
    if (teacher == null || !context.mounted || !h.active || h != c.features) {
      return;
    }
    await h.queue(
      'timetable_change',
      {
        'item_id': slot.id,
        'class_id': slot.fields['class_id'],
        'date': slot.date!.toUtc().toIso8601String(),
        'description': slot.description ?? '',
        'title': slot.title,
        'substitute_id': teacher,
      },
      collection: 'timetable',
      key: slot.id,
      optimistic: {
        ...slot.fields,
        'data': {
          ...Map<String, dynamic>.from(slot.fields['data'] as Map? ?? {}),
          'class_id': slot.fields['class_id'],
          'substitute_id': teacher,
        },
        'substitute_id': teacher,
      },
    );
    if (context.mounted) {
      tell(context, 'Cover assignment saved on this device.');
    }
  } catch (_) {
    if (context.mounted) {
      tell(context, 'Could not load or assign cover. Refresh and try again.');
    }
  }
}

Future<void> choosePeriod(BuildContext context) async {
  final c = AppScope.of(context), h = c.features;
  final slots =
      c.timetableItems
          .where(
            (s) =>
                s.fields['class_id'] != null &&
                DateUtils.isSameDay(s.date?.toLocal(), DateTime.now()),
          )
          .toList()
        ..sort((a, b) => a.date!.compareTo(b.date!));
  final lesson = await quickSheet<SchoolRecord>(
    context,
    (sheet, scroll) => ListView(
      controller: scroll,
      children: [
        const ListTile(title: Text('Choose a period')),
        if (slots.isEmpty)
          const ListTile(title: Text('No lessons available for cover today.')),
        for (final slot in slots)
          ListTile(
            title: Text(slot.title ?? 'Lesson'),
            leading: Text(DateFormat('HH:mm').format(slot.date!.toLocal())),
            onTap: () => Navigator.pop(sheet, slot),
          ),
      ],
    ),
  );
  if (lesson == null || !context.mounted || h == null || !h.active) return;
  try {
    final result = await h.gateway.call('erp_principal_summary', {
      'p_school': h.school,
      'p_day': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    });
    if (context.mounted && h.active && c.features == h) {
      await chooseCover(context, lesson, {
        for (final r in (result['absent_teachers'] as List? ?? []))
          r['id'].toString(),
      }, preservesDetails: result['unmarked_classes'] is List);
    }
  } catch (_) {
    if (context.mounted) {
      tell(context, 'Staff availability could not be loaded. Try again.');
    }
  }
}

class PulseOverview extends StatelessWidget {
  const PulseOverview({
    super.key,
    required this.summary,
    required this.onRefresh,
  });
  final SchoolRow summary;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final today = DateTime.now();
    final day = DateFormat('yyyy-MM-dd').format(today);
    final slots =
        c.timetableItems
            .where((s) => DateUtils.isSameDay(s.date?.toLocal(), today))
            .toList()
          ..sort((a, b) => a.date!.compareTo(b.date!));
    final absent = (summary['absent_teachers'] as List? ?? [])
        .map((r) => r['id'].toString())
        .toSet();
    final marked = c.phaseOne?.entries.values
        .where((e) => e.day == day)
        .map((e) => e.classId)
        .toSet();
    final unmarked = c.snapshot.classes
        .where((r) => marked != null && !marked.contains(r.id))
        .toList();
    final serverClasses = summary['unmarked_classes'] as List?;
    final classes = serverClasses == null
        ? unmarked
        : serverClasses
              .map(
                (r) =>
                    SchoolRecord.fromJson(Map<String, dynamic>.from(r as Map)),
              )
              .toList();
    final coverage = summary['coverage_percent'] as num?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pulse',
                style: textStyle(32, weight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Refresh daily summary',
              onPressed: onRefresh,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
            ),
          ],
        ),
        Text(
          DateFormat('EEEE, d MMMM').format(today),
          style: textStyle(13, color: context.tones.muted),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.tones.forest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Register coverage',
                style: textStyle(
                  14,
                  color: Colors.white,
                  weight: FontWeight.w700,
                ),
              ),
              Text(
                coverage == null ? '—' : '$coverage%',
                style: textStyle(
                  42,
                  height: 1.2,
                  color: Colors.white,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (coverage != null)
                LinearProgressIndicator(
                  value: (coverage / 100).clamp(0, 1),
                  color: const Color(0xff9fdbbe),
                  backgroundColor: const Color(0xff326256),
                ),
              Text(
                '${summary['recorded_students'] ?? '—'} of ${summary['total_students'] ?? '—'} students recorded',
                style: textStyle(12, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const SectionHeading('Needs attention'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.clipboardList),
          title: const Text('Classes without a register'),
          subtitle: Text(
            serverClasses == null
                ? 'Based on attendance on this device'
                : 'No entries recorded today',
          ),
          trailing: Text(
            marked == null && serverClasses == null ? '—' : '${classes.length}',
          ),
          onTap: () async {
            final id = await quickSheet<String>(
              context,
              (sheet, scroll) => ListView(
                controller: scroll,
                children: [
                  const ListTile(title: Text('Classes without a register')),
                  if (classes.isEmpty)
                    const ListTile(title: Text('No classes listed.')),
                  for (final r in classes)
                    ListTile(
                      title: Text(r.title ?? 'Class'),
                      onTap: () => Navigator.pop(sheet, r.id),
                    ),
                ],
              ),
            );
            if (id != null && context.mounted) {
              c.chooseClass(id);
              await openPage(context, const FastAttendanceScreen());
            }
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.users),
          title: const Text('Absent teachers'),
          trailing: Text(
            summary['absent_teachers'] == null ? '—' : '${absent.length}',
          ),
          onTap: () => choosePeriod(context),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.calendarCheck),
          title: const Text('Leave approvals'),
          trailing: Text(
            summary.isEmpty ? '—' : '${summary['pending_leave'] ?? 0}',
          ),
          onTap: () => openPage(context, const LeaveInboxScreen()),
        ),
        const Divider(),
        const SectionHeading('Period coverage'),
        if (slots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No lessons scheduled today.',
              style: textStyle(13, color: context.tones.muted),
            ),
          ),
        for (final s in slots)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Text(DateFormat('HH:mm').format(s.date!.toLocal())),
            title: Text(s.title ?? 'Lesson'),
            subtitle: Text(
              assignedTeacher(s) == null
                  ? 'No assigned teacher'
                  : absent.contains(assignedTeacher(s))
                  ? 'Cover needed'
                  : 'Teacher assigned',
            ),
            trailing: s.fields['class_id'] == null
                ? null
                : const Icon(LucideIcons.userRoundPlus, size: 17),
            onTap: s.fields['class_id'] == null
                ? null
                : () => chooseCover(
                    context,
                    s,
                    absent,
                    preservesDetails: serverClasses != null,
                  ),
          ),
      ],
    );
  }
}
