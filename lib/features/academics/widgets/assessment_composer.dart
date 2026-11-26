part of '../screen.dart';

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
