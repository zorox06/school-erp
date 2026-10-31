import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:schoolday/core/alert_router.dart';

void main() {
  test(
    'cold-start action waits for authenticated context and executes once',
    () async {
      bool ready = false;
      final delivered = <Map<String, dynamic>>[];
      final router = SchoolAlertRouter(
        ready: () => ready,
        dispatch: (data) async {
          delivered.add(data);
        },
      );
      final action = {
        'event_id': 'fixture',
        'action': 'approve',
        'type': 'leave',
      };
      router.receive(action);
      expect(delivered, isEmpty);
      ready = true;
      await router.flush();
      router.receive(action);
      await router.flush();
      expect(delivered.length, 1);
      expect(delivered.single['action'], 'approve');
    },
  );
  test(
    'logout removes queued alerts before the next account is ready',
    () async {
      bool ready = false;
      int sent = 0;
      final router = SchoolAlertRouter(
        ready: () => ready,
        dispatch: (_) async {
          sent++;
        },
      );
      router.receive({'event_id': 'old-account', 'type': 'leave'});
      router.clear();
      ready = true;
      await router.flush();
      expect(sent, 0);
    },
  );
  test(
    'duplicate OS callbacks during an in-flight action do not repeat it',
    () async {
      final hold = Completer<void>();
      int calls = 0;
      final router = SchoolAlertRouter(
        ready: () => true,
        dispatch: (_) async {
          calls++;
          await hold.future;
        },
      );
      final event = {'event_id': 'fixture', 'action': 'approve'};
      router.receive(event);
      router.receive(event);
      expect(calls, 1);
      hold.complete();
      await Future<void>.delayed(Duration.zero);
      await router.flush();
      expect(calls, 1);
    },
  );
}
