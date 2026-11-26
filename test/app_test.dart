import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schoolday/app.dart';
import 'package:schoolday/core/data.dart';
import 'package:schoolday/features/dashboard/screen.dart';
import 'package:schoolday/features/learning/screen.dart';

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

Future<AppController> makeController({
  SchoolRepository? repository,
  Workspace? role,
}) async {
  SharedPreferences.setMockInitialValues({});
  final c = AppController(
    auth: TestAuth(assignedWorkspace: role)..active = role != null,
    repository: repository ?? const EmptySchoolRepository(),
  );
  await c.initialize();
  return c;
}

Future<void> chooseDestination(WidgetTester tester, String key) async {
  final nav=find.byWidgetPredicate((w)=>w is NavigationRail || w is NavigationBar);
  final dest=find.descendant(of:nav,matching:find.text(key));
  await tester.tap(dest.first);
  await tester.pumpAndSettle();
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

  test('signed-out state cannot read school records or write', () async {
    final repository = ObservedRepository();
    final c = await makeController(repository: repository);
    await c.refresh();
    expect(c.entered, isFalse);
    expect(c.canWrite, isFalse);
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
      final c = await makeController(role: Workspace.parent);
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

  test(
    'device limits reduce motion without overwriting data saver preference',
    () async {
      SharedPreferences.setMockInitialValues({});
      var info = <String, dynamic>{'low_ram': true, 'reduce_work': true};
      final c = AppController(
        auth: TestAuth(),
        repository: const EmptySchoolRepository(),
        readDeviceInfo: () async => info,
      );
      await c.initialize();
      await c.refreshDevicePerformance();
      expect(c.dataSaver, isTrue);
      expect(c.thumbnailWidth, 320);
      await c.setDataSaver(false);
      expect(c.dataSaver, isFalse);
      expect(c.reduceMotion, isFalse);
      expect(c.limitEffects, isTrue);
      info = {'low_ram': false, 'reduce_work': false};
      await c.refreshDevicePerformance();
      expect(c.reduceMotion, isFalse);
      expect(c.limitEffects, isFalse);
      expect(c.thumbnailWidth, 512);
      c.dispose();
    },
  );

  testWidgets('daybook moves to the selected lesson and opens that timetable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await makeController(role: Workspace.teacher);
    final now = DateTime.now();
    final target = DateTime(
      now.year,
      now.month,
      now.day + (now.weekday == 7 ? -1 : 1),
      9,
      30,
    );
    c.snapshot = SchoolSnapshot(
      schoolId: 'example',
      role: Workspace.teacher,
      timetable: [SchoolRecord(id: 'lesson', title: 'Geometry', date: target)],
    );
    await tester.pumpWidget(SchooldayApp(controller: c));
    await tester.pumpAndSettle();
    final marker = find.byKey(const Key('daybook-week-marker'));
    double markerX() => tester.getTopLeft(marker).dx;
    final start = markerX();
    await tester.tap(find.byKey(ValueKey('daybook-weekday-${target.weekday}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final halfway = markerX();
    await tester.pumpAndSettle();
    expect(halfway, isNot(start));
    expect(halfway, isNot(markerX()));
    await tester.tap(find.textContaining('09:30   Geometry'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TimetableDayPage>(find.byType(TimetableDayPage)).day,
      DateUtils.dateOnly(target),
    );
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets('workspace tabs build on demand and keep search state', (
    tester,
  ) async {
    final c = await makeController(role: Workspace.teacher);
    await tester.pumpWidget(SchooldayApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.byType(ClassesScreen, skipOffstage: false), findsNothing);

    await chooseDestination(tester, 'Classes');
    await tester.enterText(find.byType(TextField), 'Grade seven');
    await tester.pumpAndSettle();
    await chooseDestination(tester, 'Today');
    await chooseDestination(tester, 'Classes');
    expect(find.text('Grade seven'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  testWidgets(
    'school office and platform ownership have distinct menu entries',
    (tester) async {
      final c = await makeController(role: Workspace.admin);
      await tester.pumpWidget(SchooldayApp(controller: c));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Quick actions'));await tester.pumpAndSettle();
      expect(find.text('Emergency broadcast').hitTestable(),findsOneWidget);
      expect(find.text('Platform admin'),findsNothing);
      Navigator.pop(tester.element(find.byType(DraggableScrollableSheet)));
      await tester.pumpAndSettle();
      c.snapshot=const SchoolSnapshot(schoolId:'school',platformOwner:true,role:Workspace.admin);
      await tester.tap(find.byTooltip('Quick actions'));await tester.pumpAndSettle();
      expect(find.text('Platform admin'),findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );

  testWidgets('parent empty workspace navigates across all four destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = await makeController(role: Workspace.parent);
    await tester.pumpWidget(SchooldayApp(controller: c));
    await tester.pumpAndSettle();
    expect(find.text('No child linked yet'), findsOneWidget);
    for (final key in [
      'Learning',
      'School',
      'Inbox',
      'Today',
    ]) {
      await chooseDestination(tester, key);
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
      final c = await makeController(role: Workspace.teacher);
      await tester.pumpWidget(SchooldayApp(controller: c));
      await tester.pumpAndSettle();
      for (final key in [
        'Classes',
        'Inbox',
        'Marks',
        'Today',
      ]) {
        await chooseDestination(tester, key);
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
    final c = await makeController(role: Workspace.parent);
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
