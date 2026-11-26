part of '../screen.dart';

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
      builder: (context, scroll) =>
          NoticeContent(notice: notice, scroll: scroll),
    ),
  );
}

class NoticeContent extends StatelessWidget {
  const NoticeContent({super.key, required this.notice, this.scroll});
  final SchoolNotice notice;
  final ScrollController? scroll;
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).phaseOne;
    if (p == null) return const SizedBox.shrink();
    return ListenableBuilder(
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
            Text(current.title, style: textStyle(24, weight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              DateFormat('d MMM yyyy').format(current.publishedAt.toLocal()),
              style: textStyle(12, color: context.tones.muted),
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
                  style: textStyle(11, color: context.tones.muted),
                ),
              ),
          ],
        );
      },
    );
  }
}
