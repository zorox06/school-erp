import 'dart:convert';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

FirebaseOptions? firebaseOptions() {
  const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const sender = String.fromEnvironment('FIREBASE_SENDER_ID');
  const androidApp = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  const iosApp = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  final app = defaultTargetPlatform == TargetPlatform.iOS ? iosApp : androidApp;
  if (kIsWeb ||
      project.isEmpty ||
      sender.isEmpty ||
      app.isEmpty ||
      apiKey.isEmpty) {
    return null;
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: app,
    messagingSenderId: sender,
    projectId: project,
    iosBundleId: 'app.schoolday.schoolerp',
  );
}

@pragma('vm:entry-point')
Future<void> schoolPushBackground(RemoteMessage message) async {
  final options = firebaseOptions();
  if (options != null && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: options);
  }
  if (message.data['approve'] == 'true' &&
      defaultTargetPlatform == TargetPlatform.android) {
    final local = FlutterLocalNotificationsPlugin();
    await local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_schoolday'),
      ),
    );
    await local.show(
      id:
          (message.messageId ?? message.sentTime.toString()).hashCode &
          0x7fffffff,
      title: 'School leave request',
      body: 'Open Schoolday to securely review the request.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'school_quiet',
          'School circulars',
          importance: Importance.low,
          visibility: NotificationVisibility.private,
          actions: [
            AndroidNotificationAction(
              'approve',
              'Approve leave',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
  // Visible notification payloads are delivered by the OS. Never modify school
  // records or duplicate that notification in this background isolate.
}

class SchoolPushService {
  final SupabaseClient? client;
  final String? Function() school;
  final void Function(Map<String, dynamic>) onOpen;
  final FlutterLocalNotificationsPlugin local =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<String>? _tokens;
  StreamSubscription<RemoteMessage>? _foreground, _opened;
  String? _token;
  bool _ready = false;
  SchoolPushService({
    required this.client,
    required this.school,
    required this.onOpen,
  });
  bool get configured => firebaseOptions() != null;
  Future<String?> setEnabled(
    bool enabled, {
    bool requestPermission = true,
  }) async {
    if (!enabled) {
      await disable();
      return null;
    }
    if (!configured) {
      return 'Push needs Firebase and APNs configuration. In-app notices still work.';
    }
    if (client?.auth.currentUser == null || school() == null) {
      return 'Connect your school account before enabling device alerts.';
    }
    try {
      if (!_ready) {
        await Firebase.initializeApp(options: firebaseOptions());
        FirebaseMessaging.onBackgroundMessage(schoolPushBackground);
        await local.initialize(
          settings: InitializationSettings(
            android: const AndroidInitializationSettings('ic_stat_schoolday'),
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
              notificationCategories: [
                DarwinNotificationCategory(
                  'LEAVE_REQUEST',
                  actions: [
                    DarwinNotificationAction.plain(
                      'approve',
                      'Approve',
                      options: {DarwinNotificationActionOption.foreground},
                    ),
                  ],
                ),
              ],
            ),
          ),
          onDidReceiveNotificationResponse: (response) {
            final data = notificationRoute(response.payload, response.actionId);
            if (data != null) onOpen(data);
          },
        );
        final android = local
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            'school_urgent',
            'Urgent school alerts',
            description: 'Absence and urgent school alerts',
            importance: Importance.high,
          ),
        );
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            'school_quiet',
            'School circulars',
            description: 'Notices and circulars',
            importance: Importance.low,
            playSound: false,
          ),
        );
        await android?.createNotificationChannel(
          const AndroidNotificationChannel(
            'school_emergency',
            'School emergencies',
            description: 'Urgent school safety broadcasts',
            importance: Importance.max,
          ),
        );
        final launch = await local.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp == true) {
          final response = launch?.notificationResponse;
          final data = notificationRoute(response?.payload, response?.actionId);
          if (data != null) onOpen(data);
        }
        _ready = true;
      }
      final settings = requestPermission
          ? await FirebaseMessaging.instance.requestPermission(
              alert: true,
              badge: true,
              sound: true,
            )
          : await FirebaseMessaging.instance.getNotificationSettings();
      if (![
        AuthorizationStatus.authorized,
        AuthorizationStatus.provisional,
      ].contains(settings.authorizationStatus)) {
        return 'Notifications are disabled in your device settings.';
      }
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await FirebaseMessaging.instance
            .setForegroundNotificationPresentationOptions(
              alert: true,
              badge: true,
              sound: true,
            );
        if (await FirebaseMessaging.instance.getAPNSToken() == null) {
          return 'Waiting for Apple push registration. Try enabling alerts again shortly.';
        }
      }
      await _tokens?.cancel();
      final registration = Completer<void>();
      _tokens = FirebaseMessaging.instance.onRegistered.listen(
        (t) async {
          try {
            await _register(t);
            if (!registration.isCompleted) registration.complete();
          } catch (e) {
            if (!registration.isCompleted) registration.completeError(e);
          }
        },
        onError: (Object e) {
          if (!registration.isCompleted) registration.completeError(e);
        },
      );
      await Future.wait<void>([
        FirebaseMessaging.instance.register(),
        registration.future.timeout(const Duration(seconds: 20)),
      ]);
      await _foreground?.cancel();
      _foreground = FirebaseMessaging.onMessage.listen((m) async {
        if (defaultTargetPlatform != TargetPlatform.android ||
            client?.auth.currentUser == null) {
          return;
        }
        final emergency = m.data['channel'] == 'emergency';
        final urgent = m.data['channel'] == 'urgent' || emergency;
        try {
          await local.show(
            id: (m.messageId ?? m.sentTime.toString()).hashCode & 0x7fffffff,
            title: m.notification?.title ?? 'School update',
            body: m.notification?.body ?? 'Open Schoolday to view this update.',
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                emergency
                    ? 'school_emergency'
                    : urgent
                    ? 'school_urgent'
                    : 'school_quiet',
                emergency
                    ? 'School emergencies'
                    : urgent
                    ? 'Urgent school alerts'
                    : 'School circulars',
                importance: emergency
                    ? Importance.max
                    : urgent
                    ? Importance.high
                    : Importance.low,
                priority: emergency
                    ? Priority.max
                    : urgent
                    ? Priority.high
                    : Priority.low,
                playSound: urgent,
                visibility: NotificationVisibility.private,
                actions: m.data['approve'] == 'true'
                    ? [
                        const AndroidNotificationAction(
                          'approve',
                          'Approve leave',
                          showsUserInterface: true,
                          cancelNotification: true,
                        ),
                      ]
                    : null,
              ),
            ),
            payload: jsonEncode(m.data),
          );
        } catch (_) {
          /* A disabled OS channel must not interrupt the app. */
        }
      });
      await _opened?.cancel();
      _opened = FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => onOpen(m.data),
      );
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) onOpen(initial.data);
      return null;
    } catch (_) {
      return 'Device alerts couldn’t be connected. You can retry here; in-app updates remain available.';
    }
  }

  Future<void> _register(String token) async {
    if (school() == null || client?.auth.currentUser == null) return;
    await client!.rpc(
      'erp_register_device',
      params: {
        'p_school': school(),
        'p_token': token,
        'p_platform': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      },
    );
    _token = token;
  }

  Future<void> disable() async {
    await _tokens?.cancel();
    await _foreground?.cancel();
    await _opened?.cancel();
    if (_token != null && client?.auth.currentUser != null) {
      try {
        await client!.rpc('erp_unregister_device', params: {'p_token': _token});
      } catch (_) {
        /* Token deletion below prevents future delivery. */
      }
    }
    if (_ready) {
      try {
        await FirebaseMessaging.instance.unregister();
        await FirebaseMessaging.instance.setAutoInitEnabled(false);
      } catch (_) {
        /* Offline device; server binding is revoked at the next authenticated registration. */
      }
      await local.cancelAll();
    }
    _token = null;
  }
}

Map<String, dynamic>? notificationRoute(String? payload, String? action) {
  try {
    final data = Map<String, dynamic>.from(jsonDecode(payload ?? '{}') as Map);
    if (action == 'approve' && data['approve'] == 'true') {
      data['action'] = 'approve';
    }
    return data;
  } catch (_) {
    return null;
  }
}
