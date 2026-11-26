import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/media.dart';
import '../../core/theme.dart';
import '../../ui/components.dart';
import '../scanner/screen.dart';

part 'widgets/attachments.dart';
part 'widgets/submission.dart';

class HomeworkComposer extends StatefulWidget {
  final bool worksheet;
  final LocalAttachment? initialFile;
  const HomeworkComposer({super.key, this.worksheet = false, this.initialFile});
  @override
  State<HomeworkComposer> createState() => _HomeworkComposerState();
}

class _HomeworkComposerState extends State<HomeworkComposer> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(), body = TextEditingController();
  final classes = <String>{};
  late final files = <LocalAttachment>[?widget.initialFile];
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
              if (c.learningItems(widget.worksheet).isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(LucideIcons.copy, size: 16),
                    label: const Text('Copy previous assignment'),
                    onPressed: busy
                        ? null
                        : () async {
                            final template =
                                await showModalBottomSheet<SchoolRecord>(
                                  context: context,
                                  builder: (sheet) => ListenableBuilder(
                                    listenable: c,
                                    builder: (context, _) {
                                      final kind = widget.worksheet
                                          ? 'worksheets'
                                          : 'homework';
                                      final records = c.learningItems(
                                        widget.worksheet,
                                      );
                                      return SafeArea(
                                        child: ListView.builder(
                                          itemCount: records.length + 2,
                                          itemBuilder: (context, index) {
                                            if (index == 0) {
                                              return const ListTile(
                                                title: Text(
                                                  'Choose previous work',
                                                ),
                                              );
                                            }
                                            if (index > records.length) {
                                              return c
                                                          .features
                                                          ?.hasMore[kind] ==
                                                      true
                                                  ? TextButton(
                                                      onPressed:
                                                          c.features!.loading
                                                          ? null
                                                          : () => c.features!
                                                                .moreLearning(
                                                                  kind,
                                                                ),
                                                      child: const Text(
                                                        'Load older assignments',
                                                      ),
                                                    )
                                                  : const SizedBox.shrink();
                                            }
                                            final r = records[index - 1];
                                            return ListTile(
                                              title: Text(
                                                r.title ?? 'Assignment',
                                              ),
                                              subtitle: r.date == null
                                                  ? null
                                                  : Text(
                                                      DateFormat('d MMM yyyy')
                                                          .format(
                                                            r.date!.toLocal(),
                                                          ),
                                                    ),
                                              onTap: () =>
                                                  Navigator.pop(sheet, r),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  ),
                                );
                            if (template == null || !mounted) return;
                            setState(() {
                              title.text = template.title ?? '';
                              body.text = template.description ?? '';
                            });
                          },
                  ),
                ),
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final item in c.snapshot.classes)
                          FilterChip(
                            label: Text(item.title ?? 'Class'),
                            selected: classes.contains(item.id),
                            onSelected: busy
                                ? null
                                : (v) => setState(() {
                                    if (v) {
                                      classes.add(item.id);
                                    } else {
                                      classes.remove(item.id);
                                    }
                                  }),
                          ),
                      ],
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
