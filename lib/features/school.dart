import 'leave.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme.dart';
import '../ui/components.dart';
import 'learning.dart';
import 'attendance.dart';
import 'notices.dart';
import '../core/phase_one/models.dart';

class SchoolScreen extends StatefulWidget {
  const SchoolScreen({super.key});
  @override
  State<SchoolScreen> createState() => _SchoolScreenState();
}

class _SchoolScreenState extends State<SchoolScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final items = tab == 0 ? c.snapshot.news : c.snapshot.events;
    if (tab == 0) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
            child: FilterTabs(
              labels: const ['Notices', 'Events', 'Attendance'],
              selected: tab,
              onSelected: (v) => setState(() => tab = v),
            ),
          ),
          const Expanded(child: NoticesScreen()),
        ],
      );
    }
    return ContentList(
      onRefresh: c.refresh,
      children: [
        const ScreenHeading(
          'Around the school.',
          eyebrow: 'Your school community',
          subtitle: 'The moments that bring us together.',
        ),
        FilterTabs(
          labels: const ['Notices', 'Events', 'Attendance'],
          selected: tab,
          onSelected: (v) => setState(() => tab = v),
        ),
        const SizedBox(height: 25),
        if (tab == 2)
          const AttendanceContent()
        else ...[
          if (items.isEmpty)
            EmptyPanel(
              icon: tab == 0
                  ? LucideIcons.newspaper
                  : LucideIcons.calendarHeart,
              title: tab == 0
                  ? 'Good stories are on their way.'
                  : 'Something to look forward to.',
              message: tab == 0
                  ? 'News, celebrations and school circulars will find a home here. No updates have been shared yet.'
                  : 'School events and important dates will appear here when they are announced.',
              color: tab == 0 ? Palette.teal : Palette.coral,
              background: tab == 0 ? Palette.mint : Palette.coralWash,
            )
          else
            ...items.map(
              (e) => RecordTile(
                e,
                icon: tab == 0
                    ? LucideIcons.newspaper
                    : LucideIcons.calendarHeart,
                onTap: () => openPage(
                  context,
                  RecordDetailScreen(
                    record: e,
                    section: tab == 0 ? 'School news' : 'School event',
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          const SectionHeading('Stay in the loop'),
          const SizedBox(height: 13),
          Surface(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const IconBadge(LucideIcons.bellRing, size: 40),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'School days, less guesswork.',
                        style: textStyle(13, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Important announcements will always be available here, even if you miss a notification.',
                        style: textStyle(12, color: Palette.muted, height: 1.7),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class AttendanceScreen extends StatelessWidget {
  final bool teacher;
  const AttendanceScreen({super.key, this.teacher = false});
  @override
  Widget build(BuildContext context) => teacher
      ? const FastAttendanceScreen()
      : AppPage(
          title: teacher ? 'Who’s here today?' : 'Every day counts.',
          eyebrow: teacher ? 'Class attendance' : 'Attendance',
          children: [AttendanceContent(teacher: teacher)],
        );
}

class AttendanceContent extends StatefulWidget {
  final bool teacher;
  const AttendanceContent({super.key, this.teacher = false});
  @override
  State<AttendanceContent> createState() => _AttendanceContentState();
}

class _AttendanceContentState extends State<AttendanceContent> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final p = AppScope.of(context).phaseOne;
    return p == null
        ? _content(context)
        : ListenableBuilder(
            listenable: p,
            builder: (context, _) => _content(context),
          );
  }

  Widget _content(BuildContext context) {
    final c = AppScope.of(context);
    final records =
        c.phaseOne?.entries.values
            .where(
              (e) =>
                  e.studentId == c.selectedChildId &&
                  e.day.startsWith(DateFormat('yyyy-MM').format(month)),
            )
            .toList() ??
        [];
    final record = c
        .phaseOne
        ?.entries['${c.selectedChildId}/${DateFormat('yyyy-MM-dd').format(selected)}'];
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = (month.weekday - 1) % 7;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.teacher) ...[
          Surface(
            onTap: () => _classPicker(context),
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                const IconBadge(LucideIcons.users, size: 35),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    c.snapshot.classes
                            .where((e) => e.id == c.selectedClassId)
                            .firstOrNull
                            ?.title ??
                        'Choose a class',
                    style: textStyle(13, weight: FontWeight.w700),
                  ),
                ),
                const Icon(LucideIcons.chevronDown, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        Row(
          children: ['Present', 'Absent', 'Recorded']
              .map(
                (label) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: label == 'Recorded' ? 0 : 9,
                    ),
                    child: Surface(
                      radius: 17,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 15,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            records.isEmpty
                                ? '—'
                                : '${label == 'Recorded' ? records.length : records.where((e) => e.status == (label == 'Present' ? AttendanceStatus.present : AttendanceStatus.absent)).length}',
                            style: textStyle(
                              25,
                              weight: FontWeight.w800,
                              color: Palette.teal,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: textStyle(9, color: Palette.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 23),
        Surface(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy').format(month),
                      style: textStyle(15, weight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Previous month',
                    onPressed: () => setState(
                      () => month = DateTime(month.year, month.month - 1),
                    ),
                    icon: const Icon(LucideIcons.chevronLeft, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    onPressed: () => setState(
                      () => month = DateTime(month.year, month.month + 1),
                    ),
                    icon: const Icon(LucideIcons.chevronRight, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map(
                      (e) => Expanded(
                        child: Center(
                          child: Text(
                            e,
                            style: textStyle(
                              10,
                              color: Palette.muted,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 3,
                  childAspectRatio: 1.08,
                ),
                itemCount: ((days + offset) / 7).ceil() * 7,
                itemBuilder: (context, i) {
                  final d = i - offset + 1;
                  if (d < 1 || d > days) return const SizedBox();
                  final date = DateTime(month.year, month.month, d);
                  final active = DateUtils.isSameDay(date, selected);
                  return Semantics(
                    label: DateFormat('EEEE d MMMM').format(date),
                    selected: active,
                    child: Material(
                      color: active ? Palette.teal : Palette.background,
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => setState(() => selected = date),
                        child: Center(
                          child: Text(
                            '$d',
                            style: textStyle(
                              11,
                              weight: active
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: active ? Colors.white : Palette.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 13),
              Text(
                'Select a day to view its attendance record.',
                style: textStyle(10, color: Palette.muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (record != null)
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.status.name.toUpperCase(),
                  style: textStyle(19, weight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat('d MMMM yyyy').format(selected),
                  style: textStyle(13, color: Palette.muted),
                ),
                if (record.reason != null)
                  Text('Reason: ${record.reason!.name}', style: textStyle(13)),
              ],
            ),
          )
        else
          EmptyPanel(
            icon: LucideIcons.clipboardCheck,
            title: widget.teacher
                ? 'Ready when your class is.'
                : 'No attendance recorded yet',
            message: widget.teacher
                ? 'Your class register will appear once your school assigns a class. No attendance has been marked.'
                : 'There is no attendance information for ${DateFormat('d MMMM').format(selected)}. Your school’s records will appear here.',
            compact: true,
          ),
        const SizedBox(height: 20),
        if (!widget.teacher)
          OutlinedButton.icon(
            onPressed: () => showLeaveRequest(context),
            icon: const Icon(LucideIcons.calendarMinus, size: 17),
            label: const Text('Request leave'),
          )
        else
          PrimaryButton(
            'Select class to mark attendance',
            icon: LucideIcons.users,
            onPressed: () => _classPicker(context),
          ),
      ],
    );
  }

  Future<void> _classPicker(BuildContext context) {
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
                'Choose your class',
                style: textStyle(23, weight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              if (c.snapshot.classes.isEmpty)
                const EmptyPanel(
                  icon: LucideIcons.users,
                  title: 'No classes linked yet',
                  message: 'Ask your school to assign your class. You’ll be able to mark attendance once your register is available.',
                  compact: true,
                )
              else
                ...c.snapshot.classes.map(
                  (e) => RecordTile(
                    e,
                    icon: LucideIcons.users,
                    onTap: () {
                      c.chooseClass(e.id);
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
}
