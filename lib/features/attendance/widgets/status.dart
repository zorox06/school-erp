part of '../screen.dart';

String _label(String value) => '${value[0].toUpperCase()}${value.substring(1)}';

class SyncBadge extends StatelessWidget {
  final PhaseOneController controller;
  final bool compact;
  const SyncBadge({super.key, required this.controller, this.compact = false});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final p = controller;

      final (state, label) = p.blockedCount > 0
          ? (RecordSyncState.conflict, 'Needs review · ${p.blockedCount}')
          : p.busy
          ? (RecordSyncState.syncing, 'Syncing')
          : p.pendingCount > 0
          ? (
              RecordSyncState.queued,
              'Saved locally · ${p.pendingCount} pending',
            )
          : p.status == SyncStatus.offline
          ? (RecordSyncState.offline, 'Offline')
          : (RecordSyncState.synced, 'Synced');
      return Tooltip(
        message: '$label. Tap to sync.',
        child: InkWell(
          onTap: p.busy ? null : () => p.sync(retryBlocked: true),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SyncPill(
              state,
              compact && p.pendingCount > 0 && state == RecordSyncState.queued
                  ? '${p.pendingCount} pending'
                  : label,
            ),
          ),
        ),
      );
    },
  );
}
