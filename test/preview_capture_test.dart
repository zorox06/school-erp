import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolday/app.dart';
import 'package:schoolday/core/data.dart';

import 'app_test.dart' show makeController;

// Optional rendered artifacts. Normal test runs do not create or compare images.
// flutter test test/preview_capture_test.dart --update-goldens --dart-define=CAPTURE_PREVIEWS=true
void main() {
  const capture = bool.fromEnvironment('CAPTURE_PREVIEWS');
  const outputDirectory = String.fromEnvironment(
    'PREVIEW_OUTPUT_DIR',
    defaultValue: 'build/preview',
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!capture) return;
    for (final entry in {
      'Manrope': 'assets/fonts/Manrope.ttf',
      'packages/lucide_icons_flutter/Lucide':
          'packages/lucide_icons_flutter/assets/lucide.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final font = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
      await font.load();
    }
  });
  for (final scenario in [
    'login',
    'parent',
    'teacher',
    'fees',
    'attendance',
    'notices',
    'principal',
    'admin',
    'student',
  ]) {
    testWidgets('render $scenario without fabricated school records', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await makeController();
      if (scenario != 'login') {
        controller.enterPreview(
          ['teacher', 'attendance'].contains(scenario)
              ? Workspace.teacher
              : scenario == 'principal'
              ? Workspace.principal
              : scenario == 'admin'
              ? Workspace.admin
              : scenario == 'student'
              ? Workspace.student
              : Workspace.parent,
        );
      }
      const boundary = Key('preview-boundary');
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: SchooldayApp(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      if (scenario == 'fees') {
        await tester.tap(find.byKey(const Key('nav-fees')));
        await tester.pumpAndSettle();
      }
      if (scenario == 'attendance') {
        await tester.ensureVisible(find.text('Mark attendance'));
        await tester.tap(find.text('Mark attendance'));
        await tester.pumpAndSettle();
      }
      if (scenario == 'notices') {
        await tester.tap(find.byKey(const Key('nav-school')));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(boundary),
        matchesGoldenFile(Uri.file('$outputDirectory/Schoolday-$scenario.png')),
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    }, skip: !capture);
  }
}
