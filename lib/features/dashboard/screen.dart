import '../feed/screen.dart';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../ui/components.dart';
import '../../ui/daybook.dart';
import '../learning/screen.dart';
import '../school/screen.dart';

part 'widgets/child_selector.dart';
part 'widgets/classes.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime? chosenDay;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final staff = c.workspace.isStaff;
    final today = DateUtils.dateOnly(DateTime.now());
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final week = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
    final day = week.contains(chosenDay) ? chosenDay! : today;
    final lessons =
        c.timetableItems
            .where((r) => DateUtils.isSameDay(r.date?.toLocal(), day))
            .toList()
          ..sort((a, b) => a.date!.compareTo(b.date!));
    final ready = c.snapshot.schoolId != null;
    return ContentList(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 30),
      onRefresh: c.refresh,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(1, 3, 1, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  'Today',
                  style: textStyle(32, weight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        c.snapshot.schoolName ?? 'Schoolday',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: textStyle(13, weight: FontWeight.w800),
                      ),
                      Text(
                        c.workspace.label,
                        style: textStyle(11, color: context.tones.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        DaybookWeek(
          week: week,
          selected: day,
          onSelect: (date) => setState(() => chosenDay = date),
        ),
        const SizedBox(height: 16),
        if (staff)
          DaybookAgenda(
            day: day,
            today: today,
            lessons: lessons,
            ready: ready,
            open: () =>
                openPage(context, TimetableDayPage(day: day, teacher: staff)),
          ),
        const SizedBox(height: 18),
        WhatsNew(day: day),
      ],
    );
  }
}
