import 'timetable_edit.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/data.dart';
import '../core/theme.dart';
import '../ui/components.dart';
import 'homework.dart';
import 'academics.dart';
import '../ui/attachments.dart';

class LearningPage extends StatelessWidget {
  final int initial;
  final bool teacher;
  const LearningPage({super.key, this.initial = 0, this.teacher = false});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Go back',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(LucideIcons.arrowLeft, size: 21),
      ),
      title: Text('Learning', style: textStyle(13, weight: FontWeight.w700)),
    ),
    body: SafeArea(
      top: false,
      child: LearningScreen(initial: initial, teacher: teacher),
    ),
  );
}

class LearningScreen extends StatefulWidget {
  final int initial;
  final bool teacher;
  const LearningScreen({super.key, this.initial = 0, this.teacher = false});
  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  late int kind = widget.initial;
  int filter = 0;
  String query = '';
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final records = c.learningItems(kind == 1);
    final filtered = records
        .where(
          (e) => '${e.title ?? ''} ${e.category ?? ''}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .where(
          (e) =>
              filter == 0 ||
              (kind == 0 && filter == 1
                  ? e.status == 'submitted'
                  : kind == 0 && filter == 2
                  ? e.status == 'reviewed'
                  : true),
        )
        .toList();
    return ContentList(
      onRefresh: c.refresh,
      children: [
        ScreenHeading(
          widget.teacher ? 'Learning in motion.' : 'Room to grow.',
          eyebrow: widget.teacher ? 'Your teaching shelf' : 'Learning',
          subtitle: widget.teacher
              ? 'Thoughtful lessons. Meaningful progress.'
              : 'A little practice. A little progress. Every day.',
        ),
        FilterTabs(
          labels: const ['Homework', 'Worksheets', 'Timetable'],
          selected: kind,
          onSelected: (i) => setState(() {
            kind = i;
            filter = 0;
            query = '';
          }),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => openPage(context, const AcademicsScreen()),
          icon: const Icon(LucideIcons.chartNoAxesCombined),
          label: const Text("Marks & exams"),
        ),
        const SizedBox(height: 12),
        if (kind == 2)
          const TimetableContent()
        else ...[
          if (widget.teacher) ...[
            PrimaryButton(
              kind == 0 ? 'Create homework' : 'Upload worksheet',
              icon: LucideIcons.plus,
              onPressed: () =>
                  openPage(context, HomeworkComposer(worksheet: kind == 1)),
            ),
            const SizedBox(height: 20),
          ],
          TextField(
            key: ValueKey('search-$kind'),
            onChanged: (v) => setState(() => query = v),
            decoration: InputDecoration(
              hintText: kind == 0
                  ? 'Search homework or subject'
                  : 'Search your worksheets',
              prefixIcon: const Icon(LucideIcons.search, size: 18),
            ),
          ),
          const SizedBox(height: 17),
          if (kind == 0) ...[
            FilterTabs(
              labels: const ['All', 'Submitted', 'Reviewed'],
              selected: filter,
              onSelected: (i) => setState(() => filter = i),
            ),
            const SizedBox(height: 22),
          ],
          if (filtered.isEmpty)
            EmptyPanel(
              icon: kind == 0 ? LucideIcons.notebookPen : LucideIcons.files,
              title: query.isNotEmpty
                  ? 'No matches just yet.'
                  : kind == 0
                  ? 'A clean page for learning.'
                  : 'Your teaching shelf is ready.',
              message: query.isNotEmpty
                  ? 'Try another title or subject.'
                  : kind == 0
                  ? (widget.teacher
                        ? 'Create your first homework when a class is linked to your account. Nothing has been assigned yet.'
                        : 'Homework from your child’s teachers will appear here, with clear instructions and due dates.')
                  : 'Worksheets and practice material will appear here when your school shares them.',
              color: kind == 1 ? Palette.blue : Palette.teal,
              background: kind == 1 ? Palette.blueWash : Palette.mint,
            )
          else
            ...filtered.map(
              (e) => RecordTile(
                e,
                icon: kind == 0 ? LucideIcons.bookOpen : LucideIcons.fileText,
                onTap: () => openPage(
                  context,
                  LearningDetailScreen(
                    record: e,
                    worksheet: kind == 1,
                    teacher: widget.teacher,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 21),
          if (c.features?.hasMore[kind == 0 ? 'homework' : 'worksheets'] ==
              true)
            OutlinedButton(
              onPressed: () => c.features!.moreLearning(
                kind == 0 ? 'homework' : 'worksheets',
              ),
              child: const Text('Load more learning'),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                LucideIcons.lockKeyhole,
                size: 12,
                color: Palette.muted,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Shared securely by your school.',
                  style: textStyle(10, color: Palette.muted),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class TimetableContent extends StatefulWidget {
  const TimetableContent({super.key});
  @override
  State<TimetableContent> createState() => _TimetableContentState();
}

class _TimetableContentState extends State<TimetableContent> {
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  late DateTime week = selected.subtract(Duration(days: selected.weekday - 1));
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final entries = c.timetableItems
        .where((e) => e.date == null || DateUtils.isSameDay(e.date, selected))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(selected),
                style: textStyle(17, weight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Previous week',
              onPressed: () => setState(() {
                week = week.subtract(const Duration(days: 7));
                selected = week;
              }),
              icon: const Icon(LucideIcons.chevronLeft, size: 19),
            ),
            IconButton(
              tooltip: 'Next week',
              onPressed: () => setState(() {
                week = week.add(const Duration(days: 7));
                selected = week;
              }),
              icon: const Icon(LucideIcons.chevronRight, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(7, (i) {
            final day = week.add(Duration(days: i));
            final active = DateUtils.isSameDay(day, selected);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: active ? Palette.teal : Palette.paper,
                  borderRadius: BorderRadius.circular(13),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() => selected = day),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('EEEEE').format(day),
                            style: textStyle(
                              9,
                              color: active ? Colors.white70 : Palette.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${day.day}',
                            style: textStyle(
                              14,
                              weight: FontWeight.w800,
                              color: active ? Colors.white : Palette.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        Text(
          DateFormat('EEEE, d MMMM').format(selected),
          style: textStyle(13, weight: FontWeight.w700),
        ),
        const SizedBox(height: 15),
        if (entries.isEmpty)
          const EmptyPanel(
            icon: LucideIcons.calendarDays,
            title: 'A little room in the day.',
            message: 'No timetable has been shared for this day. Your classes and periods will appear here when they are available.',
            color: Palette.blue,
            background: Palette.blueWash,
          )
        else
          ...entries.map(
            (e) => RecordTile(
              e,
              icon: LucideIcons.clock,
              onTap: () => openPage(
                context,
                RecordDetailScreen(record: e, section: 'Timetable'),
              ),
            ),
          ),
      ],
    );
  }
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  Widget build(BuildContext context) => ContentList(
    onRefresh: AppScope.of(context).refresh,
    children: [
      if (AppScope.of(context).workspace.isStaff)
        OutlinedButton(
          onPressed: () => openPage(context, const TimetableComposer()),
          child: const Text('Update timetable / substitute'),
        ),
      const ScreenHeading(
        'Your teaching day.',
        eyebrow: 'Timetable',
        subtitle: 'A clear view of what’s ahead.',
      ),
      const TimetableContent(),
    ],
  );
}

class LearningDetailScreen extends StatelessWidget {
  final SchoolRecord record;
  final bool worksheet, teacher;
  const LearningDetailScreen({
    super.key,
    required this.record,
    this.worksheet = false,
    this.teacher = false,
  });
  @override
  Widget build(BuildContext context) => AppPage(
    title: record.title ?? '—',
    eyebrow: worksheet ? 'Worksheet' : 'Homework',
    children: [
      if (record.category != null) Tag(record.category!),
      const SizedBox(height: 20),
      Text(
        record.description ?? 'No instructions have been added.',
        style: textStyle(15, height: 1.7),
      ),
      const SizedBox(height: 24),
      const SectionHeading('Attachments'),
      const SizedBox(height: 12),
      SchoolAttachments(ids: record.fields['asset_ids'] as List? ?? const []),
      const SizedBox(height: 24),
      if (!worksheet)
        PrimaryButton(
          teacher ? 'Review submissions' : 'Add completed work',
          icon: teacher ? LucideIcons.clipboardCheck : LucideIcons.upload,
          onPressed: () => teacher
              ? openPage(
                  context,
                  ReviewSubmissionsScreen(homeworkId: record.id),
                )
              : showSubmissionSheet(context, record),
        ),
    ],
  );
}

class SubmissionsScreen extends StatelessWidget {
  const SubmissionsScreen({super.key});
  @override
  Widget build(BuildContext context) => const ReviewSubmissionsScreen();
}

class RecordDetailScreen extends StatelessWidget {
  final SchoolRecord record;
  final String section;
  const RecordDetailScreen({
    super.key,
    required this.record,
    required this.section,
  });
  @override
  Widget build(BuildContext context) => AppPage(
    title: record.title ?? '—',
    eyebrow: section,
    children: [
      if (record.category != null) Tag(record.category!),
      if (record.date != null) ...[
        const SizedBox(height: 15),
        Text(
          DateFormat('EEEE, d MMMM yyyy').format(record.date!),
          style: textStyle(12, color: Palette.muted),
        ),
      ],
      const SizedBox(height: 24),
      Text(
        record.description ?? 'No additional details have been shared.',
        style: textStyle(15, height: 1.75),
      ),
    ],
  );
}
