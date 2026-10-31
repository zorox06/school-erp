import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'core/data.dart';
import 'core/theme.dart';
import 'ui/components.dart';
import 'features/auth.dart';
import 'features/dashboard.dart';
import 'features/learning.dart';
import 'features/school.dart';
import 'features/messages.dart';
import 'features/payments.dart';
import 'features/account.dart';
import 'features/notices.dart';
import 'features/attendance.dart';

class SchooldayApp extends StatelessWidget {
  final AppController controller;
  final GlobalKey<NavigatorState>? navigatorKey;
  const SchooldayApp({super.key, required this.controller, this.navigatorKey});
  @override
  Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: MaterialApp(
      title: 'Schoolday',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: schooldayTheme(),
      builder: (context, child) {
        final c = AppScope.of(context);
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations: c.dataSaver || media.disableAnimations,
          ),
          child: child!,
        );
      },
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) =>
            controller.entered && !controller.accessAssigned
            ? Scaffold(
                appBar: AppBar(title: const Text('Schoolday')),
                body: ContentList(
                  children: [
                    const ScreenHeading(
                      'Your account is signed in.',
                      eyebrow: 'School access',
                    ),
                    const EmptyPanel(
                      icon: LucideIcons.shieldCheck,
                      title: 'Waiting for school access',
                      message: 'Your school must assign your account a role and link its records. You cannot choose your own permissions.',
                    ),
                    OutlinedButton(
                      onPressed: controller.refresh,
                      child: const Text('Check school access'),
                    ),
                    TextButton(
                      onPressed: controller.leave,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              )
            : controller.entered
            ? MainShell(
                key: ValueKey(
                  '${controller.preview}-${controller.workspace.name}',
                ),
              )
            : const LoginScreen(),
      ),
    ),
  );
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final teacher = c.workspace.isStaff;
    final student = c.workspace == Workspace.student;
    final leadership = c.workspace.isLeadership;
    final labels = teacher
        ? [
            'Today',
            'Classes',
            leadership ? 'Notices' : 'Homework',
            'Inbox',
            'Schedule',
          ]
        : [
            'Home',
            'Learning',
            'School',
            'Inbox',
            student ? 'Schedule' : 'Fees',
          ];
    final icons = teacher
        ? [
            LucideIcons.house,
            LucideIcons.users,
            leadership ? LucideIcons.newspaper : LucideIcons.bookOpen,
            LucideIcons.messageCircle,
            LucideIcons.calendarDays,
          ]
        : [
            LucideIcons.house,
            LucideIcons.bookOpen,
            LucideIcons.school,
            LucideIcons.messageCircle,
            student ? LucideIcons.calendarDays : LucideIcons.wallet,
          ];
    final screens = <Widget>[
      DashboardScreen(onNavigate: (i) => setState(() => _index = i)),
      teacher ? const ClassesScreen() : const LearningScreen(),
      leadership
          ? const NoticesScreen()
          : teacher
          ? const LearningScreen(teacher: true)
          : const SchoolScreen(),
      const MessagesScreen(),
      teacher || student ? const ScheduleScreen() : const PaymentsScreen(),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 950;
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (wide)
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  backgroundColor: Palette.paper,
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: IconBadge(LucideIcons.sprout),
                  ),
                  destinations: List.generate(
                    5,
                    (i) => NavigationRailDestination(
                      icon: Icon(icons[i], size: 21),
                      label: Text(labels[i]),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 28 : 22,
                        14,
                        wide ? 28 : 22,
                        7,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Brand(),
                                  ),
                                ),
                              ),
                              if (!teacher && c.snapshot.children.isNotEmpty)
                                const ChildAvatar(),
                              if (c.preview) ...[
                                const SizedBox(width: 10),
                                const Tag('PREVIEW'),
                              ],
                              IconButton(
                                tooltip: 'Notifications',
                                onPressed: () => openPage(
                                  context,
                                  const NotificationsScreen(),
                                ),
                                icon: const Icon(LucideIcons.bell, size: 21),
                              ),
                              const SizedBox(width: 3),
                              IconButton(
                                tooltip: 'Account and settings',
                                onPressed: () =>
                                    openPage(context, const AccountScreen()),
                                style: IconButton.styleFrom(
                                  backgroundColor: Palette.mint,
                                ),
                                icon: const Icon(
                                  LucideIcons.userRound,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (c.phaseOne != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 18),
                          child: SyncBadge(controller: c.phaseOne!),
                        ),
                      ),
                    if (c.loading) const LinearProgressIndicator(minHeight: 2),
                    if (c.loadError != null)
                      MaterialBanner(
                        content: Text(c.loadError!, style: textStyle(12)),
                        actions: [
                          TextButton(
                            onPressed: c.refresh,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    if (!teacher && c.snapshot.children.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22),
                        child: ChildSelector(),
                      ),
                    Expanded(
                      child: IndexedStack(index: _index, children: screens),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : DecoratedBox(
                decoration: const BoxDecoration(
                  color: Palette.paper,
                  border: Border(top: BorderSide(color: Palette.line)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
                    child: Row(
                      children: List.generate(
                        5,
                        (i) => Expanded(
                          child: Semantics(
                            selected: i == _index,
                            button: true,
                            label: labels[i],
                            child: InkWell(
                              key: Key('nav-${labels[i].toLowerCase()}'),
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => setState(() => _index = i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 5,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedContainer(
                                      duration: c.dataSaver
                                          ? Duration.zero
                                          : const Duration(milliseconds: 180),
                                      width: 49,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: i == _index
                                            ? Palette.mint
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        icons[i],
                                        size: 20,
                                        color: i == _index
                                            ? Palette.teal
                                            : Palette.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      labels[i],
                                      maxLines: 1,
                                      style: textStyle(
                                        10,
                                        color: i == _index
                                            ? Palette.teal
                                            : Palette.muted,
                                        weight: i == _index
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
