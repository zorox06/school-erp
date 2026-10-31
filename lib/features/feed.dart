import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/data.dart';
import '../core/phase_one/models.dart';
import '../ui/components.dart';
import 'learning.dart';
import 'notices.dart';
import 'school.dart';

class WhatsNew extends StatelessWidget {
  const WhatsNew({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final items = <(int, DateTime, String, String, IconData, VoidCallback)>[];
    for (final a in c.phaseOne?.entries.values ?? <AttendanceEntry>[]) {
      if (!c.workspace.isStaff && a.studentId != c.selectedChildId) continue;
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
      items.add((
        n.important && !n.acknowledged ? 0 : 2,
        n.publishedAt,
        n.title,
        n.important && !n.acknowledged
            ? 'Acknowledgement required'
            : 'School circular',
        LucideIcons.newspaper,
        () => openPage(
          context,
          Scaffold(
            appBar: AppBar(title: const Text('Notices')),
            body: const NoticesScreen(),
          ),
        ),
      ));
    }
    for (final h in c.learningItems(false)) {
      final due = h.date;
      items.add((
        h.status == 'submitted' ? 3 : 1,
        due ?? DateTime.fromMillisecondsSinceEpoch(0),
        h.title ?? 'Homework',
        due == null
            ? 'No due date'
            : 'Due ${due.toLocal().toString().substring(0, 16)}',
        LucideIcons.bookOpen,
        () => openPage(
          context,
          LearningDetailScreen(record: h, teacher: c.workspace.isStaff),
        ),
      ));
    }
    items.sort((a, b) {
      final p = a.$1.compareTo(b.$1);
      return p == 0
          ? (a.$1 == 1 ? a.$2.compareTo(b.$2) : b.$2.compareTo(a.$2))
          : p;
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading('What’s new'),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const EmptyPanel(
            icon: LucideIcons.sparkles,
            title: 'A fresh start.',
            message:
                'Attendance, homework and circulars will come together here.',
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
