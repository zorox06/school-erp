import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolday/app.dart';
import 'package:schoolday/core/data.dart';
import 'package:schoolday/core/fees.dart';
import 'package:schoolday/features/learning.dart';

import 'app_test.dart' show makeController, TestAuth;

void main() {
  test('live membership and selected child govern access to statements', () {
    final controller = AppController(
      auth: TestAuth(assignedWorkspace: Workspace.admin)..active = true,
      repository: const EmptySchoolRepository(),
      liveDataEnabled: true,
    );
    addTearDown(controller.dispose);
    expect(controller.accessAssigned, isFalse);
    controller.snapshot = SchoolSnapshot.fromJson({
      'school_id': 'school',
      'role': 'parent',
      'invoices': [
        {
          'id': 'one',
          'student_id': 'first',
          'amount': '5.25',
          'currency': 'USD',
        },
        {'id': 'two', 'child_id': 'second', 'amount': 12, 'currency': 'USD'},
        {'id': 'unlinked', 'amount': 99, 'currency': 'USD'},
      ],
    });
    expect(controller.accessAssigned, isTrue);
    expect(controller.snapshot.invoices, isEmpty);
    controller.selectedChildId = 'first';
    expect(outstandingFees(controller.snapshot.invoices), 'USD 5.25');
    controller.selectedChildId = 'second';
    expect(outstandingFees(controller.snapshot.invoices), 'USD 12');
  });
  test('school fee contract matches the shared examples', () {
    final cases =
        jsonDecode(File('test/fixtures/fees.json').readAsStringSync()) as List;
    for (final c in cases) {
      final rows = (c['invoices'] as List).indexed
          .map(
            (x) => SchoolRecord.fromJson({
              ...Map<String, dynamic>.from(x.$2),
              'id': '${x.$1}',
            }),
          )
          .toList();
      expect(outstandingFees(rows), c['expected'], reason: c['label']);
    }
  });
  for (final role in [Workspace.principal, Workspace.admin]) {
    testWidgets('${role.name} Homework shortcut opens teaching workspace', (
      tester,
    ) async {
      final c = await makeController();
      c.enterPreview(role);
      await tester.pumpWidget(SchooldayApp(controller: c));
      await tester.pumpAndSettle();
      final homework = find.text('Homework').hitTestable();
      await tester.scrollUntilVisible(
        find.text('Homework'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(homework.first);
      await tester.pumpAndSettle();
      expect(find.byType(LearningPage), findsOneWidget);
      expect(find.text('Your teaching shelf'.toUpperCase()), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
}
