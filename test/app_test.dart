import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schoolday/app.dart';
import 'package:schoolday/core/data.dart';

class TestAuth implements AuthRepository {
  @override
  String? get userId => active ? 'test-user' : null;
  @override
  final Workspace? assignedWorkspace;
  TestAuth({this.assignedWorkspace});
  final events = StreamController<bool>.broadcast();
  bool active = false;
  @override
  bool get configured => false;
  @override
  String? get email => null;
  @override
  bool get signedIn => active;
  @override
  Stream<bool> get changes => events.stream;
  @override
  Future<void> signIn(String email, String password) async =>
      throw StateError('No test account');
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> signOut() async {
    active = false;
    events.add(false);
  }
}

class ObservedRepository implements SchoolRepository {
  int reads = 0, writes = 0;
  @override
  Future<SchoolSnapshot> load() async {
    reads++;
    return const SchoolSnapshot();
  }

  @override
  Future<void> saveItem(String collection, Map<String, dynamic> values) async {
    writes++;
  }
}

Future<AppController> makeController({SchoolRepository? repository}) async {
  SharedPreferences.setMockInitialValues({});
  final c = AppController(
    auth: TestAuth(),
    repository: repository ?? const EmptySchoolRepository(),
  );
  await c.initialize();
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'empty repository exposes no business values or records and rejects writes',
    () async {
      const repository = EmptySchoolRepository();
      final data = await repository.load();
      expect(data.schoolId, isNull);
      expect(data.schoolName, isNull);
      expect(data.displayName, isNull);
      expect(data.role, isNull);
      for (final records in [
        data.children,
        data.classes,
        data.homework,
        data.worksheets,
        data.timetable,
        data.attendance,
        data.news,
        data.events,
        data.conversations,
        data.invoices,
        data.notifications,
      ]) {
        expect(records, isEmpty);
      }
      await expectLater(
        repository.saveItem('homework', {'title': 'User input'}),
        throwsA(isA<SchoolDataUnavailable>()),
      );
    },
  );

  test('preview never reads remote records and cannot write', () async {
    final repository = ObservedRepository();
    final c = await makeController(repository: repository);
    c.enterPreview(Workspace.teacher);
    await c.refresh();
    expect(c.entered, isTrue);
    expect(c.canWrite, isFalse);
    expect(c.workspace, Workspace.teacher);
    expect(repository.reads, 0);
    expect(repository.writes, 0);
    await c.leave();
    expect(c.entered, isFalse);
    expect(c.snapshot.schoolName, isNull);
    c.dispose();
  });

  test(
    'leaving a workspace clears identity and selected child state',
    () async {
      final c = await makeController();
      c.enterPreview(Workspace.parent);
      c.chooseChild('selected-by-user');
      await c.leave();
      expect(c.selectedChildId, isNull);
      expect(c.selectedClassId, isNull);
      expect(c.snapshot.children, isEmpty);
      c.dispose();
    },
  );

  test('trusted teacher workspace is honored with null school data', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = TestAuth(assignedWorkspace: Workspace.teacher)..active = true;
    final c = AppController(
      auth: auth,
      repository: const EmptySchoolRepository(),
    );
    await c.initialize();
    expect(c.workspace, Workspace.teacher);
    expect(c.snapshot.schoolId, isNull);
    expect(c.snapshot.children, isEmpty);
    expect(c.canWrite, isFalse);
    c.dispose();
  });

  testWidgets('login validates blank input without contacting authentication', (
    tester,
  ) async {
    final c = await makeController();
    await tester.pumpWidget(SchooldayApp(controller: c));
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
    expect(c.entered, isFalse);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('parent empty workspace navigates across all five destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await makeController();
    c.enterPreview(Workspace.parent);
    await tester.pumpWidget(SchooldayApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('No child linked yet'), findsOneWidget);
    for (final key in [
      'nav-learning',
      'nav-school',
      'nav-inbox',
      'nav-fees',
      'nav-home',
    ]) {
      await tester.tap(find.byKey(Key(key)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('₹12,500'), findsNothing);
    expect(find.text('Aarav'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets(
    'teacher empty workspace has a different navigation and no class data',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await makeController();
      c.enterPreview(Workspace.teacher);
      await tester.pumpWidget(SchooldayApp(controller: c));
      await tester.pumpAndSettle();
      for (final key in [
        'nav-classes',
        'nav-homework',
        'nav-inbox',
        'nav-schedule',
        'nav-today',
      ]) {
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.byKey(const Key('nav-fees')), findsNothing);
      expect(c.canWrite, isFalse);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets('empty UI remains usable at larger text scaling', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await makeController();
    c.enterPreview(Workspace.parent);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: SchooldayApp(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
}
