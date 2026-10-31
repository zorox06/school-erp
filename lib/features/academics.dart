import '../ui/subject_chart.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/data.dart';
import '../core/school_features.dart';
import '../ui/components.dart';
import '../ui/attachments.dart';
import '../ui/quick_sheet.dart';

class AcademicsScreen extends StatelessWidget {
  const AcademicsScreen({super.key});
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
    return AppPage(
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
                  ? () => openPage(context, MarksScreen(assessment: a))
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
  }
}

class AssessmentComposer extends StatefulWidget {
  const AssessmentComposer({super.key});
  @override
  State<AssessmentComposer> createState() => _AssessmentState();
}

class _AssessmentState extends State<AssessmentComposer> {
  final title = TextEditingController(),
      subject = TextEditingController(),
      max = TextEditingController();
  String? classroom;
  DateTime? date;
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    subject.dispose();
    max.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final c = AppScope.of(context);
    final maximum = num.tryParse(max.text);
    if (!c.canWrite ||
        c.features == null ||
        classroom == null ||
        date == null ||
        title.text.trim().isEmpty ||
        subject.text.trim().isEmpty ||
        maximum == null ||
        maximum <= 0 ||
        maximum > 10000) {
      tell(context, 'Choose a class, title, subject and valid maximum score.');
      return;
    }
    setState(() => busy = true);
    try {
      final p = <String, dynamic>{
        'class_id': classroom,
        'title': title.text.trim(),
        'subject': subject.text.trim(),
        'max_score': maximum,
        'exam_at': date?.toUtc().toIso8601String(),
      };
      await c.features!.queue(
        'assessment',
        p,
        collection: 'assessments',
        optimistic: p,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) tell(context, 'Couldn’t save this assessment.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return AppPage(
      title: 'An opportunity to grow.',
      eyebrow: 'New assessment',
      children: [
        DropdownButtonFormField<String>(
          initialValue: classroom,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Class'),
          items: c.snapshot.classes
              .map(
                (e) => DropdownMenuItem(
                  value: e.id,
                  child: Text(e.title ?? 'Class'),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => classroom = v),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: title,
          maxLength: 140,
          decoration: const InputDecoration(labelText: 'Assessment title'),
        ),
        TextField(
          controller: subject,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Subject'),
        ),
        TextField(
          controller: max,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Maximum score'),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(LucideIcons.calendarDays),
          label: Text(
            date == null
                ? 'Choose exam date & time'
                : DateFormat('d MMM yyyy, h:mm a').format(date!),
          ),
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 3),
            );
            if (d == null || !context.mounted) return;
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (t != null) {
              setState(
                () => date = DateTime(d.year, d.month, d.day, t.hour, t.minute),
              );
            }
          },
        ),
        const SizedBox(height: 22),
        PrimaryButton('Save assessment', onPressed: save, busy: busy),
      ],
    );
  }
}

class MarksScreen extends StatefulWidget {
  final SchoolRow assessment;
  const MarksScreen({super.key, required this.assessment});
  @override
  State<MarksScreen> createState() => _MarksState();
}

class _MarksState extends State<MarksScreen> {
  final edits = <String, String>{};
  final errors = <String, String>{};
  bool loading = true, saving = false;
  String query = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AppScope.of(context).phaseOne
          ?.loadRoster(widget.assessment['class_id'] as String);
      if (!mounted) return;
      try {
        await AppScope.of(context).features
            ?.loadGrades(widget.assessment['id'] as String);
      } catch (_) {
        if (mounted) {
          tell(
            context,
            'Downloaded marks shown. Refresh before changing marks that are missing.',
          );
        }
      }
      if (mounted) setState(() => loading = false);
    });
  }

  Future<void> save() async {
    final c = AppScope.of(context);
    final h = c.features;
    if (h == null || !c.canWrite) return;
    final max = (widget.assessment['max_score'] as num).toDouble();
    errors.clear();
    for (final e in edits.entries) {
      final score = num.tryParse(e.value);
      if (score == null || score < 0 || score > max) {
        errors[e.key] = 'Enter 0 to $max';
      }
    }
    if (errors.isNotEmpty) {
      setState(() {});
      return;
    }
    setState(() => saving = true);
    try {
      for (final e in edits.entries) {
        final old = h
            .rows('grades')
            .where(
              (g) =>
                  g['assessment_id'] == widget.assessment['id'] &&
                  g['student_id'] == e.key,
            )
            .firstOrNull;
        final p = <String, dynamic>{
          'assessment_id': widget.assessment['id'],
          'student_id': e.key,
          'score': num.parse(e.value),
          'expected_version': old?['version'] ?? 0,
        };
        await h.queue(
          'grade',
          p,
          collection: 'grades',
          key: '${widget.assessment['id']}/${e.key}',
          optimistic: {...p, 'version': old?['version'] ?? 0},
        );
      }
      edits.clear();
      if (mounted) {
        tell(context, 'Edited marks saved. Newer server marks take priority.');
      }
    } catch (_) {
      if (mounted) {
        tell(context, 'Some marks couldn’t be saved. Review pending sync.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final students = (c.phaseOne?.students ?? [])
        .where(
          (s) =>
              s.classId == widget.assessment['class_id'] &&
              s.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assessment['title'] as String? ?? 'Marks'),
        actions: [
          TextButton(
            onPressed: saving ? null : save,
            child: const Text('Save edits'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search student'),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (c.features?.conflicts != 0 && c.features?.conflicts != null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: InfoBanner(
                'A newer school mark was kept. Refresh and review before editing.',
              ),
            ),
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('No students in this register.'))
                : FocusTraversalGroup(
                    child: ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, i) {
                        final s = students[i];
                        final old = c.features
                            ?.rows('grades')
                            .where(
                              (g) =>
                                  g['assessment_id'] ==
                                      widget.assessment['id'] &&
                                  g['student_id'] == s.id,
                            )
                            .firstOrNull;
                        return ListTile(
                          title: Text(s.name),
                          subtitle: s.roll == null
                              ? null
                              : Text('Roll ${s.roll}'),
                          trailing: SizedBox(
                            width: 120,
                            child: TextFormField(
                              key: ValueKey(
                                '${s.id}/${old?['version']}/${old?['_pending']}',
                              ),
                              initialValue:
                                  edits[s.id] ?? old?['score']?.toString(),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Mark',
                                errorText: errors[s.id],
                                suffixText:
                                    '/ ${widget.assessment['max_score']}',
                              ),
                              onChanged: (v) => edits[s.id] = v,
                              onFieldSubmitted: (_) =>
                                  FocusScope.of(context).nextFocus(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class ReviewSubmissionsScreen extends StatelessWidget {
  final String? homeworkId;
  const ReviewSubmissionsScreen({super.key, this.homeworkId});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final items = (c.features?.rows('submissions') ?? <SchoolRow>[])
        .where((r) => homeworkId == null || r['homework_id'] == homeworkId)
        .toList();
    return AppPage(
      title: 'Room for good feedback.',
      eyebrow: 'Submitted work',
      children: [
        if (items.isEmpty)
          const EmptyPanel(
            icon: LucideIcons.clipboardCheck,
            title: 'No submissions yet',
            message:
                'Completed work from your assigned classes will appear here.',
          ),
        ...items.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r['student_name'] as String? ?? 'Submitted work',
                    style: textStyle(17, weight: FontWeight.w800),
                  ),
                  Text(r['body'] as String? ?? ''),
                  SchoolAttachments(ids: r['asset_ids'] as List? ?? []),
                  if (r['feedback'] != null) Text(r['feedback'] as String),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final feedback = TextEditingController(
                        text: r['feedback'] as String?,
                      );
                      await quickSheet<void>(
                        context,
                        (context, scroll) => ListView(
                          controller: scroll,
                          padding: EdgeInsets.fromLTRB(
                            22,
                            10,
                            22,
                            MediaQuery.viewInsetsOf(context).bottom + 22,
                          ),
                          children: [
                            Text(
                              'Thoughtful feedback',
                              style: textStyle(23, weight: FontWeight.w800),
                            ),
                            TextField(
                              controller: feedback,
                              maxLength: 4000,
                              minLines: 3,
                              maxLines: 8,
                            ),
                            PrimaryButton(
                              'Save feedback',
                              onPressed: () async {
                                if (c.features == null) return;
                                await c.features!.queue(
                                  'feedback',
                                  {
                                    'submission_id': r['id'],
                                    'feedback': feedback.text.trim(),
                                  },
                                  collection: 'submissions',
                                  key: r['id'] as String,
                                  optimistic: {
                                    ...r,
                                    'feedback': feedback.text.trim(),
                                  },
                                );
                                if (context.mounted) Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      );
                      feedback.dispose();
                    },
                    child: const Text('Review & respond'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
