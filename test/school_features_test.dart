import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolday/core/school_features.dart';
import 'package:schoolday/core/phase_one/store.dart';
import 'package:schoolday/core/phase_one/sync.dart';
import 'package:schoolday/core/phase_one/models.dart';
import 'package:schoolday/core/roles.dart';
import 'package:schoolday/core/media.dart';
import 'package:schoolday/core/diagnostics.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:image/image.dart' as im;

import 'phase_one_sync_test.dart' show RemoteBoundary;

class GatewayBoundary implements SchoolGateway {
  bool offline = false;
  Map<String, Completer<SchoolRow>> holds = {};
  SchoolRow response = {};
  final calls = <String>[];
  @override
  Future<dynamic> call(String name, SchoolRow parameters) async {
    calls.add(name);
    if (offline) throw const SocketException('offline');
    if (name == 'erp_workspace') {
      return holds[parameters['p_child']]?.future ?? response;
    }
    return response;
  }

  @override
  Future<void> upload(String path, Uint8List bytes, String mime) async {}
  @override
  Future<Uint8List> download(String path) async => Uint8List(0);
  @override
  Future<String> signedUrl(String path) async => 'https://example.invalid';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late LocalSchoolStore db;
  late PhaseOneController sync;
  late GatewayBoundary remote;
  late SchoolFeatures hub;
  setUp(() async {
    db = await LocalSchoolStore.open(
      factory: databaseFactoryFfi,
      location: inMemoryDatabasePath,
    );
    sync = PhaseOneController(
      store: db,
      remote: RemoteBoundary(),
      owner: 'u',
      school: 's',
      role: Workspace.parent,
    );
    remote = GatewayBoundary();
    hub = SchoolFeatures(
      sync: sync,
      gateway: remote,
      owner: 'u',
      school: 's',
      role: Workspace.parent,
      timezone: 'UTC',
    );
  });
  tearDown(() async {
    await sync.close();
    await hub.close();
    await db.db.close();
  });
  test(
    'switching children rejects a late response for the previous child',
    () async {
      final hold = Completer<SchoolRow>();
      remote.holds['a'] = hold;
      final old = hub.selectChild('a');
      while (!remote.calls.contains('erp_workspace')) {
        await Future<void>.delayed(Duration.zero);
      }
      remote.response = {
        'homework': [
          {'id': 'b-work', 'title': 'Fixture B'},
        ],
      };
      await hub.selectChild('b');
      hold.complete({
        'homework': [
          {'id': 'a-work', 'title': 'Fixture A'},
        ],
      });
      await old;
      expect(hub.childId, 'b');
      expect(hub.rows('homework').single['id'], 'b-work');
      expect(await db.cached(hub.scope, 'homework/a'), isEmpty);
    },
  );
  test(
    'offline child changes show only the selected child’s cached work',
    () async {
      remote.offline = true;
      await db.putCache(hub.scope, 'homework/a', 'a', {'id': 'a'});
      await db.putCache(hub.scope, 'homework/b', 'b', {'id': 'b'});
      await hub.selectChild('a');
      expect(hub.rows('homework').single['id'], 'a');
      await hub.selectChild('b');
      expect(hub.rows('homework').single['id'], 'b');
      expect(hub.offline, isTrue);
    },
  );
  test('parent cannot enqueue staff learning or emergency writes', () async {
    await expectLater(hub.queue('grade', {}), throwsStateError);
    await expectLater(hub.queue('homework', {}), throwsStateError);
    await expectLater(hub.queue('emergency', {}), throwsStateError);
    expect(await db.pending(hub.scope), 0);
  });
  test(
    'server grade conflict returns the server record and tracks review',
    () async {
      remote.response = {
        'conflict': true,
        'record': {'id': 'g', 'score': 72, 'version': 3},
      };
      final result = await hub.send(
        const QueuedOperation('grade/g', 'op', 'grade', {'score': 91}, 0),
      );
      expect(result?['score'], 72);
      expect(hub.conflicts, 1);
    },
  );
  test('feature acknowledgement cannot delete a newer queued edit', () async {
    await db.queueFeature(
      hub.scope,
      'grade',
      'older',
      {'score': 50},
      cacheKind: 'grades/staff',
      cacheKey: 'assessment/student',
      optimistic: {'id': 'g', 'score': 50},
    );
    final sent = (await db.due(hub.scope, DateTime.now())).single;
    await db.queueFeature(
      hub.scope,
      'grade',
      'newer',
      {'score': 80},
      cacheKind: 'grades/staff',
      cacheKey: 'assessment/student',
      optimistic: {'id': 'g', 'score': 80},
    );
    await db.accept(hub.scope, sent, {'id': 'g', 'score': 50});
    expect(await db.pending(hub.scope), 1);
    expect((await db.cached(hub.scope, 'grades/staff')).single['score'], 80);
  });
  test('missing queued attachment is a permanent repairable error', () async {
    await expectLater(
      hub.send(
        const QueuedOperation('submission/op', 'op', 'submission', {
          'homework_id': 'h',
          'attachments': [
            {
              'path': 'missing-private-file',
              'id': 'f',
              'mime': 'image/jpeg',
              'bytes': 1,
            },
          ],
        }, 0),
      ),
      throwsA(predicate((e) => e.toString().contains('22023'))),
    );
  });
  test('scanner applies crop, enhancement and rotation to a real image', () {
    final image = im.Image(width: 100, height: 80);
    im.fill(image, color: im.ColorRgb8(255, 200, 150));
    final result = processScan({
      'bytes': im.encodePng(image),
      'crop': [.1, .1, .9, .9],
      'enhance': true,
      'rotate': true,
    });
    final decoded = im.decodeJpg(result)!;
    expect(decoded.width, 64);
    expect(decoded.height, 80);
    final pixel = decoded.getPixel(0, 0);
    expect((pixel.r - pixel.g).abs(), lessThan(3));
  });
  test(
    'crash reports discard messages, school data, users and breadcrumbs',
    () {
      final clean = sanitizedCrash(
        SentryEvent(
          message: SentryMessage('private school content'),
          user: SentryUser(id: 'private-user'),
          breadcrumbs: [Breadcrumb(message: 'private message')],
          exceptions: [
            SentryException(type: 'StateError', value: 'private credentials'),
          ],
        ),
      );
      final serialized = clean.toJson().toString();
      expect(serialized, isNot(contains('private')));
      expect(clean.exceptions!.single.value, 'Redacted application error');
    },
  );
}
