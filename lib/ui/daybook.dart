import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/data.dart';
import '../core/theme.dart';
import 'components.dart';

const _ink = Palette.ink;

TextStyle folioType(double size, {Color color = _ink}) => TextStyle(
  fontFamily: 'Manrope',
  fontSize: size,
  height: 1.04,
  color: color,
  fontWeight: FontWeight.w700,
);

class DaybookWeek extends StatelessWidget {
  const DaybookWeek({
    super.key,
    required this.week,
    required this.selected,
    required this.onSelect,
  });
  final List<DateTime> week;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final index = week.indexOf(selected);
    final duration = schoolMotion(context, 480, 180);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: context.tones.forest,
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            child: AnimatedSwitcher(
              duration: duration,
              child: Align(
                key: ValueKey(selected),
                alignment: Alignment.centerLeft,
                child: Text(
                  DateFormat('EEEE, d MMMM').format(selected),
                  style: textStyle(
                    25,
                    color: Colors.white,
                    weight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          Material(
            color: context.tones.forest,
            child: LayoutBuilder(
              builder: (context, box) {
                final cell = box.maxWidth / 7;
                return Stack(
                  children: [
                    AnimatedPositioned(
                      key: const Key('daybook-week-marker'),
                      duration: duration,
                      curve: Curves.easeOutQuart,
                      left: index * cell + 2,
                      width: cell - 4,
                      top: 5,
                      bottom: 5,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xffd2eee1),
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final d in week)
                          Expanded(
                            child: Semantics(
                              button: true,
                              selected: selected == d,
                              label: DateFormat('EEEE, d MMMM').format(d),
                              child: InkWell(
                                key: ValueKey('daybook-weekday-${d.weekday}'),
                                onTap: () => onSelect(d),
                                child: ExcludeSemantics(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          DateFormat('E').format(d),
                                          style: textStyle(
                                            10,
                                            color: d == selected
                                                ? _ink
                                                : Colors.white,
                                            weight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${d.day}',
                                          style: textStyle(
                                            15,
                                            color: d == selected
                                                ? _ink
                                                : Colors.white,
                                            weight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class DaybookAgenda extends StatelessWidget {
  const DaybookAgenda({
    super.key,
    required this.day,
    required this.today,
    required this.lessons,
    required this.ready,
    required this.open,
  });
  final DateTime day, today;
  final List<SchoolRecord> lessons;
  final bool ready;
  final VoidCallback open;

  @override
  Widget build(BuildContext context) {
    final duration = schoolMotion(context, 365, 140);
    final dateLabel = DateUtils.isSameDay(day, today)
        ? 'Today'
        : DateFormat('EEEE').format(day);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
          child: Row(
            children: [
              Icon(LucideIcons.clock3, size: 19, color: context.tones.teal),
              const SizedBox(width: 13),
              Expanded(
                child: AnimatedSize(
                  duration: duration,
                  alignment: Alignment.topLeft,
                  child: AnimatedSwitcher(
                    duration: duration,
                    layoutBuilder: (child, old) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...old, ?child],
                    ),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(.08, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey(day),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$dateLabel’s timetable',
                          style: textStyle(14, weight: FontWeight.w800),
                        ),
                        if (lessons.isEmpty)
                          Text(
                            ready
                                ? 'No lessons scheduled'
                                : 'Timetable unavailable',
                            style: textStyle(12, color: Palette.muted),
                          )
                        else
                          for (final lesson in lessons.take(2))
                            Text(
                              '${DateFormat('HH:mm').format(lesson.date!.toLocal())}   ${lesson.title ?? 'Lesson'}',
                              style: textStyle(12, color: Palette.muted),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                LucideIcons.arrowUpRight,
                size: 18,
                color: context.tones.teal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DaybookRow extends StatelessWidget {
  const DaybookRow({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? detail;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Palette.line)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 3),
          child: Row(
            children: [
              Icon(icon, size: 19, color: context.tones.teal),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  title,
                  style: textStyle(14, weight: FontWeight.w700),
                ),
              ),
              if (detail != null)
                Padding(
                  padding: const EdgeInsets.only(right: 9),
                  child: Text(
                    detail!,
                    style: textStyle(13, color: Palette.muted),
                  ),
                ),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Palette.muted,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
