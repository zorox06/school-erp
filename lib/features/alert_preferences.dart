import 'package:flutter/material.dart';

import '../core/data.dart';
import '../ui/components.dart';

class AlertPreferencesScreen extends StatelessWidget {
  const AlertPreferencesScreen({super.key});
  Future<void> time(BuildContext context, String key, int fallback) async {
    final h = AppScope.of(context).features;
    if (h == null) return;
    final minutes = h.preferences[key] as int? ?? fallback;
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (value != null) {
      await h.savePreferences({key: value.hour * 60 + value.minute});
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final h = c.features;
    final p = h?.preferences ?? <String, dynamic>{};
    final categories = Map<String, dynamic>.from(p['categories'] as Map? ?? {});
    String clock(String key, int fallback) {
      final m = p[key] as int? ?? fallback;
      return '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
    }

    return AppPage(
      title: 'Updates, on your terms.',
      eyebrow: 'Alert preferences',
      children: [
        const InfoBanner(
          'Urgent alerts use a separate device channel. Emergency delivery still depends on device permission and operating system settings.',
        ),
        SwitchListTile(
          title: const Text('Device notifications'),
          value: c.notificationsEnabled,
          onChanged: c.notificationsBusy
              ? null
              : (v) async {
                  await c.setNotifications(v);
                  await h?.savePreferences({'enabled': c.notificationsEnabled});
                },
        ),
        for (final entry in {
          'absence': 'Absence alerts',
          'emergency': 'School emergencies',
          'notice': 'Notices & circulars',
          'homework': 'Homework & worksheets',
          'message': 'Private messages',
          'timetable': 'Timetable changes',
          'leave': 'Leave requests',
        }.entries)
          SwitchListTile(
            title: Text(entry.value),
            value: categories[entry.key] != false,
            onChanged: h == null
                ? null
                : (v) => h.savePreferences({
                    'categories': {...categories, entry.key: v},
                  }),
          ),
        const Divider(),
        SwitchListTile(
          title: const Text('Quiet hours'),
          subtitle: Text('Times use ${h?.timezone ?? 'your device timezone'}'),
          value: p['quiet_enabled'] == true,
          onChanged: h == null
              ? null
              : (v) => h.savePreferences({'quiet_enabled': v}),
        ),
        ListTile(
          title: const Text('Quiet hours start'),
          trailing: Text(clock('quiet_start', 1200)),
          onTap: () => time(context, 'quiet_start', 1200),
        ),
        ListTile(
          title: const Text('Quiet hours end'),
          trailing: Text(clock('quiet_end', 420)),
          onTap: () => time(context, 'quiet_end', 420),
        ),
        if (c.workspace.isStaff) ...[
          const Divider(),
          SwitchListTile(
            title: const Text('Teacher messaging quiet hours'),
            value: p['teacher_quiet_enabled'] == true,
            onChanged: h == null
                ? null
                : (v) => h.savePreferences({'teacher_quiet_enabled': v}),
          ),
          ListTile(
            title: const Text('Teacher quiet hours start'),
            trailing: Text(clock('teacher_quiet_start', 1080)),
            onTap: () => time(context, 'teacher_quiet_start', 1080),
          ),
          ListTile(
            title: const Text('Teacher quiet hours end'),
            trailing: Text(clock('teacher_quiet_end', 480)),
            onTap: () => time(context, 'teacher_quiet_end', 480),
          ),
        ],
      ],
    );
  }
}
