part of '../screen.dart';

Future<void> showPublishNotice(BuildContext context) async {
  final c = AppScope.of(context);
  if (!c.workspace.canPublishNotices || c.phaseOne == null) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _PublishNoticeSheet(),
  );
}

class _PublishNoticeSheet extends StatefulWidget {
  const _PublishNoticeSheet();
  @override
  State<_PublishNoticeSheet> createState() => _PublishNoticeSheetState();
}

class _PublishNoticeSheetState extends State<_PublishNoticeSheet> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(), body = TextEditingController();
  bool important = false, busy = false;
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'A note for your school.',
              style: textStyle(23, weight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: title,
              maxLength: 140,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a notice title' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: body,
              minLines: 4,
              maxLines: 8,
              maxLength: 8000,
              decoration: const InputDecoration(labelText: 'Circular'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter your circular' : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Require acknowledgement'),
              value: important,
              onChanged: busy ? null : (v) => setState(() => important = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setState(() => busy = true);
                      try {
                        await AppScope.of(context).phaseOne!.publish(
                          title.text.trim(),
                          body.text.trim(),
                          important,
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        if (context.mounted) {
                          tell(
                            context,
                            'Circular wasn’t published. Check your connection and school access.',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: Text(busy ? 'Publishing…' : 'Publish circular'),
            ),
          ],
        ),
      ),
    ),
  );
}
