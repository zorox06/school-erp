import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

SentryEvent sanitizedCrash(SentryEvent event) => SentryEvent(
  eventId: event.eventId,
  timestamp: event.timestamp,
  level: event.level,
  release: event.release,
  platform: event.platform,
  message: SentryMessage('Schoolday application error'),
  exceptions: event.exceptions
      ?.map(
        (e) => SentryException(
          type: e.type,
          value: 'Redacted application error',
          stackTrace: e.stackTrace,
          mechanism: e.mechanism,
        ),
      )
      .toList(),
);
Future<void> recordLocalCrash(String category) async {
  try {
    final root = await getApplicationSupportDirectory();
    final file = File('${root.path}/schoolday-diagnostics.log');
    final previous = await file.exists()
        ? await file.readAsLines()
        : <String>[];
    final lines = [
      ...previous.skip(previous.length > 63 ? previous.length - 63 : 0),
      '${DateTime.now().toUtc().toIso8601String()} $category',
    ];
    await file.writeAsString(lines.join('\n'), flush: true);
  } catch (_) {
    /* Reporting must never interfere with the app. */
  }
}

Future<void> initializeCrashReporting() async {
  const dsn = String.fromEnvironment('SENTRY_DSN');
  if (dsn.isNotEmpty) {
    try {
      await SentryFlutter.init((o) {
        o.dsn = dsn;
        o.sendDefaultPii = false;
        o.attachScreenshot = false;
        // Explicitly disable the SDK’s experimental capture of private school views.
        // ignore: experimental_member_use
        o.attachViewHierarchy = false;
        o.enableAutoNativeBreadcrumbs = false;
        o.enableAutoPerformanceTracing = false;
        o.tracesSampleRate = 0;
        o.replay.sessionSampleRate = 0;
        o.replay.onErrorSampleRate = 0;

        o.beforeSend = (event, hint) => sanitizedCrash(event);
      });
    } catch (_) {
      await recordLocalCrash('reporter_unavailable');
    }
  }
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    recordLocalCrash('flutter_error');
    previous?.call(details);
  };
}
