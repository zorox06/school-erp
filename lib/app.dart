import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'core/data.dart';
import 'core/theme.dart';
import 'core/school_link.dart';
import 'ui/components.dart';
import 'features/auth/screen.dart';
import 'features/workspace/workspaces.dart';
import 'features/dashboard/screen.dart';
import 'features/account/screen.dart';
import 'features/attendance/screen.dart';

class SchooldayApp extends StatefulWidget {
  const SchooldayApp({super.key, required this.controller, this.router});
  final AppController controller;
  final SchoolRouter? router;
  @override
  State<SchooldayApp> createState() => _SchooldayAppState();
}

class _SchooldayAppState extends State<SchooldayApp> {
  late final router = widget.router ?? SchoolRouter(widget.controller);
  @override
  void dispose() {
    if (widget.router == null) router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    controller: widget.controller,
    child: MaterialApp.router(
      title: 'Schoolday',
      routerDelegate: router,
      debugShowCheckedModeBanner: false,
      theme: schooldayTheme(),
      darkTheme: schooldayTheme(Brightness.dark),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            disableAnimations:
                AppScope.of(context).reduceMotion || media.disableAnimations,
          ),
          child: child!,
        );
      },
    ),
  );
}

class SchoolRouter extends RouterDelegate<RouteSettings>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<RouteSettings> {
  SchoolRouter(this.controller) {
    controller.addListener(_refresh);
  }
  final AppController controller;
  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  SchoolLink? _link;
  Object? _scope;
  Object get _identity => (
    controller.auth.userId,
    controller.snapshot.schoolId,
    controller.workspace,
    controller.selectedChildId,
  );
  void _refresh() {
    if (_link != null && (_scope != _identity || !_link!.allowed(controller))) {
      _link = null;
    }
    notifyListeners();
  }

  void show(SchoolLink link) {
    if (!link.allowed(controller)) return;
    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    _scope = _identity;
    _link = link;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(RouteSettings configuration) async {}
  @override
  void dispose() {
    controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final link = _link;
    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage<void>(
          key: ValueKey((
            controller.auth.userId,
            controller.snapshot.schoolId,
            controller.workspace,
            controller.entered,
          )),
          child: _home(),
        ),
        if (link != null && link.allowed(controller))
          MaterialPage<void>(
            key: ObjectKey(link),
            child: link.screen(controller),
          ),
      ],
      onDidRemovePage: (page) {
        if (_link != null && page.key == ObjectKey(_link)) {
          _link = null;
          notifyListeners();
        }
      },
    );
  }

  Widget _home() => controller.entered && !controller.accessAssigned
      ? Scaffold(
          appBar: AppBar(title: const Text('Schoolday')),
          body: ContentList(
            children: [
              const ScreenHeading(
                'Your account is signed in.',
                eyebrow: 'School access',
              ),
              if (controller.loading)
                const LinearProgressIndicator()
              else if (controller.loadError != null)
                EmptyPanel(
                  icon: LucideIcons.cloudOff,
                  title: 'School workspace unavailable',
                  message: controller.loadError!,
                )
              else
                const EmptyPanel(
                  icon: LucideIcons.shieldCheck,
                  title: 'Waiting for school access',
                  message: 'Your school must assign your account a role and link its records. You cannot choose your own permissions.',
                ),
              OutlinedButton(
                onPressed: controller.loading ? null : controller.refresh,
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
      ? MainShell(key: ValueKey(controller.workspace))
      : const LoginScreen();
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  final _pages = PageController(keepPage: false);
  int _index = 0;

  void _selectTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
    _pages.jumpToPage(index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final controller = context
        .getInheritedWidgetOfExactType<AppScope>()!
        .notifier!;
    controller.refreshDevicePerformance();
    if (controller.auth.signedIn &&
        !controller.loading &&
        !controller.signingOut) {
      controller.refresh();
    }
  }

  @override
  void didHaveMemoryPressure() {
    if (mounted) AppScope.of(context).refreshDevicePerformance();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final teacher = c.workspace.isStaff;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 950;
    final compact = width < 600;
    final spaces = schoolWorkspaces(c.workspace);
    void select(int i) => _selectTab(i);
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _selectTab(0);
      },
      child: Scaffold(
        bottomNavigationBar: compact
            ? NavigationBar(
                height: 66,
                selectedIndex: _index,
                onDestinationSelected: select,
                destinations: [
                  for (final space in spaces)
                    NavigationDestination(
                      icon: Icon(space.icon),
                      label: space.name,
                    ),
                ],
              )
            : null,
        body: SafeArea(
          child: Row(
            children: [
              if (!compact)
                NavigationRail(
                  extended: wide,
                  minExtendedWidth: 156,
                  groupAlignment: -.9,
                  labelType: wide
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  selectedIndex: _index,
                  onDestinationSelected: select,
                  destinations: [
                    for (final space in spaces)
                      NavigationRailDestination(
                        icon: Icon(space.icon),
                        label: Text(space.name),
                      ),
                  ],
                ),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 28 : 18,
                        4,
                        wide ? 28 : 18,
                        3,
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
                              IconButton(
                                tooltip: 'Quick actions',
                                onPressed: () => showWorkspaceActions(context),
                                icon: const Icon(LucideIcons.circlePlus),
                              ),
                              if (c.phaseOne != null)
                                SyncBadge(
                                  controller: c.phaseOne!,
                                  compact: true,
                                ),

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
                                  backgroundColor: context.tones.mint,
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
                    if (!teacher && c.snapshot.children.isNotEmpty)
                      SizedBox(
                        height: 52,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          scrollDirection: Axis.horizontal,
                          itemCount: c.snapshot.children.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, i) {
                            final child = c.snapshot.children[i];
                            return ChoiceChip(
                              showCheckmark: false,
                              avatar: Badge(
                                isLabelVisible:
                                    c.features?.hasUnreadFor(child.id) ?? false,
                                child: const Icon(
                                  LucideIcons.userRound,
                                  size: 15,
                                ),
                              ),
                              label: Text(child.title ?? 'Student'),
                              selected: c.selectedChildId == child.id,
                              onSelected: (_) => c.chooseChild(child.id),
                            );
                          },
                        ),
                      ),
                    if (!teacher && c.snapshot.children.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22),
                        child: ChildSelector(),
                      ),
                    Expanded(
                      child: PageView.builder(
                        controller: _pages,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: spaces.length,
                        itemBuilder: (context, index) => _WorkspaceTab(
                          active: index == _index,
                          animateOnMount: index != 0,
                          child: WorkspaceBody(
                            key: ValueKey((
                              c.workspace,
                              c.selectedChildId,
                              index,
                            )),
                            destination: spaces[index],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceTab extends StatefulWidget {
  const _WorkspaceTab({
    required this.active,
    required this.animateOnMount,
    required this.child,
  });

  final bool active, animateOnMount;
  final Widget child;

  @override
  State<_WorkspaceTab> createState() => _WorkspaceTabState();
}

class _WorkspaceTabState extends State<_WorkspaceTab>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final _enter = AnimationController(vsync: this, value: 1);
  bool _mountedOnce = false;
  late Duration _duration;
  late bool _limited;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _duration = schoolMotion(context, 240, 0);
    _limited = limitSchoolEffects(context);
    if (!_mountedOnce && widget.active && widget.animateOnMount) _animate();
    if (_duration == Duration.zero) _enter.value = 1;
    _mountedOnce = true;
  }

  @override
  void didUpdateWidget(_WorkspaceTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _animate();
    if (!widget.active && oldWidget.active) _enter.value = 1;
  }

  void _animate() {
    if (_duration == Duration.zero) return;
    _enter.duration = _duration;
    _enter.forward(from: 0);
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_duration == Duration.zero) {
      return TickerMode(
        enabled: widget.active,
        child: ExcludeFocus(excluding: !widget.active, child: widget.child),
      );
    }
    final eased = CurveTween(curve: Curves.easeOutCubic).animate(_enter);
    return TickerMode(
      enabled: widget.active,
      child: ExcludeFocus(
        excluding: !widget.active,
        child: SlideTransition(
          position: Tween(
            begin: Offset(0, _limited ? .008 : .020),
            end: Offset.zero,
          ).animate(eased),
          child: widget.child,
        ),
      ),
    );
  }
}
