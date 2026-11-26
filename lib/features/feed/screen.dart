import '../academics/screen.dart';

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/phase_one/models.dart';
import '../../ui/components.dart';
import '../learning/screen.dart';
import '../notices/screen.dart';
import '../school/screen.dart';

class WhatsNew extends StatelessWidget {
  final DateTime? day;
  const WhatsNew({super.key, this.day});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final family = !c.workspace.isStaff;
    final today = DateUtils.dateOnly(day ?? DateTime.now());
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final items = <(int, DateTime, String, String, IconData, VoidCallback)>[];
    for (final a in c.phaseOne?.entries.values ?? <AttendanceEntry>[]) {
      if (!c.workspace.isStaff && a.studentId != c.selectedChildId) continue;
      if (family && !DateUtils.isSameDay(DateTime.tryParse(a.day), today)) {
        continue;
      }
      items.add((
        a.status == AttendanceStatus.absent ? 0 : 3,
        DateTime.parse(a.day),
        'Attendance: ${a.status.name}',
        a.day,
        LucideIcons.clipboardCheck,
        () => openPage(
          context,
          Scaffold(
            appBar: AppBar(title: const Text('Attendance')),
            body: const AttendanceContent(),
          ),
        ),
      ));
    }
    for (final n in c.phaseOne?.notices ?? <SchoolNotice>[]) {
      if (family && (!n.important || n.acknowledged)) continue;
      items.add((
        n.important && !n.acknowledged ? 0 : 2,
        n.publishedAt,
        n.title,
        n.important && !n.acknowledged
            ? 'Acknowledgement required'
            : 'School circular',
        LucideIcons.newspaper,
        () => showNoticeSheet(context, n),
      ));
    }
    for (final h in c.learningItems(false)) {
      final due = h.date;
      if (family &&
          (due == null ||
              ['submitted', 'reviewed'].contains(h.status) ||
              !(DateUtils.isSameDay(due.toLocal(), today) ||
                  DateUtils.isSameDay(due.toLocal(), tomorrow)))) {
        continue;
      }
      items.add((
        h.status == 'submitted' ? 3 : 1,
        due ?? DateTime.fromMillisecondsSinceEpoch(0),
        h.title ?? 'Homework',
        due == null
            ? 'No due date'
            : DateUtils.isSameDay(due.toLocal(), tomorrow)
            ? 'Due tomorrow'
            : 'Due ${DateFormat('EEE, d MMM').format(due.toLocal())}',
        LucideIcons.bookOpen,
        () => openPage(
          context,
          LearningDetailScreen(record: h, teacher: c.workspace.isStaff),
        ),
      ));
    }
    for (final exam
        in c.features?.rows('assessments') ?? <Map<String, dynamic>>[]) {
      final at = DateTime.tryParse(exam['exam_at']?.toString() ?? '')
          ?.toLocal();
      if (at != null && !at.isBefore(today)) {
        items.add((
          1,
          at,
          exam['title']?.toString() ?? 'Exam',
          'Exam · ${DateFormat('EEE, d MMM').format(at)} · ${DateTime.utc(at.year, at.month, at.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays} days',
          LucideIcons.calendarClock,
          () => openPage(context, const AcademicsScreen()),
        ));
      }
    }
    if (family) {
      for (final lesson in c.timetableItems.where(
        (r) => DateUtils.isSameDay(r.date?.toLocal(), today),
      )) {
        items.add((
          2,
          lesson.date!.toLocal(),
          lesson.title ?? 'Lesson',
          DateFormat('HH:mm').format(lesson.date!.toLocal()),
          LucideIcons.calendarClock,
          () => openPage(context, TimetableDayPage(day: today, teacher: false)),
        ));
      }
    }
    items.sort((a, b) {
      final pastA = a.$2.isBefore(today), pastB = b.$2.isBefore(today);
      if (pastA != pastB) return pastA ? 1 : -1;
      return pastA ? b.$2.compareTo(a.$2) : a.$2.compareTo(b.$2);
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(family ? 'Morning brief' : 'School activity'),
        const SizedBox(height: 14),
        if (items.isEmpty)
          EmptyPanel(
            icon: LucideIcons.newspaper,
            title: family ? 'No updates for this day' : 'No recent activity',
            message:
                'Attendance updates, homework and school notices appear here.',
            compact: true,
          ),
        ...items
            .take(12)
            .map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Surface(
                  onTap: r.$6,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconBadge(r.$5),
                    title: Text(r.$3),
                    subtitle: Text(r.$4),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
