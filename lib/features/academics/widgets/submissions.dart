part of '../screen.dart';

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
