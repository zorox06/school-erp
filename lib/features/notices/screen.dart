import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/phase_one/models.dart';
import '../../core/theme.dart';
import '../../ui/components.dart';
import '../attendance/screen.dart';

part 'widgets/notice_content.dart';
part 'widgets/publish.dart';

class NoticesScreen extends StatefulWidget {
  const NoticesScreen({super.key});
  @override
  State<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends State<NoticesScreen> {
  String query = '';
  String? selectedId;
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
        final wide = MediaQuery.sizeOf(context).width >= 950;
        final list = RefreshIndicator(
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
                            style: textStyle(12, color: context.tones.muted),
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
                        onTap: () async {
                          if (!wide) {
                            await showNoticeSheet(context, n);
                            return;
                          }
                          setState(() => selectedId = n.id);
                          try {
                            await p.readNotice(n);
                          } catch (_) {
                            if (context.mounted) {
                              tell(context, 'Could not save read receipt.');
                            }
                          }
                        },
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
                              style: textStyle(13, color: context.tones.muted),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              DateFormat('d MMM yyyy')
                                  .format(n.publishedAt.toLocal()),
                              style: textStyle(11, color: context.tones.muted),
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
        if (!wide) return list;
        final selected = notices.where((n) => n.id == selectedId).firstOrNull;
        return Row(
          children: [
            SizedBox(width: 330, child: list),
            const VerticalDivider(width: 1),
            Expanded(
              child: selected == null
                  ? const Center(child: Text('Select a circular'))
                  : NoticeContent(notice: selected),
            ),
          ],
        );
      },
    );
  }
}
