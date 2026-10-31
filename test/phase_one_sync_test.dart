import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:schoolday/core/roles.dart';
import 'package:schoolday/core/phase_one/models.dart';
import 'package:schoolday/core/phase_one/store.dart';
import 'package:schoolday/core/phase_one/sync.dart';

// Only the network boundary is substituted; SQLite and queue logic are real.
class RemoteBoundary implements PhaseOneRemote {
  bool online = true, forbidden = false;
  Completer<void>? requestStarted, hold;
  Map<String, dynamic>? authoritative;
  final accepted = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> attendance(
    String school,
    Map<String, dynamic> change,
  ) async {
    if (!online) throw const SocketException('offline');
    if (forbidden) {
      throw const PostgrestException(message: 'Forbidden', code: '42501');
    }
    requestStarted?.complete();
    requestStarted = null;
    await hold?.future;
    accepted.add(change);
    return authoritative ?? change;
  }

  @override
  Future<Map<String, dynamic>> delta(String school, String? cursor) async {
    if (!online) throw const SocketException('offline');
    return {'records': <dynamic>[], 'cursor': cursor, 'has_more': false};
  }

  @override
  Future<List<RosterStudent>> roster(
    String school,
    String classId,
    String? after,
  ) async {
    if (!online) throw const SocketException('offline');
    return [student];
  }

  @override
  Future<List<SchoolNotice>> notices(String school, String? after) async => [];
  @override
  Future<void> receipt(String school, String noticeId, bool acknowledge) async {
    if (!online) throw const SocketException('offline');
  }

  @override
  Future<void> publish(
    String school,
    String title,
    String body,
    bool important,
  ) async {}
}

const student = RosterStudent(
  id: 'student-a',
  classId: 'class-a',
  name: 'Test fixture',
);
final now = DateTime.utc(2026, 10, 31, 10);
AttendanceEntry entry(String operation, AttendanceStatus status) =>
    AttendanceEntry(
      studentId: student.id,
      classId: student.classId,
      day: '2026-10-31',
      operationId: operation,
      status: status,
      clientTime: now,
      pending: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late LocalSchoolStore db;
  setUp(() async {
    db = await LocalSchoolStore.open(
      factory: databaseFactoryFfi,
      location: inMemoryDatabasePath,
    );
  });
  tearDown(() async {
    await db.db.close();
  });

  test('opening an empty SQLite store seeds no school records or pending operations', () async {
    expect(await db.cached('u:s', 'roster'), isEmpty);
    expect(await db.pending('u:s'), 0);
    expect(await db.context('u'), isNull);
  });
  test('attendance edit and outbox insert roll back together when queue insertion fails', () async {
    await db.db.execute(
      "CREATE TRIGGER reject_test_write BEFORE INSERT ON outbox BEGIN SELECT RAISE(ABORT,'test failure'); END",
    );
    await expectLater(
      db.queueAttendance('u:s', [entry('op-a', AttendanceStatus.absent)]),
      throwsA(isA<DatabaseException>()),
    );
    expect(await db.cached('u:s', 'attendance'), isEmpty);
    expect(await db.pending('u:s'), 0);
  });
  test(
    'newer local edit survives an acknowledgement for an in-flight older edit',
    () async {
      await db.queueAttendance('u:s', [entry('old', AttendanceStatus.absent)]);
      final old = (await db.due('u:s', now)).single;
      await db.queueAttendance('u:s', [entry('new', AttendanceStatus.late)]);
      await db.accept(
        'u:s',
        old,
        entry('old', AttendanceStatus.absent).toJson(),
      );
      expect((await db.due('u:s', now)).single.operationId, 'new');
      expect((await db.cached('u:s', 'attendance')).single['status'], 'late');
      expect((await db.cached('u:s', 'attendance')).single['_pending'], isTrue);
    },
  );
  test('server conflict response becomes authoritative after the sent version is accepted', () async {
    await db.queueAttendance('u:s', [entry('local', AttendanceStatus.absent)]);
    final remote = RemoteBoundary()
      ..authoritative = entry('server', AttendanceStatus.leave).toJson();
    final p = PhaseOneController(
      store: db,
      remote: remote,
      owner: 'u',
      school: 's',
      role: Workspace.teacher,
      clock: () => now,
    );
    await p.sync();
    expect(p.entries.values.single.status, AttendanceStatus.leave);
    expect(p.entries.values.single.operationId, 'server');
    expect(p.pendingCount, 0);
    await p.close();
  });
  test(
    'offline writes persist and retry after backoff instead of disappearing',
    () async {
      final remote = RemoteBoundary()..online = false;
      await db.queueAttendance('u:s', [
        entry('local', AttendanceStatus.absent),
      ]);
      var clock = now;
      final p = PhaseOneController(
        store: db,
        remote: remote,
        owner: 'u',
        school: 's',
        role: Workspace.teacher,
        clock: () => clock,
      );
      await p.sync();
      expect(p.status, SyncStatus.offline);
      expect(p.pendingCount, 1);
      expect(await db.due('u:s', now), isEmpty);
      remote.online = true;
      clock = now.add(const Duration(minutes: 5));
      await p.sync();
      expect(p.pendingCount, 0);
      expect(remote.accepted, hasLength(1));
      expect(p.status, SyncStatus.synced);
      await p.close();
    },
  );
  test('permission failures remain visible and blocked without endless network retries', () async {
    await db.queueAttendance('u:s', [entry('local', AttendanceStatus.absent)]);
    final p = PhaseOneController(
      store: db,
      remote: RemoteBoundary()..forbidden = true,
      owner: 'u',
      school: 's',
      role: Workspace.teacher,
      clock: () => now,
    );
    await p.sync();
    expect(p.blockedCount, 1);
    expect(p.pendingCount, 1);
    expect(await db.due('u:s', now.add(const Duration(days: 1))), isEmpty);
    final log = await db.db.query('sync_failures');
    expect(log.single['category'], 'permission_or_validation');
    expect(log.single.keys, isNot(contains('payload')));
    await p.close();
  });
  test('parent and student roles cannot queue attendance, even with a cached roster', () async {
    for (final role in [Workspace.parent, Workspace.student]) {
      final p = PhaseOneController(
        store: db,
        remote: RemoteBoundary(),
        owner: 'u',
        school: 's',
        role: role,
      );
      p.students = [student];
      await expectLater(
        p.mark([(student, AttendanceStatus.absent, null)], '2026-10-31'),
        throwsStateError,
      );
      expect(await db.pending('u:s'), 0);
      await expectLater(p.publish('Title', 'Body', false), throwsStateError);
      await p.close();
    }
  });
  test('unknown student cannot enter the local write queue', () async {
    final p = PhaseOneController(
      store: db,
      remote: RemoteBoundary(),
      owner: 'u',
      school: 's',
      role: Workspace.teacher,
    );
    await expectLater(
      p.mark([(student, AttendanceStatus.absent, null)], '2026-10-31'),
      throwsStateError,
    );
    expect(await db.pending('u:s'), 0);
    await p.close();
  });
  test('delta refresh preserves unsynced drafts and advances its cursor transactionally', () async {
    await db.queueAttendance('u:s', [entry('local', AttendanceStatus.late)]);
    await db.mergeAttendance('u:s', [
      entry('server', AttendanceStatus.absent).toJson(),
    ], '42');
    expect((await db.cached('u:s', 'attendance')).single['status'], 'late');
    expect(await db.cursor('u:s'), '42');
    expect(await db.pending('u:s'), 1);
  });
  test('purging one account removes its caches and queue without touching another account', () async {
    await db.queueAttendance('alice:s', [entry('a', AttendanceStatus.absent)]);
    await db.queueAttendance('bob:s', [entry('b', AttendanceStatus.present)]);
    await db.saveContext('alice', {'school_id': 's'});
    await db.purgeUser('alice');
    expect(await db.pending('alice:s'), 0);
    expect(await db.cached('alice:s', 'attendance'), isEmpty);
    expect(await db.context('alice'), isNull);
    expect(await db.pending('bob:s'), 1);
  });
  test('receipt retries preserve acknowledgement when a later read event is queued', () async {
    final notice = SchoolNotice(
      id: 'n',
      title: 'Fixture',
      body: 'Test only',
      publishedAt: now,
      important: true,
    );
    await db.queueReceipt('u:s', notice, true);
    await db.queueReceipt('u:s', notice, false);
    expect((await db.due('u:s', now)).single.payload['acknowledge'], isTrue);
    expect((await db.cached('u:s', 'notice')).single['acknowledged'], isTrue);
  });
  test('queue survives database close and reopen on disk', () async {
    final temp = await Directory.systemTemp.createTemp(
      'schoolday-sqlite-test-',
    );
    final location = '${temp.path}/test.db';
    final first = await LocalSchoolStore.open(
      factory: databaseFactoryFfi,
      location: location,
    );
    await first.queueAttendance('u:s', [
      entry('persist', AttendanceStatus.absent),
    ]);
    await first.db.close();
    final second = await LocalSchoolStore.open(
      factory: databaseFactoryFfi,
      location: location,
    );
    expect((await second.due('u:s', now)).single.operationId, 'persist');
    await second.db.close();
    await temp.delete(recursive: true);
  });
  test(
    'late background responses cannot repopulate a logged-out user cache',
    () async {
      await db.purgeUser('alice');
      await db.saveContext('alice', {'school_id': 's'});
      await db.queueAttendance('alice:s', [
        entry('late-response', AttendanceStatus.absent),
      ]);
      await db.mergeAttendance('alice:s', [
        entry('server', AttendanceStatus.present).toJson(),
      ], '7');
      expect(await db.context('alice'), isNull);
      expect(await db.cached('alice:s', 'attendance'), isEmpty);
      expect(await db.pending('alice:s'), 0);
      expect(await db.cursor('alice:s'), isNull);
      await db.activateUser('alice');
      await db.saveContext('alice', {'school_id': 's'});
      expect(await db.context('alice'), isNotNull);
    },
  );
}
