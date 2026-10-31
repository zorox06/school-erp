import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/data.dart';
import '../core/school_features.dart';
import '../ui/components.dart';

class LeadershipScreen extends StatefulWidget {
  const LeadershipScreen({super.key});
  @override
  State<LeadershipScreen> createState() => _LeadershipState();
}

class _LeadershipState extends State<LeadershipScreen> {
  SchoolRow summary = {};
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final h = AppScope.of(context).features;
    if (h == null) return;
    setState(() => busy = true);
    try {
      final r = await h.gateway.call('erp_principal_summary', {
        'p_school': h.school,
      });
      if (mounted) {
        setState(() {
          summary = Map<String, dynamic>.from(r as Map);
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Summary unavailable. Pull to retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    if (!c.workspace.isLeadership) return const SizedBox.shrink();
    final leaves = c.features?.rows('leaves') ?? <SchoolRow>[];
    return AppPage(
      title: 'A school in focus.',
      eyebrow: 'Principal overview',
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null) InfoBanner(error!),
        TextButton.icon(
          onPressed: load,
          icon: const Icon(LucideIcons.refreshCw),
          label: const Text('Refresh daily summary'),
        ),
        Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${summary['attendance_percent'] ?? '—'}${summary['attendance_percent'] == null ? '' : '%'}',
                style: textStyle(40, weight: FontWeight.w800),
              ),
              const Text('Attendance among recorded students'),
              Text(
                'Coverage: ${summary['coverage_percent'] ?? '—'}% · ${summary['recorded_students'] ?? '—'} / ${summary['total_students'] ?? '—'} recorded',
              ),
              const SizedBox(height: 15),
              Text('Pending leave: ${summary['pending_leave'] ?? '—'}'),
              Text(
                'Teacher registers: ${summary['staff_recorded'] ?? '—'} / ${summary['staff_total'] ?? '—'}',
              ),
              for (final a in summary['absent_teachers'] as List? ?? [])
                Text('${a['name'] ?? 'Teacher'} · ${a['status']}'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => openPage(context, const EmergencyScreen()),
              icon: const Icon(LucideIcons.siren),
              label: const Text('Emergency broadcast'),
            ),
            OutlinedButton.icon(
              onPressed: () => openPage(context, const AuditScreen()),
              icon: const Icon(LucideIcons.history),
              label: const Text('Audit history'),
            ),
            OutlinedButton.icon(
              onPressed: () => openPage(context, const StaffAttendanceScreen()),
              icon: const Icon(LucideIcons.users),
              label: const Text('Teacher attendance'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeading('Leave requests'),
        const SizedBox(height: 12),
        if (leaves.isEmpty)
          const EmptyPanel(
            icon: LucideIcons.calendarCheck,
            title: 'No leave requests',
            message: 'Requests appear when submitted by a linked parent.',
          ),
        ...leaves.map((l) => LeaveDecisionTile(leave: l)),
      ],
    );
  }
}

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

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});
  @override
  State<EmergencyScreen> createState() => _EmergencyState();
}

class _EmergencyState extends State<EmergencyScreen> {
  final title = TextEditingController(), body = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    title.dispose();
    body.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final c = AppScope.of(context);
    if (!c.workspace.isLeadership ||
        !c.canWrite ||
        c.features == null ||
        title.text.trim().isEmpty ||
        body.text.trim().isEmpty) {
      tell(context, 'A leadership account, title and message are required.');
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Broadcast to the whole school?'),
        content: Text('${title.text.trim()}\n\n${body.text.trim()}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Broadcast'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() => busy = true);
    try {
      await c.features!.queue('emergency', {
        'title': title.text.trim(),
        'body': body.text.trim(),
      });
      if (mounted) {
        tell(
          context,
          'Broadcast queued. Delivery requires configured and permitted device alerts.',
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) tell(context, 'Couldn’t save the broadcast.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Reach the whole school.',
    eyebrow: 'Emergency broadcast',
    children: [
      const InfoBanner(
        'Use for urgent school safety information. Emergency alerts bypass app quiet hours, subject to each device’s permissions.',
      ),
      const SizedBox(height: 20),
      TextField(
        controller: title,
        maxLength: 140,
        decoration: const InputDecoration(labelText: 'Alert title'),
      ),
      TextField(
        controller: body,
        maxLength: 8000,
        minLines: 5,
        maxLines: 12,
        decoration: const InputDecoration(labelText: 'Clear instructions'),
      ),
      const SizedBox(height: 20),
      PrimaryButton(
        'Review emergency broadcast',
        icon: LucideIcons.siren,
        onPressed: send,
        busy: busy,
      ),
    ],
  );
}

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});
  @override
  State<AuditScreen> createState() => _AuditState();
}

class _AuditState extends State<AuditScreen> {
  final rows = <SchoolRow>[];
  bool busy = false, more = true;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final c = AppScope.of(context);
    final h = c.features;
    if (h == null || busy || !c.workspace.isLeadership) return;
    setState(() => busy = true);
    try {
      final result = await h.gateway.call('erp_audit_page', {
        'p_school': h.school,
        'p_before': rows.lastOrNull?['id'],
        'p_limit': 40,
      }) as List;
      if (mounted) {
        setState(() {
          rows.addAll(result.map((e) => Map<String, dynamic>.from(e as Map)));
          more = result.length == 40;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Audit history could not be loaded.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Audit history')),
    body: ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == rows.length) {
          return Column(
            children: [
              if (error != null) InfoBanner(error!),
              if (rows.isEmpty && !busy)
                const EmptyPanel(
                  icon: LucideIcons.history,
                  title: 'No edits recorded',
                  message: 'Attendance and grade changes retain actor, time and before/after values.',
                ),
              if (more)
                TextButton(
                  onPressed: busy ? null : load,
                  child: Text(busy ? 'Loading…' : 'Load more'),
                ),
            ],
          );
        }
        final r = rows[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['action'] as String? ?? 'School edit',
                  style: textStyle(16, weight: FontWeight.w800),
                ),
                Text('${r['actor_name'] ?? r['actor']} · ${r['at']}'),
                Text(
                  'Before: ${r['before_value'] ?? '—'}',
                  style: textStyle(12),
                ),
                Text('After: ${r['after_value'] ?? '—'}', style: textStyle(12)),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({super.key});
  @override
  State<StaffAttendanceScreen> createState() => _StaffState();
}

class _StaffState extends State<StaffAttendanceScreen> {
  List<SchoolRow> staff = [];
  bool busy = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final h = AppScope.of(context).features;
      try {
        final r = h == null
            ? []
            : await h.gateway.call('erp_staff', {'p_school': h.school}) as List;
        if (mounted) {
          setState(
            () => staff = r
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
          );
        }
      } catch (_) {
        if (mounted) tell(context, 'Teacher list could not be loaded.');
      } finally {
        if (mounted) setState(() => busy = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = AppScope.of(context).features;
    return AppPage(
      title: 'The teaching team.',
      eyebrow: 'Today’s teacher attendance',
      children: [
        if (busy) const LinearProgressIndicator(),
        if (staff.isEmpty && !busy)
          const InfoBanner('No teachers linked to this school.'),
        ...staff.map(
          (s) => ListTile(
            title: Text(s['name'] as String? ?? 'Teacher'),
            subtitle: Text(DateFormat('d MMM yyyy').format(DateTime.now())),
            trailing: PopupMenuButton<String>(
              tooltip: 'Record teacher attendance',
              onSelected: (v) async {
                await h?.queue('staff_attendance', {
                  'user_id': s['id'],
                  'day': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  'status': v,
                });
                if (context.mounted) {
                  tell(context, 'Teacher attendance queued.');
                }
              },
              itemBuilder: (_) => [
                'present',
                'absent',
                'leave',
              ].map((v) => PopupMenuItem(value: v, child: Text(v))).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
