import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/data.dart';
import '../ui/components.dart';
import '../ui/quick_sheet.dart';
import 'leadership.dart';

Future<void> showLeaveRequest(BuildContext context) =>
    quickSheet<void>(context, (context, scroll) => _LeaveSheet(scroll: scroll));

class _LeaveSheet extends StatefulWidget {
  final ScrollController scroll;
  const _LeaveSheet({required this.scroll});
  @override
  State<_LeaveSheet> createState() => _LeaveState();
}

class _LeaveState extends State<_LeaveSheet> {
  final reason = TextEditingController();
  DateTimeRange? dates;
  bool busy = false;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final c = AppScope.of(context);
    if (!c.canWrite ||
        c.workspace != Workspace.parent ||
        c.features == null ||
        c.selectedChildId == null ||
        dates == null ||
        reason.text.trim().isEmpty) {
      tell(context, 'Select a linked child, leave dates and a reason.');
      return;
    }
    setState(() => busy = true);
    try {
      final p = <String, dynamic>{
        'student_id': c.selectedChildId,
        'starts_on': DateFormat('yyyy-MM-dd').format(dates!.start),
        'ends_on': DateFormat('yyyy-MM-dd').format(dates!.end),
        'reason': reason.text.trim(),
      };
      await c.features!.queue(
        'leave',
        p,
        collection: 'leaves',
        optimistic: {...p, 'status': 'pending', 'version': 1},
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        tell(context, 'Couldn’t save your request. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    controller: widget.scroll,
    padding: EdgeInsets.fromLTRB(
      24,
      10,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    children: [
      Text(
        'A little time away.',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        icon: const Icon(LucideIcons.calendarDays),
        label: Text(
          dates == null
              ? 'Choose leave dates'
              : '${DateFormat('d MMM').format(dates!.start)} – ${DateFormat('d MMM').format(dates!.end)}',
        ),
        onPressed: () async {
          final now = DateUtils.dateOnly(DateTime.now());
          final r = await showDateRangePicker(
            context: context,
            firstDate: now,
            lastDate: DateTime(now.year + 2),
            initialDateRange: dates,
          );
          if (r != null && mounted) setState(() => dates = r);
        },
      ),
      const SizedBox(height: 16),
      TextField(
        controller: reason,
        maxLength: 2000,
        minLines: 3,
        maxLines: 6,
        decoration: const InputDecoration(labelText: 'Reason for leave'),
      ),
      const SizedBox(height: 18),
      PrimaryButton('Request leave', onPressed: save, busy: busy),
    ],
  );
}

class LeaveInboxScreen extends StatelessWidget {
  const LeaveInboxScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final leaves = c.features?.rows('leaves') ?? [];
    return AppPage(
      title: 'A little time away.',
      eyebrow: 'Leave requests',
      children: [
        if (leaves.isEmpty)
          const EmptyPanel(
            icon: LucideIcons.calendarDays,
            title: 'No leave requests',
            message: 'Linked family requests will appear here.',
          ),
        ...leaves.map(
          (l) => c.workspace.isStaff
              ? LeaveDecisionTile(leave: l)
              : ListTile(
                  title: Text('${l['starts_on']} – ${l['ends_on']}'),
                  subtitle: Text(l['reason'] as String? ?? ''),
                  trailing: Text(l['status'] as String? ?? 'pending'),
                ),
        ),
      ],
    );
  }
}
