import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../roles.dart';
import 'store.dart';
import 'sync.dart';
import '../school_features.dart';

const schoolSyncTask = 'app.schoolday.schoolerp.sync';
Future<void>? _initialized;

@pragma('vm:entry-point')
void schoolSyncDispatcher() {
  Workmanager().executeTask((task, data) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    const enabled = bool.fromEnvironment('ENABLE_SCHOOL_DATA');
    if (!enabled) return true;
    try {
      await Supabase.initialize(
        url: const String.fromEnvironment('SUPABASE_URL'),
        publishableKey: const String.fromEnvironment(
          'SUPABASE_PUBLISHABLE_KEY',
        ),
      );
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null ||
          (data?['owner'] != null && user.id != data?['owner'])) {
        return true;
      }
      final db = await LocalSchoolStore.open();
      final context = await db.context(user.id);
      final school =
          data?['school'] as String? ?? context?['school_id'] as String?;
      final role = parseWorkspace(context?['role']);
      if (school == null || context?['school_id'] != school || role == null) {
        return true;
      }
      final controller = PhaseOneController(
        store: db,
        remote: SupabasePhaseOneRemote(client),
        owner: user.id,
        school: school,
        role: role,
      );
      final features = SchoolFeatures(
        sync: controller,
        gateway: SupabaseSchoolGateway(client),
        owner: user.id,
        school: school,
        role: role,
        timezone: 'UTC',
      );
      await controller.sync();
      final success = controller.status.name != 'offline';
      await controller.close();
      await features.close();
      return success;
    } catch (_) {
      return false;
    }
  });
}

Future<void> scheduleSchoolSync(String owner, String school) async {
  if (kIsWeb ||
      ![
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform)) {
    return;
  }
  _initialized ??= Workmanager().initialize(schoolSyncDispatcher);
  try {
    await _initialized;
    final data = <String, dynamic>{'owner': owner, 'school': school};
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Workmanager().registerPeriodicTask(
        'schoolday-periodic-$owner',
        schoolSyncTask,
        inputData: data,
        tag: 'schoolday-$owner',
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } else {
      await Workmanager().registerProcessingTask(
        schoolSyncTask,
        schoolSyncTask,
        inputData: data,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }
    await Workmanager().registerOneOffTask(
      schoolSyncTask,
      schoolSyncTask,
      inputData: data,
      tag: 'schoolday-$owner',
      initialDelay: const Duration(seconds: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  } catch (_) {
    // Foreground retries remain available when the OS refuses a scheduled job.
    _initialized = null;
  }
}

Future<void> cancelSchoolSync(String owner) async {
  if (kIsWeb ||
      ![
        TargetPlatform.android,
        TargetPlatform.iOS,
      ].contains(defaultTargetPlatform)) {
    return;
  }
  try {
    await Workmanager().cancelByTag('schoolday-$owner');
    await Workmanager().cancelByUniqueName(schoolSyncTask);
  } catch (_) {
    /* No worker registered. */
  }
}
