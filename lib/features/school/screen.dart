import '../leave/screen.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../ui/components.dart';
import '../learning/screen.dart';
import '../attendance/screen.dart';
import '../notices/screen.dart';
import '../../core/phase_one/models.dart';

part 'widgets/attendance.dart';

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
              color: tab == 0 ? context.tones.teal : context.tones.coral,
              background: tab == 0
                  ? context.tones.mint
                  : context.tones.coralWash,
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
                        style: textStyle(
                          12,
                          color: context.tones.muted,
                          height: 1.7,
                        ),
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
