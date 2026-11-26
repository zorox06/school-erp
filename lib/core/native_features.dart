import 'package:flutter/services.dart';

class NativeSchoolFeatures {
  static const channel = MethodChannel('schoolday/native');

  static void onNotificationAction(
    void Function(Map<String, dynamic>) callback,
  ) {
    channel.setMethodCallHandler((call) async {
      if (call.method == 'notificationAction' && call.arguments is Map) {
        callback(Map<String, dynamic>.from(call.arguments as Map));
      }
    });
  }

  static Future<Map<String, dynamic>?> takeNotificationAction() async {
    try {
      final value = await channel.invokeMethod<Map>('takeNotificationAction');
      return value == null ? null : Map<String, dynamic>.from(value);
    } on MissingPluginException {
      return null;
    }
  }

  static Future<Map<String, dynamic>> info() async {
    try {
      return Map<String, dynamic>.from(
        await channel.invokeMethod<Map>('deviceInfo') ?? {},
      );
    } on MissingPluginException {
      return {'timezone': 'UTC', 'low_ram': false};
    } on PlatformException {
      return {'timezone': 'UTC', 'low_ram': false};
    }
  }

  static Future<void> openFile(String path, String mime) =>
      channel.invokeMethod('openFile', {'path': path, 'mime': mime});
  static Future<void> protectReport(bool protect) async {
    try {
      await channel.invokeMethod('protectReport', {'enabled': protect});
    } on MissingPluginException {
      /* Desktop tests have no private native report window. */
    }
  }
}
