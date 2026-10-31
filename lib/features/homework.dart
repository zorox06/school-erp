import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/data.dart';
import '../core/media.dart';
import '../core/theme.dart';
import '../ui/components.dart';
import 'scanner.dart';

class HomeworkComposer extends StatefulWidget {
  final bool worksheet;
  const HomeworkComposer({super.key, this.worksheet = false});
  @override
  State<HomeworkComposer> createState() => _HomeworkComposerState();
}

class _HomeworkComposerState extends State<HomeworkComposer> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(), body = TextEditingController();
  final classes = <String>{};
  final files = <LocalAttachment>[];
  DateTime? due;
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return AppPage(
      title: widget.worksheet
          ? 'A little more practice.'
          : 'From the board to home.',
      eyebrow: widget.worksheet ? 'New worksheet' : 'New homework',
      children: [
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Photo. Due date. Classes.',
                style: textStyle(16, weight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              AttachmentPicker(
                files: files,
                enabled: c.canWrite && c.workspace.isStaff,
                onChanged: () => setState(() {}),
              ),
              const SizedBox(height: 20),
              FormLabel(
                'Title',
                child: TextFormField(
                  controller: title,
                  maxLength: 140,
                  decoration: const InputDecoration(
                    hintText: 'What are we learning?',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Add a homework title'
                      : null,
                ),
              ),
              FormLabel(
                'Instructions',
                child: TextFormField(
                  controller: body,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 8000,
                  decoration: const InputDecoration(
                    hintText: 'A few clear instructions…',
                  ),
                ),
              ),
              FormLabel(
                widget.worksheet ? 'Practice date (optional)' : 'Due date',
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDate: due ?? DateTime.now(),
                    );
                    if (d != null && mounted) setState(() => due = d);
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    due == null
                        ? 'Choose a date'
                        : DateFormat('EEE, d MMM').format(due!),
                  ),
                ),
              ),
              FormLabel(
                'Classes',
                child: Column(
                  children: [
                    if (c.snapshot.classes.isEmpty)
                      const InfoBanner(
                        'Your school must assign a class before you can post learning material.',
                      ),
                    for (final item in c.snapshot.classes)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.title ?? 'Assigned class'),
                        value: classes.contains(item.id),
                        onChanged: busy
                            ? null
                            : (v) => setState(() {
                                if (v == true) {
                                  classes.add(item.id);
                                } else {
                                  classes.remove(item.id);
                                }
                              }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                busy
                    ? 'Saving…'
                    : widget.worksheet
                    ? 'Share worksheet'
                    : 'Post homework',
                icon: LucideIcons.send,
                busy: busy,
                onPressed: () async {
                  if (!form.currentState!.validate()) return;
                  if (c.features == null ||
                      !c.canWrite ||
                      !c.workspace.isStaff) {
                    tell(context, const SchoolDataUnavailable().toString());
                    return;
                  }
                  if (classes.isEmpty || (!widget.worksheet && due == null)) {
                    tell(context, 'Choose your classes and a due date.');
                    return;
                  }
                  if (widget.worksheet && files.isEmpty) {
                    tell(context, 'Attach a worksheet to share.');
                    return;
                  }
                  setState(() => busy = true);
                  try {
                    final payload = {
                      'title': title.text.trim(),
                      'body': body.text.trim(),
                      'class_ids': classes.toList(),
                      'due_at': due
                          ?.add(const Duration(hours: 17))
                          .toUtc()
                          .toIso8601String(),
                      'attachments': files.map((f) => f.toJson()).toList(),
                    };
                    await c.features!.queue(
                      widget.worksheet ? 'worksheet' : 'homework',
                      payload,
                      collection: widget.worksheet ? 'worksheets' : 'homework',
                      optimistic: {...payload, 'asset_ids': <String>[]},
                    );
                    if (context.mounted) {
                      tell(
                        context,
                        'Saved on this device. It will post when synced.',
                      );
                      Navigator.pop(context);
                    }
                  } catch (_) {
                    if (context.mounted) {
                      tell(
                        context,
                        'Couldn’t save this homework. Your draft is still here.',
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
      ],
    );
  }
}

class AttachmentPicker extends StatelessWidget {
  final List<LocalAttachment> files;
  final bool enabled, scan;
  final VoidCallback onChanged;
  const AttachmentPicker({
    super.key,
    required this.files,
    required this.enabled,
    required this.onChanged,
    this.scan = false,
  });
  Future<void> pick(BuildContext context, String kind) async {
    final c = AppScope.of(context);
    if (!enabled || c.auth.userId == null) {
      tell(context, 'Connect your school account before attaching files.');
      return;
    }
    if (files.length >= 5) {
      tell(context, 'You can attach up to five files.');
      return;
    }
    try {
      LocalAttachment? file;
      if (kind == 'camera') file = await SchoolMedia.photo(c.auth.userId!);
      if (kind == 'scan' && context.mounted) {
        file = await openPage<LocalAttachment>(
          context,
          DocumentScannerScreen(owner: c.auth.userId!),
        );
      }
      if (kind == 'file') {
        final picked = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        );
        if (picked != null) {
          final length = await picked.length();
          if (length == null || length == 0 || length > 10485760) {
            throw const FormatException('File too large');
          }
          final bytes = await picked.readAsBytes();
          final name = picked.name.toLowerCase();
          final mime = name.endsWith('.pdf')
              ? 'application/pdf'
              : name.endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
          file = await SchoolMedia.persist(
            c.auth.userId!,
            bytes,
            mime,
            name: picked.name,
          );
        }
      }
      if (file != null && context.mounted) {
        files.add(file);
        onChanged();
      }
    } catch (_) {
      if (context.mounted) {
        tell(
          context,
          'Choose a readable PDF or photo under 10 MB. Check camera/file permissions if needed.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scan ? 'Share clear pages.' : 'A photo says it clearly.',
              style: textStyle(17, weight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              scan ? 'Crop and enhance your work, then save it as a PDF.' : 'Capture the board or choose a file. Attachments stay private.',
              style: textStyle(12, color: Palette.muted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => pick(context, scan ? 'scan' : 'camera'),
                  icon: Icon(
                    scan
                        ? Icons.document_scanner_outlined
                        : Icons.camera_alt_outlined,
                    size: 18,
                  ),
                  label: Text(scan ? 'Scan work' : 'Board photo'),
                ),
                TextButton.icon(
                  onPressed: () => pick(context, 'file'),
                  icon: const Icon(Icons.attach_file, size: 18),
                  label: const Text('Choose file'),
                ),
              ],
            ),
          ],
        ),
      ),
      for (var i = 0; i < files.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            files[i].mime == 'application/pdf'
                ? Icons.picture_as_pdf_outlined
                : Icons.image_outlined,
            color: Palette.teal,
          ),
          title: Text(
            files[i].name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${(files[i].bytes / 1024).ceil()} KB · On this device',
          ),
          trailing: IconButton(
            tooltip: 'Remove ${files[i].name}',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              files.removeAt(i);
              onChanged();
            },
          ),
        ),
    ],
  );
}

Future<void> showSubmissionSheet(BuildContext context, SchoolRecord homework) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SubmissionSheet(homework: homework),
    );

class _SubmissionSheet extends StatefulWidget {
  final SchoolRecord homework;
  const _SubmissionSheet({required this.homework});
  @override
  State<_SubmissionSheet> createState() => _SubmissionSheetState();
}

class _SubmissionSheetState extends State<_SubmissionSheet> {
  final files = <LocalAttachment>[];
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
              style: textStyle(13, color: Palette.muted),
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
