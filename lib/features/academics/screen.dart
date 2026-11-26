import '../../ui/subject_chart.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/school_features.dart';
import '../../ui/components.dart';
import '../../ui/attachments.dart';
import '../../ui/quick_sheet.dart';

part 'widgets/assessment_composer.dart';
part 'widgets/mark_register.dart';
part 'widgets/submissions.dart';

class AcademicsScreen extends StatefulWidget {
  const AcademicsScreen({super.key});
  @override
  State<AcademicsScreen> createState() => _AcademicsState();
}

class _AcademicsState extends State<AcademicsScreen> {
  String? selectedId;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final exams = c.features?.rows('assessments') ?? <SchoolRow>[];
    final grades = c.features?.rows('grades') ?? <SchoolRow>[];
    final bySubject = <String, List<double>>{};
    for (final g in grades) {
      final a = exams.where((e) => e['id'] == g['assessment_id']).firstOrNull;
      if (a == null || g['score'] == null) continue;
      bySubject
          .putIfAbsent(a['subject'] as String? ?? 'Subject', () => [])
          .add(
            (g['score'] as num).toDouble() /
                (a['max_score'] as num).toDouble() *
                100,
          );
    }
    final wide = MediaQuery.sizeOf(context).width >= 950 && c.workspace.isStaff;
    final overview = AppPage(
      title: c.workspace.isStaff ? 'Marks & exams.' : 'Every step forward.',
      eyebrow: 'Academic progress',
      children: [
        if (c.workspace.isStaff)
          PrimaryButton(
            'Create assessment',
            icon: LucideIcons.plus,
            onPressed: () => openPage(context, const AssessmentComposer()),
          ),
        const SizedBox(height: 18),
        if (exams.isEmpty)
          const EmptyPanel(
            icon: LucideIcons.chartNoAxesCombined,
            title: 'A clear view of progress.',
            message: 'Exams and subject marks appear when your school publishes them.',
          ),
        ...exams.map((a) {
          final date = DateTime.tryParse(a['exam_at'] as String? ?? '');
          final days = date?.difference(DateTime.now()).inDays;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Surface(
              onTap: c.workspace.isStaff && a['_pending'] != true
                  ? () => wide
                        ? setState(() => selectedId = a['id'] as String)
                        : openPage(context, MarksScreen(assessment: a))
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a['title'] as String? ?? 'Assessment',
                    style: textStyle(17, weight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${a['subject'] ?? ''} · Maximum ${a['max_score'] ?? '—'}',
                  ),
                  if (date != null)
                    Text(
                      '${DateFormat('EEE, d MMM · h:mm a').format(date.toLocal())}${days != null && days >= 0 ? ' · $days days away' : ''}',
                    ),
                  if (a['_pending'] == true) const Tag('Pending sync'),
                  if (!c.workspace.isStaff)
                    ...grades
                        .where(
                          (g) =>
                              g['assessment_id'] == a['id'] &&
                              g['student_id'] == c.selectedChildId,
                        )
                        .map(
                          (g) => Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Tag('${g['score']} / ${a['max_score']}'),
                          ),
                        ),
                ],
              ),
            ),
          );
        }),
        if (!c.workspace.isStaff)
          ...bySubject.keys.map(
            (subject) => SubjectChart(
              subject: subject,
              marks: grades
                  .where(
                    (g) =>
                        g['subject'] == subject &&
                        g['student_id'] == c.selectedChildId,
                  )
                  .toList(),
            ),
          ),
      ],
    );
    if (!wide) return overview;
    final selected = exams.where((r) => r['id'] == selectedId).firstOrNull;
    return Row(
      children: [
        SizedBox(width: 310, child: overview),
        const VerticalDivider(width: 1),
        Expanded(
          child: selected == null
              ? const Center(child: Text('Select an assessment'))
              : MarksScreen(key: ValueKey(selectedId), assessment: selected),
        ),
      ],
    );
  }
}
