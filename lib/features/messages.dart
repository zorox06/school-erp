import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/data.dart';
import '../core/school_features.dart';
import '../core/theme.dart';
import '../ui/components.dart';
import '../ui/quick_sheet.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesState();
}

class _MessagesState extends State<MessagesScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final records = (c.features?.rows('conversations') ?? <SchoolRow>[])
        .where(
          (r) => '${r['contact_name'] ?? ''} ${r['student_name'] ?? ''}'
              .toLowerCase()
              .contains(query.toLowerCase()),
        )
        .toList();
    return RefreshIndicator(
      onRefresh: () => c.features?.refresh() ?? c.refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(22),
            sliver: SliverList.list(
              children: [
                ScreenHeading(
                  'A conversation away.',
                  eyebrow: 'Your inbox',
                  subtitle: 'A private connection between home and school.',
                  trailing: IconButton(
                    tooltip: 'New conversation',
                    onPressed: () =>
                        openPage(context, const ComposeMessageScreen()),
                    icon: const Icon(LucideIcons.squarePen),
                  ),
                ),
                TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    hintText: 'Search conversations',
                    prefixIcon: Icon(LucideIcons.search),
                  ),
                ),
                const SizedBox(height: 20),
                if (records.isEmpty)
                  const EmptyPanel(
                    icon: LucideIcons.messagesSquare,
                    title: 'Good conversations start here.',
                    message: 'Approved school conversations will appear here.',
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            sliver: SliverList.builder(
              itemCount: records.length,
              itemBuilder: (context, i) {
                final r = records[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Surface(
                    onTap: () => openPage(
                      context,
                      ConversationScreen(
                        record: SchoolRecord(
                          id: r['id'] as String,
                          title: r['contact_name'] as String?,
                          fields: r,
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const IconBadge(LucideIcons.messageCircle),
                      title: Text(
                        r['contact_name'] as String? ?? 'School conversation',
                      ),
                      subtitle: Text(r['student_name'] as String? ?? ''),
                      trailing: (r['unread_count'] as num? ?? 0) > 0
                          ? const Badge()
                          : const Icon(LucideIcons.chevronRight, size: 18),
                    ),
                  ),
                );
              },
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                if (c.features?.hasMore['conversations'] == true)
                  TextButton(
                    onPressed: c.features!.moreConversations,
                    child: const Text('Load more conversations'),
                  ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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

class ConversationScreen extends StatefulWidget {
  final SchoolRecord record;
  const ConversationScreen({super.key, required this.record});
  @override
  State<ConversationScreen> createState() => _ConversationState();
}

class _ConversationState extends State<ConversationScreen>
    with WidgetsBindingObserver {
  final body = TextEditingController();
  List<SchoolRow> rows = [];
  Timer? timer;
  bool loading = false, sending = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      load();
      start();
    });
  }

  void start() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 20), (_) => load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    timer?.cancel();
    if (state == AppLifecycleState.resumed) {
      load();
      start();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    body.dispose();
    super.dispose();
  }

  bool allowed(AppController c) =>
      c.workspace.isStaff ||
      widget.record.fields['student_id'] == c.selectedChildId;
  Future<void> load({bool earlier = false}) async {
    if (!mounted || loading) return;
    final c = AppScope.of(context);
    final h = c.features;
    if (h == null || !allowed(c)) return;
    setState(() => loading = true);
    final id = widget.record.id;
    try {
      final cached = await h.store.cached(h.scope, 'messages/$id');
      cached.sort(
        (a, b) =>
            (a['created_at'] as String).compareTo(b['created_at'] as String),
      );
      if (mounted) setState(() => rows = cached);
      final r = await h.messages(
        id,
        after: earlier ? h.messageCursor(id) : null,
      );
      if (mounted && allowed(c)) setState(() => rows = r);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> send() async {
    final c = AppScope.of(context);
    final text = body.text.trim();
    if (text.isEmpty || c.features == null || !allowed(c)) return;
    setState(() => sending = true);
    try {
      await c.features!.sendMessage(widget.record.id, text);
      body.clear();
      await load();
    } catch (_) {
      if (mounted) tell(context, 'Couldn’t save the message. Try again.');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    if (!allowed(c)) {
      return const AppPage(
        title: 'Child changed',
        eyebrow: 'Messages',
        children: [InfoBanner('Return to the inbox for the selected child.')],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(widget.record.title ?? 'Conversation')),
      body: SafeArea(
        child: Column(
          children: [
            if (loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: rows.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return c
                                .features
                                ?.hasMore['messages/${widget.record.id}'] ==
                            true
                        ? TextButton(
                            onPressed: () => load(earlier: true),
                            child: const Text('Earlier messages'),
                          )
                        : const SizedBox.shrink();
                  }
                  final r = rows[i - 1];
                  final mine = r['sender_id'] == c.auth.userId;
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * .8,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: mine ? Palette.mint : Palette.paper,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['body'] as String? ?? ''),
                          const SizedBox(height: 5),
                          Text(
                            r['_pending'] == true
                                ? 'Pending sync'
                                : DateTime.tryParse(
                                            r['created_at'] as String? ?? '',
                                          )
                                          ?.toLocal()
                                          .toString()
                                          .substring(0, 16) ??
                                      '',
                            style: textStyle(10, color: Palette.muted),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: body,
                      maxLength: 4000,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Write a message',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: sending ? null : send,
                    icon: const Icon(LucideIcons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
