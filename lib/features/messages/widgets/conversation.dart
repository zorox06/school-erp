part of '../screen.dart';

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
                        color: mine ? context.tones.mint : context.tones.paper,
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
                            style: textStyle(10, color: context.tones.muted),
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
