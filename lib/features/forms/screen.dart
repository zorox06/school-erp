import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../ui/components.dart';

enum FormKind { homework, worksheet, leave, submission, announcement }

class SchoolFormScreen extends StatefulWidget {
  final FormKind kind;
  final String? linkedId;
  const SchoolFormScreen({super.key, required this.kind, this.linkedId});
  @override
  State<SchoolFormScreen> createState() => _SchoolFormScreenState();
}

class _SchoolFormScreenState extends State<SchoolFormScreen> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(), instructions = TextEditingController();
  SchoolRecord? classroom;
  String? leaveType;
  DateTime? start, until;
  bool busy = false;
  final List<PlatformFile> files = [];
  bool get leave => widget.kind == FormKind.leave;
  bool get submission => widget.kind == FormKind.submission;
  bool get worksheet => widget.kind == FormKind.worksheet;
  bool get needsClass => !leave && !submission;
  String get heading => switch (widget.kind) {
    FormKind.homework => 'A new learning moment.',
    FormKind.worksheet => 'Make room for practice.',
    FormKind.leave => 'A little time away.',
    FormKind.submission => 'Share their hard work.',
    FormKind.announcement => 'A note for everyone.',
  };
  String get label => switch (widget.kind) {
    FormKind.homework => 'Create homework',
    FormKind.worksheet => 'Upload worksheet',
    FormKind.leave => 'Request leave',
    FormKind.submission => 'Submit homework',
    FormKind.announcement => 'Class announcement',
  };
  @override
  void dispose() {
    title.dispose();
    instructions.dispose();
    super.dispose();
  }

  Future<void> pickDate(bool end) async {
    final now = DateUtils.dateOnly(DateTime.now());
    final value = await showDatePicker(
      context: context,
      initialDate: end ? until ?? start ?? now : start ?? now,
      firstDate: end ? start ?? now : now,
      lastDate: DateTime(now.year + 2),
      helpText: end
          ? 'Last day of leave'
          : leave
          ? 'First day of leave'
          : 'Choose a due date',
    );
    if (value != null && mounted) {
      setState(() {
        if (end) {
          until = value;
        } else {
          start = value;
          if (until != null && until!.isBefore(value)) until = null;
        }
      });
    }
  }

  Future<void> pickClass() {
    final c = AppScope.of(context);
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose a class',
                style: textStyle(23, weight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              if (c.snapshot.classes.isEmpty)
                const EmptyPanel(
                  icon: LucideIcons.users,
                  title: 'No class linked yet',
                  message: 'Your school needs to assign your class before you can publish learning material.',
                  compact: true,
                )
              else
                ...c.snapshot.classes.map(
                  (e) => RecordTile(
                    e,
                    icon: LucideIcons.users,
                    onTap: () {
                      setState(() => classroom = e);
                      Navigator.pop(sheet);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> pickFile() async {
    if (files.length >= 3) {
      tell(context, 'You can attach up to 3 files.');
      return;
    }
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.length();
      if (!mounted) return;
      if (bytes == null || bytes == 0 || bytes > 5 * 1024 * 1024) {
        tell(context, 'Choose a PDF or image up to 5 MB.');
        return;
      }
      setState(() => files.add(picked));
    } catch (_) {
      if (mounted) {
        tell(context, 'We couldn’t open that file. Please try another.');
      }
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final c = AppScope.of(context);
    if (!c.canWrite) {
      tell(context, const SchoolDataUnavailable().toString());
      return;
    }
    if ((needsClass && !c.workspace.isStaff) ||
        (leave && c.workspace != Workspace.parent) ||
        (submission && !c.workspace.canSubmitWork)) {
      tell(context, 'Your school role does not allow this action.');
      return;
    }
    if (needsClass && classroom == null) {
      tell(context, 'Please choose your class first.');
      return;
    }
    if (leave &&
        (leaveType == null ||
            start == null ||
            until == null ||
            c.selectedChildId == null)) {
      tell(context, 'Select your child, leave type and both dates first.');
      return;
    }
    if (widget.kind == FormKind.homework && start == null) {
      tell(context, 'Please choose a due date.');
      return;
    }
    if (submission && widget.linkedId == null) {
      tell(
        context,
        'Open an assigned homework activity before submitting work.',
      );
      return;
    }
    if (worksheet && files.isEmpty) {
      tell(context, 'Please attach a worksheet first.');
      return;
    }
    if (files.isNotEmpty) {
      tell(
        context,
        'Your school needs to enable secure file uploads before attachments can be submitted. Your files have not been uploaded.',
      );
      return;
    }
    setState(() => busy = true);
    try {
      if (leave && c.features != null) {
        await c.features!.queue(
          'leave',
          {
            'student_id': c.selectedChildId,
            'starts_on': DateFormat('yyyy-MM-dd').format(start!),
            'ends_on': DateFormat('yyyy-MM-dd').format(until!),
            'reason': '${leaveType!}: ${instructions.text.trim()}',
          },
          collection: 'leaves',
          optimistic: {
            'student_id': c.selectedChildId,
            'starts_on': DateFormat('yyyy-MM-dd').format(start!),
            'ends_on': DateFormat('yyyy-MM-dd').format(until!),
            'reason': instructions.text.trim(),
            'status': 'pending',
          },
        );
      } else {
        await c.repository.saveItem(widget.kind.name, {
          'title': title.text.trim().isEmpty ? null : title.text.trim(),
          'description': instructions.text.trim(),
          'class_id': classroom?.id,
          'child_id': c.selectedChildId,
          'linked_id': widget.linkedId,
          'date': start?.toIso8601String(),
          'until': until?.toIso8601String(),
          'category': leaveType,
        });
      }
      await c.refresh();
      if (mounted) {
        tell(context, 'Your ${leave ? 'leave request' : 'update'} was saved.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        tell(
          context,
          'We couldn’t save this update. Your details are still here; please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget dateField(String text, DateTime? date, VoidCallback tap) => FormLabel(
    text,
    child: Surface(
      onTap: tap,
      radius: 16,
      padding: const EdgeInsets.all(17),
      child: Row(
        children: [
          Expanded(
            child: Text(
              date == null
                  ? 'Choose a date'
                  : DateFormat('d MMMM yyyy').format(date),
              style: textStyle(
                13,
                color: date == null ? context.tones.muted : context.tones.ink,
              ),
            ),
          ),
          Icon(LucideIcons.calendarDays, size: 18, color: context.tones.muted),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return AppPage(
      title: heading,
      eyebrow: label,
      children: [
        if (!c.canWrite) ...[
          const InfoBanner(
            'You can prepare your details here. Your school must link your account before anything can be published or submitted.',
          ),
          const SizedBox(height: 22),
        ],
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (needsClass)
                FormLabel(
                  'Class',
                  child: Surface(
                    onTap: pickClass,
                    radius: 16,
                    padding: const EdgeInsets.all(17),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            classroom?.title ?? 'Select your class',
                            style: textStyle(
                              13,
                              color: classroom == null
                                  ? context.tones.muted
                                  : context.tones.ink,
                            ),
                          ),
                        ),
                        const Icon(LucideIcons.chevronDown, size: 17),
                      ],
                    ),
                  ),
                ),
              if (leave)
                FormLabel(
                  'Leave type',
                  child: DropdownButtonFormField<String>(
                    initialValue: leaveType,
                    hint: Text(
                      'Select a leave type',
                      style: textStyle(13, color: context.tones.muted),
                    ),
                    items: const ['Medical', 'Personal', 'Other']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => leaveType = v),
                  ),
                ),
              if (!leave && !submission)
                FormLabel(
                  worksheet ? 'Worksheet title' : 'Title',
                  child: TextFormField(
                    controller: title,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 140,
                    decoration: InputDecoration(
                      hintText: worksheet
                          ? 'Give your worksheet a title'
                          : 'What will your class be learning?',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Please add a title'
                        : null,
                  ),
                ),
              FormLabel(
                leave
                    ? 'Reason for leave'
                    : submission
                    ? 'A note to the teacher (optional)'
                    : 'Instructions',
                child: TextFormField(
                  controller: instructions,
                  minLines: leave ? 3 : 4,
                  maxLines: 8,
                  maxLength: 4000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: leave
                        ? 'Let the class teacher know why your child needs leave…'
                        : submission
                        ? 'Add anything you’d like the teacher to know…'
                        : 'Share clear, helpful instructions…',
                  ),
                  validator: (v) =>
                      !submission && (v == null || v.trim().isEmpty)
                      ? 'Please add ${leave ? 'a reason' : 'some instructions'}'
                      : null,
                ),
              ),
              if (leave || widget.kind == FormKind.homework)
                dateField(
                  leave ? 'From' : 'Due date',
                  start,
                  () => pickDate(false),
                ),
              if (leave) dateField('Until', until, () => pickDate(true)),
              const SectionHeading('Attachments'),
              const SizedBox(height: 6),
              Text(
                'PDF or images · Up to 5 MB each · Maximum 3 files',
                style: textStyle(10, color: context.tones.muted),
              ),
              const SizedBox(height: 12),
              ...files.map(
                (file) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Surface(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    radius: 14,
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.fileText,
                          size: 19,
                          color: context.tones.teal,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            file.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textStyle(12),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove ${file.name}',
                          onPressed: () => setState(() => files.remove(file)),
                          icon: const Icon(LucideIcons.x, size: 17),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: files.length < 3 ? pickFile : null,
                icon: const Icon(LucideIcons.paperclip, size: 17),
                label: const Text('Add an attachment'),
              ),
              const SizedBox(height: 25),
              PrimaryButton(
                leave
                    ? 'Send leave request'
                    : submission
                    ? 'Submit completed work'
                    : worksheet
                    ? 'Share worksheet'
                    : widget.kind == FormKind.announcement
                    ? 'Publish announcement'
                    : 'Publish homework',
                icon: LucideIcons.arrowRight,
                onPressed: save,
                busy: busy,
              ),
              const SizedBox(height: 14),
              Text(
                'Nothing is submitted until your school account is ready and you confirm.',
                textAlign: TextAlign.center,
                style: textStyle(10, color: context.tones.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
