import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/media.dart';
import '../../core/theme.dart';
import '../../ui/components.dart';
import '../../ui/quick_sheet.dart';
import '../academics/screen.dart';
import '../auth/screen.dart';
import '../dashboard/screen.dart';
import '../homework/screen.dart';
import '../leadership/screen.dart';
import '../learning/screen.dart';
import '../leave/screen.dart';
import '../messages/screen.dart';
import '../notices/screen.dart';
import '../payments/screen.dart';
import '../report_card/screen.dart';
import '../scanner/screen.dart';
import '../school/screen.dart';
import 'pulse.dart';

enum SchoolDestination {
  today('Today', LucideIcons.calendarDays),
  classes('Classes', LucideIcons.users),
  inbox('Inbox', LucideIcons.inbox),
  marks('Marks', LucideIcons.chartNoAxesCombined),
  pulse('Pulse', LucideIcons.activity),
  campus('Campus', LucideIcons.school),
  comms('Comms', LucideIcons.messagesSquare),
  people('People', LucideIcons.contact),
  learning('Learning', LucideIcons.bookOpen),
  school('School', LucideIcons.school);

  const SchoolDestination(this.name, this.icon);
  final String name;
  final IconData icon;
}

List<SchoolDestination> schoolWorkspaces(Workspace role) => switch (role) {
  Workspace.teacher => const [
    SchoolDestination.today,
    SchoolDestination.classes,
    SchoolDestination.inbox,
    SchoolDestination.marks,
  ],
  Workspace.admin || Workspace.principal => const [
    SchoolDestination.pulse,
    SchoolDestination.campus,
    SchoolDestination.comms,
    SchoolDestination.people,
  ],
  _ => const [
    SchoolDestination.today,
    SchoolDestination.learning,
    SchoolDestination.school,
    SchoolDestination.inbox,
  ],
};

class WorkspaceBody extends StatefulWidget {
  const WorkspaceBody({super.key, required this.destination});
  final SchoolDestination destination;
  @override
  State<WorkspaceBody> createState() => _WorkspaceBodyState();
}

class _WorkspaceBodyState extends State<WorkspaceBody> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final role = AppScope.of(context).workspace;
    final sections = <(String, Widget)>[
      ...switch (widget.destination) {
        SchoolDestination.today => const [('Agenda', DashboardScreen())],
        SchoolDestination.pulse => const [('Pulse', LeadershipScreen())],
        SchoolDestination.classes => const [
          ('Roster', ClassesScreen()),
          ('Attendance', AttendanceScreen(teacher: true)),
          ('Homework', LearningScreen(teacher: true)),
          ('Submissions', ReviewSubmissionsScreen()),
        ],
        SchoolDestination.campus => const [
          ('Classes', ClassesScreen()),
          ('Timetable', ScheduleScreen()),
          ('Audit', AuditScreen()),
          ('Learning', LearningScreen(teacher: true)),
          ('Marks', AcademicsScreen()),
        ],
        SchoolDestination.people => const [
          ('Staff', StaffAttendanceScreen()),
          ('Leave', LeaveInboxScreen()),
          ('Attendance', AttendanceScreen(teacher: true)),
        ],
        SchoolDestination.comms => const [
          ('Circulars', NoticesScreen()),
          ('Inbox', MessagesScreen()),
        ],
        SchoolDestination.inbox => const [('Inbox', MessagesScreen())],
        SchoolDestination.marks => const [('Marks', AcademicsScreen())],
        SchoolDestination.learning => const [
          ('Homework', LearningScreen()),
          ('Exams', AcademicsScreen()),
        ],
        SchoolDestination.school => [
          ('Circulars', const SchoolScreen()),
          ('Attendance', const AttendanceScreen()),
          ('Leave', const LeaveInboxScreen()),
          if (role == Workspace.parent) ('Fees', const PaymentsScreen()),
        ],
      },
    ];
    if (sections.length == 1) return sections.first.$2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          child: Text(
            widget.destination.name,
            style: textStyle(28, weight: FontWeight.w800),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Row(
            children: [
              for (final (index, item) in sections.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    showCheckmark: false,
                    label: Text(item.$1),
                    selected: selected == index,
                    onSelected: (_) => setState(() => selected = index),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(selected),
            child: sections[selected].$2,
          ),
        ),
      ],
    );
  }
}

Future<void> showWorkspaceActions(BuildContext context) async {
  final c = AppScope.of(context);
  Future<void> page(Widget child) async {
    await openPage(context, child);
  }

  Future<void> scan({required bool teaching}) async {
    final owner = c.auth.userId;
    if (owner == null || !c.canWrite) {
      tell(context, 'Connect your school account to attach a scan.');
      return;
    }
    SchoolRecord? assignment;
    if (!teaching) {
      final homework = c.learningItems(false);
      if (homework.isEmpty) {
        tell(context, 'There is no assignment to attach a scan to.');
        return;
      }
      assignment = await quickSheet<SchoolRecord>(
        context,
        (sheet, scroll) => ListView(
          controller: scroll,
          children: [
            const ListTile(title: Text('Choose homework')),
            for (final r in homework)
              ListTile(
                title: Text(r.title ?? 'Homework'),
                onTap: () => Navigator.pop(sheet, r),
              ),
          ],
        ),
      );
      if (assignment == null || !context.mounted) return;
    }
    final childId = c.selectedChildId;
    final file = await openPage<LocalAttachment>(
      context,
      DocumentScannerScreen(owner: owner),
    );
    if (file == null ||
        !context.mounted ||
        owner != c.auth.userId ||
        childId != c.selectedChildId) {
      return;
    }
    if (teaching) {
      await page(HomeworkComposer(worksheet: true, initialFile: file));
    } else {
      await showSubmissionSheet(context, assignment!, initialFile: file);
    }
  }

  final actions = <(String, IconData, VoidCallback)>[
    if (c.workspace.isLeadership) ...[
      (
        'Emergency broadcast',
        LucideIcons.siren,
        () => page(const EmergencyScreen()),
      ),
      (
        'Assign substitute',
        LucideIcons.calendarClock,
        () => choosePeriod(context),
      ),
      (
        'Approve leave',
        LucideIcons.calendarCheck,
        () => page(const LeaveInboxScreen()),
      ),
    ] else if (c.workspace == Workspace.teacher) ...[
      (
        'Take attendance',
        LucideIcons.clipboardCheck,
        () => page(const AttendanceScreen(teacher: true)),
      ),
      (
        'Assign homework',
        LucideIcons.bookOpen,
        () => page(const HomeworkComposer()),
      ),
      ('Scan sheet', LucideIcons.scanLine, () => scan(teaching: true)),
    ] else if (c.workspace == Workspace.parent) ...[
      (
        'Apply for leave',
        LucideIcons.calendarDays,
        () => showLeaveRequest(context),
      ),
      (
        'Message teacher',
        LucideIcons.messageCircle,
        () => page(const ComposeMessageScreen()),
      ),
      ('Switch child', LucideIcons.users, () => showChildSelector(context)),
      ('Report card', LucideIcons.fileText, () => showReportCard(context)),
    ] else ...[
      ('Scan homework PDF', LucideIcons.scanLine, () => scan(teaching: false)),
      (
        'View exam countdown',
        LucideIcons.calendarDays,
        () => page(const AcademicsScreen()),
      ),
    ],
    if (c.snapshot.platformOwner)
      (
        'Platform admin',
        LucideIcons.externalLink,
        () => openPlatformAdmin(context),
      ),
  ];
  final selected = await quickSheet<int>(
    context,
    (sheet, scroll) => ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Text(
            'Quick actions',
            style: textStyle(23, weight: FontWeight.w800),
          ),
        ),
        for (final (i, a) in actions.indexed)
          ListTile(
            leading: Icon(a.$2, color: context.tones.teal),
            title: Text(a.$1),
            onTap: () => Navigator.pop(sheet, i),
          ),
      ],
    ),
  );
  if (selected != null && context.mounted) actions[selected].$3();
}
