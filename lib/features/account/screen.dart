import '../leave/screen.dart';
import '../report_card/screen.dart';
import '../alert_preferences/screen.dart';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../ui/components.dart';
import '../learning/screen.dart';
import '../notices/screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final teacher = c.workspace.isStaff;
    return AppPage(
      title: 'Your own little space.',
      eyebrow: 'Account & preferences',
      children: [
        Surface(
          child: Row(
            children: [
              const IconBadge(LucideIcons.userRound, size: 59),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.snapshot.displayName ?? 'Your account',
                      style: textStyle(18, weight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      c.auth.email ?? '—',
                      style: textStyle(11, color: context.tones.muted),
                    ),
                    const SizedBox(height: 9),
                    Tag(c.workspace.name.toUpperCase()),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        if (!teacher)
          TextButton.icon(
            onPressed: () => showReportCard(context),
            icon: const Icon(LucideIcons.fingerprint),
            label: const Text('Private report card'),
          ),
        TextButton.icon(
          onPressed: () => openPage(context, const LeaveInboxScreen()),
          icon: const Icon(LucideIcons.calendarDays),
          label: const Text('Leave requests'),
        ),
        const SectionHeading('School details'),
        const SizedBox(height: 10),
        Surface(
          child: Column(
            children: [
              _detail(context, 'School', c.snapshot.schoolName),
              const Divider(height: 28),
              _detail(context, 'Academic year', null),
              const Divider(height: 28),
              _detail(
                context,
                teacher ? 'Assigned class' : 'Linked child',
                null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        const SectionHeading('Make it yours'),
        TextButton.icon(
          onPressed: () => openPage(context, const AlertPreferencesScreen()),
          icon: const Icon(LucideIcons.bell),
          label: const Text('Alert categories & quiet hours'),
        ),
        const SizedBox(height: 10),
        Surface(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 5),
          child: Column(
            children: [
              SettingRow(
                LucideIcons.bell,
                'School alerts',
                subtitle:
                    c.pushStatus ??
                    'Enable urgent alerts and school circulars on this device',
                trailing: Switch.adaptive(
                  value: c.notificationsEnabled,
                  onChanged: c.notificationsBusy ? null : c.setNotifications,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Data saver'),
                subtitle: const Text(
                  'Reduce motion and load images only on request',
                ),
                value: c.dataSaver,
                onChanged: c.setDataSaver,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Home screen widgets'),
                subtitle: const Text(
                  'Show timetable and homework outside the app',
                ),
                value: c.widgetEnabled,
                onChanged: c.setWidgets,
              ),
              const Divider(height: 1),
              SettingRow(
                LucideIcons.rows3,
                'Compact home',
                subtitle: 'A little less space between sections',
                trailing: Switch.adaptive(
                  value: c.compactView,
                  onChanged: c.setCompactView,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Surface(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 4),
          child: Column(
            children: [
              SettingRow(
                LucideIcons.newspaper,
                'School circulars',
                onTap: () => openPage(
                  context,
                  Scaffold(
                    appBar: AppBar(title: const Text('School circulars')),
                    body: const SafeArea(child: NoticesScreen()),
                  ),
                ),
              ),
              const Divider(height: 1),
              if (teacher) ...[
                SettingRow(
                  LucideIcons.megaphone,
                  'Publish school circular',
                  onTap: () {
                    if (c.phaseOne == null) {
                      tell(
                        context,
                        'Sign in with a school staff account to publish a circular.',
                      );
                      return;
                    }
                    showPublishNotice(context);
                  },
                ),
                const Divider(height: 1),
              ],
              SettingRow(
                LucideIcons.circleHelp,
                'Help & support',
                onTap: () => openPage(context, const HelpScreen()),
              ),
              const Divider(height: 1),
              SettingRow(
                LucideIcons.shieldCheck,
                'Privacy & your data',
                onTap: () => openPage(context, const PrivacyScreen()),
              ),
              const Divider(height: 1),
              SettingRow(
                LucideIcons.sprout,
                'About Schoolday',
                onTap: () => openPage(context, const AboutScreen()),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            final navigator = Navigator.of(context);
            try {
              await c.leave();
              navigator.popUntil((r) => r.isFirst);
            } catch (_) {
              if (context.mounted) {
                tell(
                  context,
                  'We couldn’t sign you out. Please check your connection and try again.',
                );
              }
            }
          },
          icon: const Icon(LucideIcons.logOut, size: 17),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 23),
        Center(
          child: Text(
            'schoolday · 1.0.0',
            style: textStyle(10, color: context.tones.muted),
          ),
        ),
      ],
    );
  }

  Widget _detail(BuildContext context, String label, String? value) => Row(
    children: [
      Expanded(
        child: Text(label, style: textStyle(12, color: context.tones.muted)),
      ),
      Expanded(
        child: Text(
          value ?? '—',
          textAlign: TextAlign.end,
          style: textStyle(13, weight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return AppPage(
      title: 'The little things that matter.',
      eyebrow: 'Notifications',
      children: [
        if (c.snapshot.notifications.isEmpty)
          const EmptyPanel(
            icon: LucideIcons.bell,
            title: 'A quiet moment.',
            message: 'Homework reminders, school updates and important messages will appear here. There are no notifications yet.',
          )
        else
          ...c.snapshot.notifications.map(
            (e) => RecordTile(
              e,
              icon: LucideIcons.bell,
              onTap: () => openPage(
                context,
                RecordDetailScreen(record: e, section: 'School update'),
              ),
            ),
          ),
      ],
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) => const AppPage(
    title: 'A helping hand.',
    eyebrow: 'Help & support',
    children: [
      EmptyPanel(
        icon: LucideIcons.heartHandshake,
        title: 'Your school is here to help.',
        message: 'For account access, child links, class assignments or fee questions, please contact your school office. Use the office contact details provided by your school.',
      ),
      SizedBox(height: 22),
      _HelpCard(
        'Can’t see your child?',
        'Your school needs to securely link your child to your account. Ask the office to check your registered email address.',
      ),
      SizedBox(height: 12),
      _HelpCard(
        'Missing a class?',
        'Class assignments are managed by your school. A teacher can access only the classes they have been assigned.',
      ),
      SizedBox(height: 12),
      _HelpCard(
        'Need to change your password?',
        'Use “Forgot password?” on the sign-in screen to request a reset link for your school account.',
      ),
    ],
  );
}

class _HelpCard extends StatelessWidget {
  final String title, body;
  const _HelpCard(this.title, this.body);
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textStyle(14, weight: FontWeight.w800)),
        const SizedBox(height: 9),
        Text(
          body,
          style: textStyle(12, color: context.tones.muted, height: 1.7),
        ),
      ],
    ),
  );
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => const AppPage(
    title: 'A space built on trust.',
    eyebrow: 'Privacy & your data',
    children: [
      IconBadge(LucideIcons.shieldCheck, size: 58),
      SizedBox(height: 22),
      _HelpCard(
        'Your family’s information',
        'Parents should see only their linked children. School access and teacher permissions are managed by your school.',
      ),
      SizedBox(height: 12),
      _HelpCard(
        'When you sign in',
        'Your account email and authentication session are processed by the configured account service. Your school assigns account access. The app caches records and queued changes on this device for offline use.',
      ),
      SizedBox(height: 12),
      _HelpCard(
        'Homework attachments',
        'When you publish or submit work, the app uploads selected files to private school storage. Offline submissions wait for a connection.',
      ),
      SizedBox(height: 12),
      _HelpCard(
        'Questions or requests',
        'Your school is responsible for its privacy policy, account provisioning and records. Please contact the office for access, corrections or deletion requests.',
      ),
    ],
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: 'A little closer, every day.',
    eyebrow: 'About Schoolday',
    children: [
      const SizedBox(height: 12),
      const Brand(large: true),
      const SizedBox(height: 25),
      Text(
        'Good school days grow from good connections.',
        style: textStyle(25, weight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
      Text(
        'Schoolday brings learning, communication and the everyday details of school life into one thoughtful place for parents and teachers.',
        style: textStyle(14, color: context.tones.muted, height: 1.8),
      ),
      const SizedBox(height: 25),

      const SizedBox(height: 23),
      TextButton(
        onPressed: () => showLicensePage(
          context: context,
          applicationName: 'Schoolday',
          applicationLegalese: 'Built with Flutter. Manrope font licensed under the SIL Open Font License.',
        ),
        child: const Text('Open-source licenses'),
      ),
    ],
  );
}
