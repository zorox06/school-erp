part of '../screen.dart';

class ChildSelector extends StatelessWidget {
  const ChildSelector({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final selected = c.snapshot.children
        .where((e) => e.id == c.selectedChildId)
        .firstOrNull;
    return Surface(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      radius: 17,
      onTap: () => showChildSelector(context),
      child: Row(
        children: [
          const IconBadge(LucideIcons.userRound, size: 36),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected?.title ?? 'Your child’s school space',
                  style: textStyle(12, weight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  selected?.description ?? 'No child linked yet',
                  style: textStyle(10, color: context.tones.muted),
                ),
              ],
            ),
          ),
          Icon(LucideIcons.chevronDown, size: 17, color: context.tones.muted),
        ],
      ),
    );
  }
}

Future<void> showChildSelector(BuildContext context) {
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
              'Your children',
              style: textStyle(23, weight: FontWeight.w800),
            ),
            const SizedBox(height: 17),
            if (c.snapshot.children.isEmpty)
              EmptyPanel(
                icon: LucideIcons.heartHandshake,
                title: 'No child linked yet',
                message: 'Your school will securely link your child to this account. Please contact the school office if you need help.',
                compact: true,
              )
            else
              ...c.snapshot.children.map(
                (e) => RecordTile(
                  e,
                  icon: LucideIcons.userRound,
                  onTap: () {
                    c.chooseChild(e.id);
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
