import '../core/data.dart';
import '../core/phase_one/models.dart';
import '../features/learning/screen.dart';
import '../features/messages/screen.dart';
import '../features/notices/screen.dart';
import '../features/leave/screen.dart';
import '../features/school/screen.dart';

import 'package:flutter/material.dart';

enum SchoolLinkKind { attendance, homework, message, timetable, notice, leave }

class SchoolLink {
  const SchoolLink(this.kind, {this.school, this.child, this.entity});
  final SchoolLinkKind kind;
  final String? school, child, entity;
  static SchoolLink? parse(Map<String, dynamic> data) {
    final kind = switch (data['type']) {
      'absence' || 'attendance' => SchoolLinkKind.attendance,
      'homework' => SchoolLinkKind.homework,
      'message' => SchoolLinkKind.message,
      'timetable' => SchoolLinkKind.timetable,
      'notice' || 'notices' || 'emergency' => SchoolLinkKind.notice,
      'leave' => SchoolLinkKind.leave,
      _ => null,
    };
    String? id(dynamic v) => v is String && v.isNotEmpty ? v : null;
    return kind == null
        ? null
        : SchoolLink(
            kind,
            school: id(data['school_id']),
            child: id(data['student_id'] ?? data['child_id']),
            entity: id(data['conversation_id'] ?? data['entity_id']),
          );
  }

  bool allowed(AppController c) =>
      c.entered &&
      !c.signingOut &&
      c.accessAssigned &&
      (school == null || school == c.snapshot.schoolId) &&
      (child == null ||
          c.workspace.isStaff ||
          c.snapshot.children.any((r) => r.id == child));
  Widget screen(AppController c) {
    assert(allowed(c));
    Widget frame(String name, Widget body) => Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SafeArea(child: body),
    );
    switch (kind) {
      case SchoolLinkKind.homework:
        final r = c
            .learningItems(false)
            .where((r) => r.id == entity)
            .firstOrNull;
        return r == null
            ? LearningPage(teacher: c.workspace.isStaff)
            : LearningDetailScreen(record: r, teacher: c.workspace.isStaff);
      case SchoolLinkKind.notice:
        final SchoolNotice? n = c.phaseOne?.notices
            .where((n) => n.id == entity)
            .firstOrNull;
        return frame(
          'Circulars',
          n == null ? const NoticesScreen() : NoticeContent(notice: n),
        );
      case SchoolLinkKind.message:
        final row = c.features
            ?.rows('conversations')
            .where((r) => r['id'] == entity)
            .firstOrNull;
        return row == null
            ? frame('Inbox', const MessagesScreen())
            : ConversationScreen(
                record: SchoolRecord(
                  id: row['id'],
                  title: row['contact_name'],
                  fields: row,
                ),
              );
      case SchoolLinkKind.leave:
        return const LeaveInboxScreen();
      case SchoolLinkKind.attendance:
        return AttendanceScreen(teacher: c.workspace.isStaff);
      case SchoolLinkKind.timetable:
        final slot = c.timetableItems.where((r) => r.id == entity).firstOrNull;
        return slot == null
            ? frame('Timetable', const ScheduleScreen())
            : RecordDetailScreen(record: slot, section: 'Timetable');
    }
  }
}
