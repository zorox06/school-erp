part of '../screen.dart';

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
  Widget build(BuildContext context) {
    final current = AppScope.of(context)
        .learningItems(worksheet)
        .where((r) => r.id == this.record.id)
        .firstOrNull;
    final record = current ?? this.record;
    return AppPage(
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
        if (!teacher && !worksheet) ...[
          Text(switch (record.status) {
            'reviewed' => 'Reviewed',
            'submitted' => 'Submitted',
            'pending' => 'Saved locally',
            _ => 'Assigned',
          }, style: textStyle(15, weight: FontWeight.w800)),
          if (record.fields['submission'] case final Map submission) ...[
            for (final id in submission['_scan_ids'] as List? ?? [])
              ScanCover(key: ValueKey(id), id: id as String),
            if (submission['asset_ids'] is List &&
                (submission['asset_ids'] as List).isNotEmpty)
              SchoolAttachments(ids: submission['asset_ids'] as List),
            if (submission['feedback'] != null)
              Text('Teacher feedback · ${submission['feedback']}'),
          ],
          const SizedBox(height: 12),
        ],
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
          style: textStyle(12, color: context.tones.muted),
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
