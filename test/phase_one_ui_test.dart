import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:schoolday/core/data.dart';
import 'package:schoolday/core/phase_one/models.dart';
import 'package:schoolday/core/phase_one/store.dart';
import 'package:schoolday/core/phase_one/sync.dart';
import 'package:schoolday/features/attendance.dart';
import 'package:schoolday/features/notices.dart';
import 'package:schoolday/ui/components.dart';

import 'app_test.dart' show makeController;
import 'phase_one_sync_test.dart' show RemoteBoundary;

void main() {
  sqfliteFfiInit();
  Future<(AppController, PhaseOneController, LocalSchoolStore)> fixture(
    WidgetTester tester, {
    int rosterSize = 500,
  }) async {
    final c = await makeController();
    final db = await LocalSchoolStore.open(
      factory: databaseFactoryFfi,
      location: inMemoryDatabasePath,
    );
    c.workspace = Workspace.teacher;
    c.snapshot = const SchoolSnapshot(
      schoolId: 's',
      role: Workspace.teacher,
      classes: [SchoolRecord(id: 'class-a', title: 'Fixture register')],
    );
    c.selectedClassId = 'class-a';
    final p = PhaseOneController(
      store: db,
      remote: RemoteBoundary()..online = false,
      owner: 'u',
      school: 's',
      role: Workspace.teacher,
    );
    c.phaseOne = p;
    await db.cacheRoster(
      p.scope,
      List.generate(
        rosterSize,
        (i) => RosterStudent(
          id: 's-$i',
          classId: 'class-a',
          name: 'Fixture ${i.toString().padLeft(3, '0')}',
        ),
      ),
    );
    await p.reload();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() async {
      c.phaseOne = null;
      await p.close();
      c.dispose();
      await db.db.close();
    });
    return (c, p, db);
  }

  testWidgets(
    '500-student roster stays lazy; opening Present drafts queues no writes',
    (tester) async {
      final (c, p, db) = await tester.runAsync(
        () => fixture(tester),
      ) as (AppController, PhaseOneController, LocalSchoolStore);
      await tester.pumpWidget(
        AppScope(
          controller: c,
          child: const MaterialApp(home: FastAttendanceScreen()),
        ),
      );
      await tester.pump();
      expect(find.text('Fixture 000'), findsOneWidget);
      expect(find.text('Fixture 499'), findsNothing);
      expect(await tester.runAsync(() => db.pending(p.scope)), 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'notice acknowledgement and read receipt persist offline in a snapping sheet',
    (tester) async {
      final (c, p, db) = await tester.runAsync(
        () => fixture(tester, rosterSize: 0),
      ) as (AppController, PhaseOneController, LocalSchoolStore);
      final notice = SchoolNotice(
        id: 'n',
        title: 'Important fixture circular',
        body: 'Test fixture only.',
        publishedAt: DateTime.now(),
        important: true,
      );
      await tester.runAsync(() async {
        await db.putCache(p.scope, 'notice', 'n', notice.toJson());
        await p.reload();
      });
      await tester.runAsync(
        () => tester.pumpWidget(
          AppScope(
            controller: c,
            child: const MaterialApp(home: Scaffold(body: NoticesScreen())),
          ),
        ),
      );
      await tester.runAsync(() async {
        while (p.noticesLoading) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester.tap(find.text('Important fixture circular'));
      });
      await tester.pumpAndSettle();
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      await tester.ensureVisible(find.text('Acknowledge'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Acknowledge'));
      });
      await tester.pumpAndSettle();
      // Drain SQLite futures before asserting persisted state.
      await tester.runAsync(() => p.reload());
      await tester.pumpAndSettle();
      expect(p.notices.single.acknowledged, isTrue);
      expect(await tester.runAsync(() => db.pending(p.scope)), 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
