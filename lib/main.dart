import 'core/alert_router.dart';
import 'core/diagnostics.dart';
import 'core/theme.dart';
import 'ui/skeleton.dart';
import 'features/leave.dart';
import 'features/messages.dart';
import 'core/launcher.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'features/learning.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/data.dart';
import 'core/phase_one/store.dart';
import 'core/phase_one/sync.dart';
import 'core/phase_one/background.dart';
import 'core/phase_one/cached_repository.dart';
import 'core/phase_one/push.dart';
import 'core/school_features.dart';
import 'core/native_features.dart';
import 'core/media.dart';
import 'features/notices.dart';
import 'features/school.dart';

final schoolNavigator = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final boot = ValueNotifier<Widget?>(null);
  runApp(
    ValueListenableBuilder<Widget?>(
      valueListenable: boot,
      builder: (context, app, _) =>
          app ??
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: schooldayTheme(),
            home: const Scaffold(body: SafeArea(child: SchoolSkeleton())),
          ),
    ),
  );

  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Manrope'], license);
  });
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Color(0xFFF7F9F5),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  SupabaseClient? client;
  if (url.isNotEmpty && key.startsWith('sb_publishable_')) {
    try {
      await Supabase.initialize(url: url, publishableKey: key);
      client = Supabase.instance.client;
    } catch (_) {
      // Never log credentials or ship an administrative key in this client.
    }
  }
  const live = bool.fromEnvironment('ENABLE_SCHOOL_DATA', defaultValue: false);
  final native =
      !kIsWeb &&
      [
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform);
  Future<LocalSchoolStore>? store;
  Future<LocalSchoolStore> local() => store ??= LocalSchoolStore.open();
  late AppController controller;
  SchoolLauncher? launcher;
  SchoolAlertRouter? alerts;
  final configuredClient = client;
  final push = SchoolPushService(
    client: client,
    school: () => controller.snapshot.schoolId,
    onOpen: (message) => alerts?.receive(message),
  );
  final remote = live && client != null
      ? SupabaseSchoolRepository(client)
      : const EmptySchoolRepository();
  controller = AppController(
    auth: SupabaseAuthRepository(client),
    repository: live && native
        ? CachedSchoolRepository(
            remote: remote,
            owner: () => controller.signingOut
                ? null
                : configuredClient?.auth.currentUser?.id,
            local: local,
          )
        : remote,
    liveDataEnabled: live,
    updatePush: (enabled) => push.setEnabled(enabled),
    onLeaving: (leavingOwner) async {
      alerts?.clear();
      await push.disable();
      await launcher?.clear();
      await DefaultCacheManager().emptyCache();
      final owner = leavingOwner ?? configuredClient?.auth.currentUser?.id;
      if (owner != null) {
        await cancelSchoolSync(owner);
        if (store != null) await (await local()).purgeUser(owner);
        if (native) await SchoolMedia.clear(owner);
      }
    },
    createPhaseOne: !live || !native || configuredClient == null
        ? null
        : (owner, school, role) async {
            final p = PhaseOneController(
              store: await local(),
              remote: SupabasePhaseOneRemote(configuredClient),
              owner: owner,
              school: school,
              role: role,
              scheduleBackground: () => scheduleSchoolSync(owner, school),
            );
            await p.initialize(synchronize: false);
            await scheduleSchoolSync(owner, school);
            if (controller.notificationsEnabled) {
              controller.pushStatus = await push.setEnabled(
                true,
                requestPermission: false,
              );
            }
            return p;
          },
  );
  alerts = SchoolAlertRouter(
    ready: () =>
        controller.entered &&
        !controller.signingOut &&
        controller.features != null,
    dispatch: (message) async {
      if (!controller.entered || controller.features == null) {
        return;
      }
      if (message['school_id'] != null &&
          message['school_id'] != controller.snapshot.schoolId) {
        return;
      }
      if (message['action'] == 'approve' &&
          message['type'] == 'leave' &&
          controller.workspace.isStaff) {
        try {
          await controller.features!.queue('leave_decision', {
            'leave_id': message['entity_id'],
            'status': 'approved',
            'expected_version': 1,
          });
        } catch (_) {
          return;
        }
      }
      final type = message['type'];
      if (type == 'leave') {
        openLauncherPage(const LeaveInboxScreen());
        return;
      }
      if (type == 'homework') {
        openLauncherPage(LearningPage(teacher: controller.workspace.isStaff));
        return;
      }
      if (type == 'message') {
        openLauncherPage(
          Scaffold(
            appBar: AppBar(title: const Text('Messages')),
            body: const MessagesScreen(),
          ),
        );
        return;
      }
      if (type == 'timetable') {
        openLauncherPage(
          Scaffold(
            appBar: AppBar(title: const Text('Timetable')),
            body: const ScheduleScreen(),
          ),
        );
        return;
      }
      openLauncherPage(
        Scaffold(
          appBar: AppBar(
            title: Text(
              type == 'absence' ? 'School attendance' : 'School circulars',
            ),
          ),
          body: SafeArea(
            child: type == 'absence'
                ? const AttendanceContent()
                : const NoticesScreen(),
          ),
        ),
      );
    },
  );
  controller.addListener(() => alerts?.flush());
  if (native) {
    NativeSchoolFeatures.onNotificationAction((data) => alerts?.receive(data));
  }
  controller.onChildChanged = () =>
      WidgetsBinding.instance.addPostFrameCallback((_) {
        schoolNavigator.currentState?.popUntil((route) => route.isFirst);
      });
  controller.createFeatures = (sync) async {
    SchoolMedia.activate(sync.owner);
    final info = await NativeSchoolFeatures.info();
    return SchoolFeatures(
      sync: sync,
      gateway: SupabaseSchoolGateway(configuredClient!),
      owner: sync.owner,
      school: sync.school,
      role: sync.role,
      timezone: info['timezone'] as String? ?? 'UTC',
    );
  };
  launcher = SchoolLauncher(controller, (type) {
    final ctx = schoolNavigator.currentContext;
    if (ctx == null || !controller.entered || !controller.accessAssigned) {
      return;
    }
    if (type == 'attendance' && controller.workspace.canMarkAttendance) {
      openLauncherPage(const AttendanceScreen(teacher: true));
    }
    if (type == 'homework') openLauncherPage(const LearningPage());
    if (type == 'timetable') {
      openLauncherPage(
        Scaffold(
          appBar: AppBar(title: const Text('Timetable')),
          body: const ScheduleScreen(),
        ),
      );
    }
    if (type == 'notices') {
      openLauncherPage(
        Scaffold(
          appBar: AppBar(title: const Text('Notices')),
          body: const NoticesScreen(),
        ),
      );
    }
  });
  boot.value = SchooldayApp(
    controller: controller,
    navigatorKey: schoolNavigator,
  );
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await controller.initialize();
    if (native && defaultTargetPlatform == TargetPlatform.iOS) {
      final action = await NativeSchoolFeatures.takeNotificationAction();
      if (action != null) alerts?.receive(action);
    }
    await alerts?.flush();
    await initializeCrashReporting();
    if (native) {
      final prefs = await SharedPreferences.getInstance();
      final info = await NativeSchoolFeatures.info();
      await controller.setDataSaver(
        prefs.getBool('dataSaver') ?? info['low_ram'] == true,
      );
      await controller.setWidgets(prefs.getBool('widgets') ?? false);
      await launcher?.initialize();
    }
  });
}

void openLauncherPage(Widget page) => schoolNavigator.currentState?.push(
  MaterialPageRoute<void>(builder: (_) => page),
);
