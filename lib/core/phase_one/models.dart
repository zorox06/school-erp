import 'dart:convert';

enum AttendanceStatus { present, absent, late, leave }

enum AttendanceReason { sick, excused, unexcused }

enum SyncStatus { synced, pending, offline }

class RosterStudent {
  final String id, classId, name;
  final String? roll;
  const RosterStudent({
    required this.id,
    required this.classId,
    required this.name,
    this.roll,
  });
  factory RosterStudent.fromJson(Map<String, dynamic> m) => RosterStudent(
    id: m['id'] as String,
    classId: m['class_id'] as String,
    name: m['name'] as String? ?? 'Student',
    roll: m['roll'] as String?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'class_id': classId,
    'name': name,
    'roll': roll,
  };
}

class AttendanceEntry {
  final String studentId, classId, day, operationId;
  final AttendanceStatus status;
  final AttendanceReason? reason;
  final DateTime clientTime;
  final bool pending;
  const AttendanceEntry({
    required this.studentId,
    required this.classId,
    required this.day,
    required this.operationId,
    required this.status,
    required this.clientTime,
    this.reason,
    this.pending = false,
  });
  String get key => '$studentId/$day';
  factory AttendanceEntry.fromJson(
    Map<String, dynamic> m, {
    bool pending = false,
  }) => AttendanceEntry(
    studentId: m['student_id'] as String,
    classId: m['class_id'] as String,
    day: m['day'] as String,
    operationId: m['operation_id'] as String,
    status: AttendanceStatus.values.byName(m['status'] as String),
    reason: m['reason'] == null
        ? null
        : AttendanceReason.values.byName(m['reason'] as String),
    clientTime: DateTime.parse(m['client_time'] as String).toUtc(),
    pending: pending,
  );
  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'class_id': classId,
    'day': day,
    'operation_id': operationId,
    'status': status.name,
    'reason': reason?.name,
    'client_time': clientTime.toUtc().toIso8601String(),
  };
}

class SchoolNotice {
  final String id, title, body;
  final bool important, acknowledged, read;
  final DateTime publishedAt;
  const SchoolNotice({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
    this.important = false,
    this.acknowledged = false,
    this.read = false,
  });
  factory SchoolNotice.fromJson(Map<String, dynamic> m) => SchoolNotice(
    id: m['id'] as String,
    title: m['title'] as String,
    body: m['body'] as String,
    publishedAt: DateTime.parse(m['published_at'] as String),
    important: m['important'] == true,
    acknowledged: m['acknowledged'] == true,
    read: m['read'] == true,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'published_at': publishedAt.toUtc().toIso8601String(),
    'important': important,
    'acknowledged': acknowledged,
    'read': read,
  };
}

class QueuedOperation {
  final String key, operationId, kind;
  final Map<String, dynamic> payload;
  final int attempts;
  const QueuedOperation(
    this.key,
    this.operationId,
    this.kind,
    this.payload,
    this.attempts,
  );
  factory QueuedOperation.fromRow(Map<String, Object?> r) => QueuedOperation(
    r['item_key'] as String,
    r['operation_id'] as String,
    r['kind'] as String,
    jsonDecode(r['payload'] as String) as Map<String, dynamic>,
    r['attempts'] as int,
  );
}
