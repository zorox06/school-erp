part of '../screen.dart';

class ComposeMessageScreen extends StatefulWidget {
  const ComposeMessageScreen({super.key});
  @override
  State<ComposeMessageScreen> createState() => _ComposeState();
}

class _ComposeState extends State<ComposeMessageScreen> {
  final body = TextEditingController();
  SchoolRow? contact;
  bool busy = false;
  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  Future<void> findFamily() async {
    final c = AppScope.of(context);
    final h = c.features;
    final p = c.phaseOne;
    if (h == null || p == null) return;
    final classId = await quickSheet<String>(
      context,
      (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(22),
        children: [
          const Text('Choose a class'),
          ...c.snapshot.classes.map(
            (e) => ListTile(
              title: Text(e.title ?? 'Class'),
              onTap: () => Navigator.pop(context, e.id),
            ),
          ),
        ],
      ),
    );
    if (classId == null || !mounted) return;
    await p.loadRoster(classId);
    if (!mounted) return;
    String q = '';
    final student = await quickSheet<String>(
      context,
      (context, scroll) => StatefulBuilder(
        builder: (context, update) {
          final students = p.students
              .where(
                (s) =>
                    s.classId == classId &&
                    s.name.toLowerCase().contains(q.toLowerCase()),
              )
              .toList();
          return CustomScrollView(
            controller: scroll,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search student',
                    ),
                    onChanged: (v) => update(() => q = v),
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: students.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(students[i].name),
                  onTap: () => Navigator.pop(context, students[i].id),
                ),
              ),
            ],
          );
        },
      ),
    );
    if (student == null || !mounted) return;
    try {
      final raw = await h.gateway.call('erp_contacts', {
        'p_school': h.school,
        'p_child': student,
      }) as List;
      if (!mounted) return;
      final contact = await quickSheet<SchoolRow>(
        context,
        (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(22),
          children: [
            if (raw.isEmpty)
              const Text('No approved family contacts for this student.'),
            ...raw.map((e) {
              final r = Map<String, dynamic>.from(e as Map);
              return ListTile(
                title: Text(r['name'] as String? ?? 'Family contact'),
                subtitle: Text(r['student_name'] as String? ?? ''),
                onTap: () => Navigator.pop(context, r),
              );
            }),
          ],
        ),
      );
      if (contact != null && mounted) setState(() => this.contact = contact);
    } catch (_) {
      if (mounted) {
        tell(
          context,
          'Couldn’t load approved contacts. Please retry when connected.',
        );
      }
    }
  }

  Future<void> choose() async {
    final contacts =
        AppScope.of(context).features?.rows('contacts') ?? <SchoolRow>[];
    String q = '';
    final chosen = await quickSheet<SchoolRow>(
      context,
      (context, scroll) => StatefulBuilder(
        builder: (context, update) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              'Choose a school contact',
              style: textStyle(23, weight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search name or child',
              ),
              onChanged: (v) => update(() => q = v),
            ),
            if (contacts.isEmpty)
              const EmptyPanel(
                icon: LucideIcons.contactRound,
                title: 'No contacts linked yet',
                message: 'Your school will link the right staff and family contacts.',
              ),
            ...contacts
                .where(
                  (r) => '${r['name']} ${r['student_name']}'
                      .toLowerCase()
                      .contains(q.toLowerCase()),
                )
                .map(
                  (r) => ListTile(
                    title: Text(r['name'] as String? ?? 'School contact'),
                    subtitle: Text(r['student_name'] as String? ?? ''),
                    onTap: () => Navigator.pop(context, r),
                  ),
                ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) setState(() => contact = chosen);
  }

  Future<void> send() async {
    final c = AppScope.of(context);
    if (!c.canWrite ||
        c.features == null ||
        contact == null ||
        body.text.trim().isEmpty) {
      tell(context, 'Choose an approved contact and write a message.');
      return;
    }
    setState(() => busy = true);
    try {
      await c.features!.queue('message', {
        'student_id': contact!['student_id'],
        'contact_id': contact!['id'],
        'body': body.text.trim(),
      });
      if (mounted) {
        tell(context, 'Message saved. It will send when connected.');
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        tell(context, 'Couldn’t save your message. Your text is still here.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return AppPage(
      title: 'Keep in touch.',
      eyebrow: 'New conversation',
      children: [
        if (c.workspace.isStaff)
          TextButton(
            onPressed: findFamily,
            child: const Text('Find a student’s family'),
          ),
        Surface(
          onTap: choose,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(contact?['name'] as String? ?? 'Choose a recipient'),
            subtitle: Text(
              contact?['student_name'] as String? ?? 'School approved contacts',
            ),
            trailing: const Icon(LucideIcons.chevronDown),
          ),
        ),
        const SizedBox(height: 20),
        if (contact?['teacher_quiet_enabled'] == true)
          const InfoBanner(
            'This teacher has quiet hours. Messages are saved immediately; alerts may arrive during school hours.',
          ),
        if (c.workspace.isStaff)
          Wrap(
            spacing: 8,
            children:
                [
                      'Thank you for the update. I will follow up during school hours.',
                      'Please review the latest homework when you have a moment.',
                      'Could we arrange a time to discuss your child’s progress?',
                    ]
                    .map(
                      (t) => ActionChip(
                        label: Text(
                          t.startsWith('Thank')
                              ? 'Thank you'
                              : t.startsWith('Please')
                              ? 'Homework'
                              : 'Meeting',
                        ),
                        onPressed: () => setState(() => body.text = t),
                      ),
                    )
                    .toList(),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: body,
          minLines: 6,
          maxLines: 12,
          maxLength: 4000,
          decoration: const InputDecoration(
            hintText: 'Write a thoughtful note…',
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          'Send message',
          icon: LucideIcons.send,
          onPressed: send,
          busy: busy,
        ),
      ],
    );
  }
}
