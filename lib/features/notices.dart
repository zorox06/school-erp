import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/data.dart';
import '../core/phase_one/models.dart';
import '../core/theme.dart';
import '../ui/components.dart';
import 'attendance.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});
  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  String query = '';
  bool importantOnly = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).phaseOne?.loadNotices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = c.phaseOne;
    if (p == null) {
      return const ContentList(
        children: [
          ScreenHeading('Keep in the know.', eyebrow: 'School notices'),
          EmptyPanel(
            icon: LucideIcons.newspaper,
            title: 'No circulars yet',
            message: 'Your school’s notices will appear here once your account is connected.',
          ),
        ],
      );
    }
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final notices = p.notices
            .where(
              (n) =>
                  (!importantOnly || n.important) &&
                  '${n.title} ${n.body}'.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
            )
            .toList();
        return RefreshIndicator(
          onRefresh: p.loadNotices,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ScreenHeading(
                        'Keep in the know.',
                        eyebrow: 'School notices',
                        trailing: SyncBadge(controller: p),
                      ),
                      if (c.workspace.canPublishNotices)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => showPublishNotice(context),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Publish circular'),
                          ),
                        ),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search notices',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (v) => setState(() => query = v),
                      ),
                      const SizedBox(height: 10),
                      FilterTabs(
                        labels: const ['All notices', 'Important'],
                        selected: importantOnly ? 1 : 0,
                        onSelected: (v) =>
                            setState(() => importantOnly = v == 1),
                      ),
                      if (p.noticesLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      if (p.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            p.error!,
                            style: textStyle(12, color: Palette.muted),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (notices.isEmpty)
                const SliverPadding(
                  padding: EdgeInsets.all(22),
                  sliver: SliverToBoxAdapter(
                    child: EmptyPanel(
                      icon: LucideIcons.mailOpen,
                      title: 'Nothing to catch up on',
                      message: 'School circulars and important notices will appear here.',
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                sliver: SliverList.builder(
                  itemCount: notices.length,
                  itemBuilder: (context, index) {
                    final n = notices[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Surface(
                        onTap: () => showNoticeSheet(context, n),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (n.important) const Tag('IMPORTANT'),
                                if (n.acknowledged)
                                  const Tag('ACKNOWLEDGED')
                                else if (!n.read)
                                  const Tag('NEW'),
                              ],
                            ),
                            const SizedBox(height: 9),
                            Text(
                              n.title,
                              style: textStyle(16, weight: FontWeight.w800),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              n.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textStyle(13, color: Palette.muted),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              DateFormat('d MMM yyyy')
                                  .format(n.publishedAt.toLocal()),
                              style: textStyle(11, color: Palette.muted),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (p.hasMoreNotices)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: OutlinedButton(
                      onPressed: p.noticesLoading
                          ? null
                          : () => p.loadNotices(more: true),
                      child: const Text('Load more notices'),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }
}

Future<void> showNoticeSheet(BuildContext context, SchoolNotice notice) async {
  final p = AppScope.of(context).phaseOne;
  if (p == null) return;
  unawaited(
    p.readNotice(notice).catchError((Object _) {
      if (context.mounted) {
        tell(context, 'Couldn’t save the read receipt on this device.');
      }
    }),
  );
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .5,
      minChildSize: .3,
      maxChildSize: .9,
      snap: true,
      snapSizes: const [.5, .9],
      builder: (context, scroll) => ListenableBuilder(
        listenable: p,
        builder: (context, _) {
          final current =
              p.notices.where((n) => n.id == notice.id).firstOrNull ?? notice;
          return ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 36),
            children: [
              if (current.important)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Tag('IMPORTANT CIRCULAR'),
                ),
              const SizedBox(height: 12),
              Text(
                current.title,
                style: textStyle(24, weight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('d MMM yyyy').format(current.publishedAt.toLocal()),
                style: textStyle(12, color: Palette.muted),
              ),
              const SizedBox(height: 22),
              Text(current.body, style: textStyle(15, height: 1.7)),
              const SizedBox(height: 26),
              if (current.important)
                FilledButton.icon(
                  onPressed: current.acknowledged
                      ? null
                      : () async {
                          try {
                            await p.readNotice(current, acknowledge: true);
                          } catch (_) {
                            if (context.mounted) {
                              tell(
                                context,
                                'Couldn’t save the acknowledgement. Please retry.',
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.done_all),
                  label: Text(
                    current.acknowledged
                        ? 'Acknowledged on this device'
                        : 'Acknowledge',
                  ),
                ),
              if (current.important)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Offline acknowledgements sync when a connection is available.',
                    style: textStyle(11, color: Palette.muted),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

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
