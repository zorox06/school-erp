import '../../core/data.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/school_features.dart';
import '../../ui/components.dart';

class TimetableComposer extends StatefulWidget {
  const TimetableComposer({super.key});
  @override
  State<TimetableComposer> createState() => _TimetableState();
}

class _TimetableState extends State<TimetableComposer> {
  final title = TextEditingController(), details = TextEditingController();
  String? classroom, substitute;
  DateTime? date;
  List<SchoolRow> staff = [];
  bool busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final c = AppScope.of(context);
      if (!c.workspace.isLeadership || c.features == null) return;
      try {
        final raw = await c.features!.gateway.call('erp_staff', {
          'p_school': c.features!.school,
        }) as List;
        if (mounted) {
          setState(
            () => staff = raw
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
          );
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    title.dispose();
    details.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final c = AppScope.of(context);
    if (!c.canWrite ||
        c.features == null ||
        !c.workspace.isStaff ||
        classroom == null ||
        date == null ||
        title.text.trim().isEmpty) {
      tell(context, 'Choose your class, lesson title and date.');
      return;
    }
    setState(() => busy = true);
    try {
      await c.features!.queue('timetable_change', {
        'class_id': classroom,
        'title': title.text.trim(),
        'description': details.text.trim(),
        'date': date!.toUtc().toIso8601String(),
        'substitute_id': substitute,
      });
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) tell(context, 'Couldn’t save the timetable change.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return AppPage(
      title: 'A clearer teaching day.',
      eyebrow: 'Timetable & substitute update',
      children: [
        DropdownButtonFormField<String>(
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
          decoration: const InputDecoration(labelText: 'Lesson title'),
        ),
        TextField(
          controller: details,
          maxLength: 4000,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Change details'),
        ),
        OutlinedButton(
          onPressed: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime(now.year),
              lastDate: DateTime(now.year + 2),
            );
            if (d == null || !context.mounted) return;
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.now(),
            );
            if (t != null && mounted) {
              setState(
                () => date = DateTime(d.year, d.month, d.day, t.hour, t.minute),
              );
            }
          },
          child: Text(
            date == null
                ? 'Choose lesson date & time'
                : DateFormat('d MMM yyyy, h:mm a').format(date!),
          ),
        ),
        if (c.workspace.isLeadership)
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Substitute teacher (optional)',
            ),
            items: staff
                .map(
                  (e) => DropdownMenuItem(
                    value: e['id'] as String,
                    child: Text(e['name'] as String? ?? 'Teacher'),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => substitute = v),
          ),
        const SizedBox(height: 24),
        PrimaryButton('Publish schedule update', onPressed: save, busy: busy),
      ],
    );
  }
}
