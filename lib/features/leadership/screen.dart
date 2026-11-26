import '../workspace/pulse.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/school_features.dart';
import '../../ui/components.dart';
import '../../ui/daybook.dart';

part 'widgets/leave_decision.dart';
part 'widgets/emergency.dart';
part 'widgets/audit.dart';
part 'widgets/staff_register.dart';

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
        'p_day': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
      if (mounted) {
        setState(() {
          summary = Map<String, dynamic>.from(r as Map);
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Summary unavailable. Use refresh to retry.');
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
      title: 'School office',
      eyebrow: '',
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null) InfoBanner(error!),
        PulseOverview(summary: summary, onRefresh: load),
        const SizedBox(height: 18),
        const SectionHeading('Daily register'),
        if (summary['attendance_percent'] != null)
          Text(
            "${summary['attendance_percent']}% attendance among recorded students",
          ),
        DaybookRow(
          icon: LucideIcons.users,
          title: 'Teacher attendance',
          detail:
              '${summary['staff_recorded'] ?? '—'} / ${summary['staff_total'] ?? '—'}',
          onTap: () => openPage(context, const StaffAttendanceScreen()),
        ),
        for (final a in summary['absent_teachers'] as List? ?? [])
          Text('${a['name'] ?? 'Teacher'} · ${a['status']}'),
        DaybookRow(
          icon: LucideIcons.history,
          title: 'Audit history',
          onTap: () => openPage(context, const AuditScreen()),
        ),
        DaybookRow(
          icon: LucideIcons.siren,
          title: 'Emergency broadcast',
          onTap: () => openPage(context, const EmergencyScreen()),
        ),
        const SizedBox(height: 24),
        Text('Leave requests', style: textStyle(22, weight: FontWeight.w800)),
        if (summary['pending_leave'] != null)
          Text(
            '${summary['pending_leave']} pending',
            style: textStyle(12, color: context.tones.muted),
          ),
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
