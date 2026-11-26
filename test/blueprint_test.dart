import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolday/app.dart';
import 'package:schoolday/core/launcher.dart';
import 'package:schoolday/core/data.dart';
import 'package:schoolday/core/theme.dart';
import 'package:schoolday/core/school_link.dart';
import 'package:schoolday/features/workspace/workspaces.dart';
import 'package:schoolday/features/workspace/pulse.dart';
import 'package:schoolday/features/messages/screen.dart';
import 'package:schoolday/features/learning/screen.dart';
import 'package:schoolday/ui/components.dart';

import 'app_test.dart' show makeController;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final role in Workspace.values) {
    for (final width in [390.0, 750.0, 1100.0]) {
      testWidgets('${role.name}: four workspaces at $width', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 844);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final c = await makeController(role: role);
        await tester.pumpWidget(SchooldayApp(controller: c));
        await tester.pumpAndSettle();
        final nav = width < 600
            ? find.byType(NavigationBar)
            : find.byType(NavigationRail);
        expect(nav, findsOneWidget);
        for (final space in schoolWorkspaces(role)) {
          final trigger = find.descendant(
            of: nav,
            matching: find.text(space.name),
          );
          await tester.tap(trigger.first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        c.dispose();
      });
    }
  }
  for (final brightness in Brightness.values) {
    testWidgets('Inbox golden and semantic contrast in ${brightness.name}', (
      tester,
    ) async {
      final loader = FontLoader('Manrope')
        ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
      await loader.load();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 650);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final theme = schooldayTheme(brightness), t = themeTokens(brightness);
      for (final ground in [t.paper, t.background]) {
        final l = [ground.computeLuminance(), t.muted.computeLuminance()]
          ..sort();
        expect((l.last + .05) / (l.first + .05), greaterThanOrEqualTo(7));
      }
      final c = await makeController(role: Workspace.teacher);
      await tester.pumpWidget(
        AppScope(
          controller: c,
          child: MaterialApp(
            theme: theme,
            home: const RepaintBoundary(
              key: Key('inbox-golden'),
              child: Scaffold(body: MessagesScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('inbox-golden')),
        matchesGoldenFile('goldens/inbox_${brightness.name}.png'),
      );
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
  testWidgets(
    'widget homework opens its scoped detail and back returns to Today',
    (tester) async {
      final c = await makeController(role: Workspace.parent);
      c.snapshot = const SchoolSnapshot(
        role: Workspace.parent,
        schoolId: 's',
        children: [SchoolRecord(id: 'a')],
        homework: [SchoolRecord(id: 'h', title: 'Field notebook')],
      );
      final router = SchoolRouter(c);
      await tester.pumpWidget(SchooldayApp(controller: c, router: router));
      await tester.pumpAndSettle();
      final link = SchoolLink.parse(
        widgetRoute(
          Uri.parse('schoolday://homework?school_id=s&child_id=a&entity_id=h'),
        ),
      )!;
      router.show(link);
      await tester.pumpAndSettle();
      expect(find.byType(LearningDetailScreen), findsOneWidget);
      await router.popRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LearningDetailScreen), findsNothing);
      router.show(
        const SchoolLink(SchoolLinkKind.notice, school: 'other-school'),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MainShell), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      c.dispose();
    },
  );
  test('substitute ranking excludes absences and overlapping lessons', () {
    final at = DateTime(2026, 11, 24, 9);
    final rows = [
      for (final id in ['a', 'b', 'c', 'd']) {'id': id, 'name': id},
    ];
    final slot = SchoolRecord(id: 's', date: at);
    final slots = [
      slot,
      SchoolRecord(id: 't', date: at, fields: {'teacher_id': 'b'}),
      SchoolRecord(
        id: 'u',
        date: at.add(const Duration(hours: 2)),
        fields: {'substitute_id': 'a'},
      ),
    ];
    expect(availableTeachers(rows, slots, slot, {'c'}).map((r) => r['id']), [
      'd',
      'a',
    ]);
  });
  test('notification resolves a scoped assignment; cross-school and unlinked child links are denied', () async {
    final c = await makeController(role: Workspace.parent);
    c.snapshot = const SchoolSnapshot(
      schoolId: 's',
      role: Workspace.parent,
      children: [SchoolRecord(id: 'a')],
      homework: [SchoolRecord(id: 'h')],
    );
    final link = SchoolLink.parse({
      'type': 'homework',
      'school_id': 's',
      'child_id': 'a',
      'entity_id': 'h',
    })!;
    expect(link.allowed(c), isTrue);
    expect(link.screen(c), isA<LearningDetailScreen>());
    expect(
      const SchoolLink(SchoolLinkKind.notice, school: 'elsewhere').allowed(c),
      isFalse,
    );
    expect(
      const SchoolLink(SchoolLinkKind.notice, child: 'other').allowed(c),
      isFalse,
    );
    c.dispose();
  });
}

SchooldayTokens themeTokens(Brightness brightness) =>
    brightness == Brightness.light
    ? SchooldayTokens.light
    : SchooldayTokens.dark;
