part of '../screen.dart';

Future<void> showSubmissionSheet(
  BuildContext context,
  SchoolRecord homework, {
  LocalAttachment? initialFile,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _SubmissionSheet(homework: homework, initialFile: initialFile),
);

class _SubmissionSheet extends StatefulWidget {
  final SchoolRecord homework;
  final LocalAttachment? initialFile;
  const _SubmissionSheet({required this.homework, this.initialFile});
  @override
  State<_SubmissionSheet> createState() => _SubmissionSheetState();
}

class _SubmissionSheetState extends State<_SubmissionSheet> {
  late final files = <LocalAttachment>[?widget.initialFile];
  final note = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          0,
          22,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share completed work.',
              style: textStyle(24, weight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              widget.homework.title ?? 'Homework',
              style: textStyle(13, color: context.tones.muted),
            ),
            const SizedBox(height: 20),
            AttachmentPicker(
              files: files,
              enabled: c.canWrite && c.workspace.canSubmitWork,
              scan: true,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: note,
              maxLength: 4000,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'A note for your teacher (optional)',
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              'Submit work',
              busy: busy,
              onPressed: () async {
                if (c.features == null ||
                    !c.canWrite ||
                    c.selectedChildId == null ||
                    !c.workspace.canSubmitWork) {
                  tell(context, const SchoolDataUnavailable().toString());
                  return;
                }
                if (files.isEmpty) {
                  tell(context, 'Scan or attach completed work first.');
                  return;
                }
                setState(() => busy = true);
                try {
                  await c.features!.queue(
                    'submission',
                    {
                      'homework_id': widget.homework.id,
                      'student_id': c.selectedChildId,
                      'body': note.text.trim(),
                      'attachments': files.map((f) => f.toJson()).toList(),
                    },
                    collection: 'submissions',
                    optimistic: {
                      'homework_id': widget.homework.id,
                      'student_id': c.selectedChildId,
                      'body': note.text.trim(),
                      'asset_ids': <String>[],
                      '_scan_ids': [
                        for (final f in files)
                          if (f.preview != null) f.id,
                      ],
                    },
                  );
                  if (context.mounted) {
                    tell(
                      context,
                      'Work saved on this device. It will submit when synced.',
                    );
                    Navigator.pop(context);
                  }
                } catch (_) {
                  if (context.mounted) {
                    tell(
                      context,
                      'Couldn’t save this submission. Please retry.',
                    );
                  }
                } finally {
                  if (mounted) setState(() => busy = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
