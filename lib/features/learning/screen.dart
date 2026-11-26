import '../timetable_edit/screen.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../ui/components.dart';
import '../homework/screen.dart';
import '../academics/screen.dart';
import '../../ui/attachments.dart';

part 'widgets/timetable.dart';
part 'widgets/detail.dart';

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
              color: kind == 1 ? context.tones.blue : context.tones.teal,
              background: kind == 1
                  ? context.tones.blueWash
                  : context.tones.mint,
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
              Icon(
                LucideIcons.lockKeyhole,
                size: 12,
                color: context.tones.muted,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Shared securely by your school.',
                  style: textStyle(10, color: context.tones.muted),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
