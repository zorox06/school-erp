part of '../screen.dart';

class TimetableDayPage extends StatelessWidget {
  const TimetableDayPage({super.key, required this.day, required this.teacher});
  final DateTime day;
  final bool teacher;
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'Timetable',
    eyebrow: '',
    children: [
      if (teacher)
        OutlinedButton(
          onPressed: () => openPage(context, const TimetableComposer()),
          child: const Text('Update timetable / substitute'),
        ),
      TimetableContent(initialDay: day),
    ],
  );
}

class TimetableContent extends StatefulWidget {
  const TimetableContent({super.key, this.initialDay});
  final DateTime? initialDay;
  @override
  State<TimetableContent> createState() => _TimetableContentState();
}

class _TimetableContentState extends State<TimetableContent> {
  late DateTime selected = DateUtils.dateOnly(
    widget.initialDay ?? DateTime.now(),
  );
  late DateTime week = selected.subtract(Duration(days: selected.weekday - 1));
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final entries = c.timetableItems
        .where(
          (e) =>
              e.date == null ||
              DateUtils.isSameDay(e.date?.toLocal(), selected),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('MMMM yyyy').format(selected),
                style: textStyle(17, weight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Previous week',
              onPressed: () => setState(() {
                week = week.subtract(const Duration(days: 7));
                selected = week;
              }),
              icon: const Icon(LucideIcons.chevronLeft, size: 19),
            ),
            IconButton(
              tooltip: 'Next week',
              onPressed: () => setState(() {
                week = week.add(const Duration(days: 7));
                selected = week;
              }),
              icon: const Icon(LucideIcons.chevronRight, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List.generate(7, (i) {
            final day = week.add(Duration(days: i));
            final active = DateUtils.isSameDay(day, selected);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Material(
                  color: active ? context.tones.teal : context.tones.paper,
                  borderRadius: BorderRadius.circular(13),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() => selected = day),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('EEEEE').format(day),
                            style: textStyle(
                              9,
                              color: active
                                  ? Colors.white70
                                  : context.tones.muted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${day.day}',
                            style: textStyle(
                              14,
                              weight: FontWeight.w800,
                              color: active ? Colors.white : context.tones.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        Text(
          DateFormat('EEEE, d MMMM').format(selected),
          style: textStyle(13, weight: FontWeight.w700),
        ),
        const SizedBox(height: 15),
        if (entries.isEmpty)
          EmptyPanel(
            icon: LucideIcons.calendarDays,
            title: 'A little room in the day.',
            message: 'No timetable has been shared for this day. Your classes and periods will appear here when they are available.',
            color: context.tones.blue,
            background: context.tones.blueWash,
          )
        else
          ...entries.map(
            (e) => RecordTile(
              e,
              icon: LucideIcons.clock,
              onTap: () => openPage(
                context,
                RecordDetailScreen(record: e, section: 'Timetable'),
              ),
            ),
          ),
      ],
    );
  }
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  Widget build(BuildContext context) => ContentList(
    onRefresh: AppScope.of(context).refresh,
    children: [
      if (AppScope.of(context).workspace.isStaff)
        OutlinedButton(
          onPressed: () => openPage(context, const TimetableComposer()),
          child: const Text('Update timetable / substitute'),
        ),
      const ScreenHeading(
        'Your teaching day.',
        eyebrow: 'Timetable',
        subtitle: 'A clear view of what’s ahead.',
      ),
      const TimetableContent(),
    ],
  );
}
