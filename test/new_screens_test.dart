import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolday/app.dart';
import 'package:schoolday/core/data.dart';
import 'package:schoolday/features/academics.dart';
import 'package:schoolday/features/homework.dart';
import 'package:schoolday/features/leadership.dart';
import 'package:schoolday/features/alert_preferences.dart';
import 'package:schoolday/features/messages.dart';
import 'package:schoolday/features/scanner.dart';
import 'package:schoolday/features/timetable_edit.dart';

import 'app_test.dart' show makeController;

void main() {
  for (final entry in <String, Widget>{
    'homework': const HomeworkComposer(),
    'marks': const AcademicsScreen(),
    'principal': const LeadershipScreen(),
    'alerts': const AlertPreferencesScreen(),
    'new message': const ComposeMessageScreen(),
    'scanner': const DocumentScannerScreen(owner: 'test-only'),
    'timetable': const TimetableComposer(),
  }.entries) {
    testWidgets('${entry.key} supports large text and an empty account', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = await makeController(role: Workspace.principal);
      await tester.pumpWidget(SchooldayApp(controller: c));
      await tester.pumpAndSettle();
      final ctx = tester.element(find.byType(Navigator).first);
      Navigator.of(ctx).push(
        MaterialPageRoute<void>(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: entry.value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
}
