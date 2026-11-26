part of '../screen.dart';

class LeaveDecisionTile extends StatefulWidget {
  final SchoolRow leave;
  const LeaveDecisionTile({super.key, required this.leave});
  @override
  State<LeaveDecisionTile> createState() => _LeaveDecisionState();
}

class _LeaveDecisionState extends State<LeaveDecisionTile> {
  bool busy = false;
  Future<void> decide(String value) async {
    final h = AppScope.of(context).features;
    if (h == null || busy) return;
    setState(() => busy = true);
    try {
      await h.queue(
        'leave_decision',
        {
          'leave_id': widget.leave['id'],
          'status': value,
          'expected_version': widget.leave['version'] ?? 1,
        },
        collection: 'leaves',
        key: widget.leave['id'] as String,
        optimistic: {...widget.leave, 'status': value},
      );
      if (mounted) {
        tell(
          context,
          'Decision saved. School permissions are checked again when syncing.',
        );
      }
    } catch (_) {
      if (mounted) tell(context, 'Couldn’t save the decision.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.leave;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l['student_name'] as String? ?? 'Leave request',
              style: textStyle(16, weight: FontWeight.w800),
            ),
            Text('${l['starts_on']} – ${l['ends_on']}'),
            Text(l['reason'] as String? ?? ''),
            const SizedBox(height: 12),
            if (l['status'] == 'pending')
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : () => decide('approved'),
                    icon: const Icon(LucideIcons.check, size: 18),
                    label: const Text('Approve'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : () => decide('denied'),
                    child: const Text('Decline'),
                  ),
                ],
              )
            else
              Tag(
                '${l['status']}${l['_pending'] == true ? ' · Pending sync' : ''}',
              ),
          ],
        ),
      ),
    );
  }
}
