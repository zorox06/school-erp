import 'leadership.dart';
import 'academics.dart';
import 'feed.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/data.dart';
import '../core/theme.dart';
import '../ui/components.dart';
import 'learning.dart';
import 'school.dart';

class DashboardScreen extends StatelessWidget {
  final ValueChanged<int> onNavigate;
  const DashboardScreen({super.key, required this.onNavigate});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final teacher = c.workspace.isStaff;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    final name = c.snapshot.displayName;
    final data = c.snapshot;
    final gap = c.compactView ? 14.0 : 22.0;
    final actions = teacher
        ? <(IconData, String, Color, Color, VoidCallback)>[
            (
              LucideIcons.clipboardCheck,
              'Attendance',
              Palette.teal,
              Palette.mint,
              () => openPage(context, const AttendanceScreen(teacher: true)),
            ),
            (
              LucideIcons.bookOpen,
              'Homework',
              Palette.blue,
              Palette.blueWash,
              () => onNavigate(2),
            ),
            (
              LucideIcons.users,
              'Classes',
              Palette.coral,
              Palette.coralWash,
              () => onNavigate(1),
            ),
            (
              LucideIcons.files,
              'Worksheets',
              Palette.amber,
              Palette.amberWash,
              () => openPage(
                context,
                const LearningPage(initial: 1, teacher: true),
              ),
            ),
            (
              LucideIcons.calendarDays,
              'Timetable',
              Palette.blue,
              Palette.blueWash,
              () => onNavigate(4),
            ),
            (
              LucideIcons.messageCircle,
              'Messages',
              Palette.teal,
              Palette.mint,
              () => onNavigate(3),
            ),
          ]
        : <(IconData, String, Color, Color, VoidCallback)>[
            (
              LucideIcons.bookOpen,
              'Homework',
              Palette.teal,
              Palette.mint,
              () => onNavigate(1),
            ),
            (
              LucideIcons.calendarDays,
              'Timetable',
              Palette.blue,
              Palette.blueWash,
              () => openPage(context, const LearningPage(initial: 2)),
            ),
            (
              LucideIcons.clipboardCheck,
              'Attendance',
              Palette.coral,
              Palette.coralWash,
              () => openPage(context, const AttendanceScreen()),
            ),
            (
              LucideIcons.wallet,
              'School fees',
              Palette.amber,
              Palette.amberWash,
              () => onNavigate(4),
            ),
            (
              LucideIcons.files,
              'Worksheets',
              Palette.blue,
              Palette.blueWash,
              () => openPage(context, const LearningPage(initial: 1)),
            ),
            (
              LucideIcons.messageCircle,
              'Messages',
              Palette.teal,
              Palette.mint,
              () => onNavigate(3),
            ),
          ];
    return ContentList(
      onRefresh: c.refresh,
      children: [
        ScreenHeading(
          name == null ? '$greeting.' : '$greeting, $name.',
          eyebrow:
              '${c.workspace.label} workspace · ${DateFormat('EEE, d MMM').format(DateTime.now())}',
          subtitle: teacher
              ? 'A little space for a great school day.'
              : 'The little things. All in one place.',
        ),
        if (c.workspace == Workspace.parent) ...[SizedBox(height: gap)],
        if (teacher) ...[
          PrimaryButton(
            'Mark attendance',
            icon: LucideIcons.clipboardCheck,
            onPressed: () =>
                openPage(context, const AttendanceScreen(teacher: true)),
          ),
          const SizedBox(height: 16),
        ],
        DaySummary(teacher: teacher),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: teacher ? LucideIcons.users : LucideIcons.bookOpen,
                label: teacher ? 'Your classes' : 'Homework',
                value: (teacher ? data.classes : data.homework).isEmpty
                    ? null
                    : '${(teacher ? data.classes : data.homework).length}',
                onTap: () => onNavigate(teacher ? 1 : 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: teacher
                    ? LucideIcons.clipboardCheck
                    : c.workspace == Workspace.student
                    ? LucideIcons.calendarDays
                    : LucideIcons.wallet,
                label: teacher
                    ? 'To review'
                    : c.workspace == Workspace.student
                    ? 'Timetable'
                    : 'Fees due',
                value: null,
                onTap: () => onNavigate(teacher ? 2 : 4),
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        if (c.workspace.isLeadership)
          PrimaryButton(
            'Principal overview',
            icon: LucideIcons.school,
            onPressed: () => openPage(context, const LeadershipScreen()),
          ),
        if (teacher)
          OutlinedButton.icon(
            onPressed: () => openPage(context, const AcademicsScreen()),
            icon: const Icon(LucideIcons.chartNoAxesCombined),
            label: const Text('Marks & exams'),
          ),

        const SectionHeading('Your daily essentials'),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 11,
            runSpacing: 11,
            children: actions
                .where(
                  (a) =>
                      c.workspace != Workspace.student || a.$2 != 'School fees',
                )
                .map(
                  (a) => SizedBox(
                    width: (box.maxWidth - 22) / 3,
                    child: Surface(
                      onTap: a.$5,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 16,
                      ),
                      radius: 18,
                      child: Column(
                        children: [
                          IconBadge(
                            a.$1,
                            color: a.$3,
                            background: a.$4,
                            size: 39,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            a.$2,
                            textAlign: TextAlign.center,
                            style: textStyle(10, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        SizedBox(height: gap),
        const WhatsNew(),
        if (c.timetableItems.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionHeading('Coming up today'),
          ...c.timetableItems
              .take(3)
              .map(
                (r) => RecordTile(
                  r,
                  icon: LucideIcons.calendarDays,
                  onTap: () => onNavigate(teacher ? 4 : 1),
                ),
              ),
        ],
        const SizedBox(height: 18),
        Center(
          child: Text(
            'A little closer to school. Every day.',
            style: textStyle(10, color: Palette.muted),
          ),
        ),
      ],
    );
  }
}

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
                  style: textStyle(10, color: Palette.muted),
                ),
              ],
            ),
          ),
          const Icon(LucideIcons.chevronDown, size: 17, color: Palette.muted),
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

class DaySummary extends StatelessWidget {
  final bool teacher;
  const DaySummary({super.key, required this.teacher});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(25),
    child: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Palette.teal, Palette.forest],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -32,
            top: -58,
            child: Container(
              width: 174,
              height: 174,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .1)),
              ),
            ),
          ),
          Positioned(
            right: 19,
            bottom: -12,
            child: Transform.rotate(
              angle: -.35,
              child: Icon(
                LucideIcons.sprout,
                size: 106,
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(23),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCE9B5),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        teacher
                            ? 'YOUR DAY, AT A GLANCE'
                            : 'SCHOOL & HOME, TOGETHER',
                        style: textStyle(
                          9,
                          weight: FontWeight.w800,
                          color: const Color(0xFFCAE3D6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  teacher
                      ? 'More room for\nbright ideas.'
                      : 'Every school day.\nA little simpler.',
                  style: textStyle(
                    25,
                    weight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  teacher
                      ? 'Your teaching day starts here.'
                      : 'Learning, updates and moments that matter.',
                  style: textStyle(11, color: const Color(0xFFD3E8DC)),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Surface(
    onTap: onTap,
    padding: const EdgeInsets.all(17),
    radius: 19,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              value ?? '—',
              style: textStyle(
                27,
                weight: FontWeight.w800,
                color: Palette.teal,
                height: 1.2,
              ),
            ),
            const Spacer(),
            Icon(icon, color: Palette.muted.withValues(alpha: .65), size: 18),
          ],
        ),
        const SizedBox(height: 7),
        Text(label, style: textStyle(11, color: Palette.muted)),
      ],
    ),
  );
}

class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});
  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final items = c.snapshot.classes
        .where(
          (e) => (e.title ?? '').toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return ContentList(
      onRefresh: c.refresh,
      children: [
        const ScreenHeading(
          'Your classes',
          eyebrow: 'Teacher workspace',
          subtitle: 'A place for every little mind.',
        ),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            hintText: 'Search your classes',
            prefixIcon: Icon(LucideIcons.search, size: 19),
          ),
        ),
        const SizedBox(height: 22),
        if (items.isEmpty)
          const EmptyPanel(
            icon: LucideIcons.users,
            title: 'Your classroom, coming soon.',
            message: 'Classes assigned to you by your school will appear here. There are no classes linked to this account yet.',
          )
        else
          ...items.map(
            (e) => RecordTile(
              e,
              icon: LucideIcons.users,
              onTap: () {
                c.chooseClass(e.id);
                openPage(context, ClassDetailScreen(record: e));
              },
            ),
          ),
        const SizedBox(height: 18),
        const InfoBanner(
          'Class access is managed by your school. Contact the office if an assignment is missing.',
        ),
      ],
    );
  }
}

class ClassDetailScreen extends StatelessWidget {
  final SchoolRecord record;
  const ClassDetailScreen({super.key, required this.record});
  @override
  Widget build(BuildContext context) => AppPage(
    title: record.title ?? 'Class',
    eyebrow: 'Your classroom',
    children: [
      const Tag('CLASS SPACE'),
      const SizedBox(height: 18),
      Surface(
        child: Column(
          children: [
            SettingRow(
              LucideIcons.clipboardCheck,
              'Mark attendance',
              onTap: () =>
                  openPage(context, const AttendanceScreen(teacher: true)),
            ),
            const Divider(),
            SettingRow(
              LucideIcons.bookOpen,
              'Class homework',
              onTap: () => openPage(context, const LearningPage(teacher: true)),
            ),
            const Divider(),
            SettingRow(
              LucideIcons.users,
              'Class register',
              onTap: () => openPage(context, const ClassRegisterScreen()),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text(
        record.description ?? '—',
        style: textStyle(13, color: Palette.muted),
      ),
    ],
  );
}

class ClassRegisterScreen extends StatelessWidget {
  const ClassRegisterScreen({super.key});
  @override
  Widget build(BuildContext context) => const AppPage(
    title: 'Class register',
    eyebrow: 'Your class',
    children: [
      EmptyPanel(
        icon: LucideIcons.users,
        title: 'No children to show yet',
        message: 'Your school will add children to this class. No names or student details have been added.',
      ),
    ],
  );
}
