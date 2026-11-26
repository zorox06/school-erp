import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/school_features.dart';

String? assignedTeacher(SchoolRecord lesson) =>
    (lesson.fields['substitute_id'] ?? lesson.fields['teacher_id']) as String?;

List<SchoolRow> availableTeachers(
  List<SchoolRow> staff,
  List<SchoolRecord> schedule,
  SchoolRecord slot,
  Set<String> absent,
) {
  final workload = <String, int>{};
  final busy = {...absent};
  final start = slot.date!;
  DateTime end(SchoolRecord r) =>
      DateTime.tryParse(r.fields['ends_at']?.toString() ?? '') ??
      r.date!.add(
        Duration(minutes: (r.fields['duration_minutes'] as num?)?.toInt() ?? 1),
      );
  for (final lesson in schedule) {
    final id = assignedTeacher(lesson);
    if (id == null || lesson.date == null || lesson.id == slot.id) continue;
    if (DateUtils.isSameDay(lesson.date!.toLocal(), start.toLocal())) {
      workload.update(id, (n) => n + 1, ifAbsent: () => 1);
    }
    if (lesson.date!.isBefore(end(slot)) && start.isBefore(end(lesson))) {
      busy.add(id);
    }
  }
  return staff
      .where((r) => r['id'] is String && !busy.contains(r['id']))
      .toList()
    ..sort((a, b) {
      final byLoad = (workload[a['id']] ?? 0).compareTo(workload[b['id']] ?? 0);
      return byLoad != 0
          ? byLoad
          : (a['name'] ?? '').toString().compareTo(
              (b['name'] ?? '').toString(),
            );
    });
}
