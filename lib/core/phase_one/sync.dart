import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../roles.dart';
import 'models.dart';
import 'store.dart';

abstract interface class PhaseOneRemote {
  Future<List<RosterStudent>> roster(
    String school,
    String classId,
    String? after,
  );
  Future<Map<String, dynamic>> attendance(
    String school,
    Map<String, dynamic> change,
  );
  Future<Map<String, dynamic>> delta(String school, String? cursor);
  Future<List<SchoolNotice>> notices(String school, String? after);
  Future<void> receipt(String school, String noticeId, bool acknowledge);
  Future<void> publish(
    String school,
    String title,
    String body,
    bool important,
  );
}

class SupabasePhaseOneRemote implements PhaseOneRemote {
  final SupabaseClient client;
  SupabasePhaseOneRemote(this.client);
  @override
  Future<List<RosterStudent>> roster(
    String school,
    String classId,
    String? after,
  ) async =>
      ((await client.rpc(
            'erp_roster',
            params: {
              'p_school': school,
              'p_class': classId,
              'p_after': after,
              'p_limit': 100,
            },
          )) as List)
          .map(
            (m) => RosterStudent.fromJson(Map<String, dynamic>.from(m as Map)),
          )
          .toList();
  @override
  Future<Map<String, dynamic>> attendance(
    String school,
    Map<String, dynamic> change,
  ) async {
    final rows = await client.rpc(
      'erp_sync_attendance',
      params: {
        'p_school': school,
        'p_changes': [change],
      },
    ) as List;
    return Map<String, dynamic>.from(rows.single as Map);
  }

  @override
  Future<Map<String, dynamic>> delta(String school, String? cursor) async =>
      Map<String, dynamic>.from(
        await client.rpc(
          'erp_attendance_delta',
          params: {'p_school': school, 'p_cursor': cursor},
        ) as Map,
      );
  @override
  Future<List<SchoolNotice>> notices(String school, String? after) async =>
      ((await client.rpc(
            'erp_notices',
            params: {
              'p_school': school,
              'p_child': null,
              'p_after': after,
              'p_limit': 30,
            },
          )) as List)
          .map(
            (m) => SchoolNotice.fromJson(Map<String, dynamic>.from(m as Map)),
          )
          .toList();
  @override
  Future<void> receipt(String school, String noticeId, bool acknowledge) async {
    await client.rpc(
      'erp_notice_receipt',
      params: {
        'p_school': school,
        'p_notice': noticeId,
        'p_acknowledge': acknowledge,
      },
    );
  }

  @override
  Future<void> publish(
    String school,
    String title,
    String body,
    bool important,
  ) async {
    await client.rpc(
      'erp_publish_notice',
      params: {
        'p_school': school,
        'p_title': title,
        'p_body': body,
        'p_important': important,
      },
    );
  }
}

class PhaseOneController extends ChangeNotifier {
  final LocalSchoolStore store;
  final PhaseOneRemote remote;
  final String owner, school;
  final Workspace role;
  final DateTime Function() clock;
  late final String scope = store.scope(owner, school);
  SyncStatus status = SyncStatus.synced;
  int pendingCount = 0, blockedCount = 0;
  bool busy = false,
      active = true,
      rosterLoading = false,
      noticesLoading = false;
  String? error;
  List<RosterStudent> students = [];
  List<SchoolNotice> notices = [];
  Map<String, AttendanceEntry> entries = {};
  bool hasMoreNotices = false;
  String? _noticeCursor;
  Timer? _timer;
  Future<void>? _syncTask;
  final Future<void> Function()? scheduleBackground;
  Future<Map<String, dynamic>?> Function(QueuedOperation operation)?
  syncFeature;
  Future<void> Function()? afterSync;
  PhaseOneController({
    required this.store,
    required this.remote,
    required this.owner,
    required this.school,
    required this.role,
    DateTime Function()? clock,
    this.scheduleBackground,
  }) : clock = clock ?? DateTime.now;

  Future<void> initialize({
    bool periodic = true,
    bool synchronize = true,
  }) async {
    await reload();
    if (periodic) {
      _timer = Timer.periodic(
        const Duration(seconds: 45),
        (_) => unawaited(sync()),
      );
    }
    if (synchronize) unawaited(sync());
  }

  void changed() {
    if (active) notifyListeners();
  }

  Future<void> reload() async {
    if (!active) return;
    students =
        (await store.cached(
            scope,
            'roster',
          )).map(RosterStudent.fromJson).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    entries = {
      for (final m in await store.cached(scope, 'attendance'))
        '${m['student_id']}/${m['day']}': AttendanceEntry.fromJson(
          m,
          pending: m['_pending'] == true,
        ),
    };
    notices =
        (await store.cached(
          scope,
          'notice',
        )).map(SchoolNotice.fromJson).toList()..sort(
          (a, b) => a.important != b.important
              ? (a.important ? -1 : 1)
              : b.publishedAt.compareTo(a.publishedAt),
        );
    pendingCount = await store.pending(scope);
    blockedCount = await store.blocked(scope);
    if (status != SyncStatus.offline) {
      status = pendingCount == 0 ? SyncStatus.synced : SyncStatus.pending;
    }
    changed();
  }

  Future<void> loadRoster(String classId) async {
    if (!role.canMarkAttendance || !active || rosterLoading) return;
    rosterLoading = true;
    error = null;
    changed();
    try {
      final all = <RosterStudent>[];
      String? cursor;
      while (active) {
        final page = await remote.roster(school, classId, cursor);
        all.addAll(page);
        if (page.length < 100) break;
        final next = page.last.id;
        if (next == cursor || all.length > 10000) {
          throw StateError('Invalid roster pagination');
        }
        cursor = next;
      }
      if (active) await store.replaceRoster(scope, classId, all);
      status = SyncStatus.pending;
    } catch (_) {
      status = SyncStatus.offline;
      error = 'Couldn’t refresh this register. Previously downloaded students are available offline.';
    } finally {
      rosterLoading = false;
      await reload();
    }
  }

  AttendanceEntry draft(
    RosterStudent student,
    String day,
    AttendanceStatus status,
    AttendanceReason? reason,
  ) {
    final last = entries['${student.id}/$day']?.clientTime;
    final now = clock().toUtc();
    final time = last != null && !now.isAfter(last)
        ? last.add(const Duration(microseconds: 1))
        : now;
    return AttendanceEntry(
      studentId: student.id,
      classId: student.classId,
      day: day,
      operationId: operationId(),
      status: status,
      reason: status == AttendanceStatus.present ? null : reason,
      clientTime: time,
      pending: true,
    );
  }

  Future<void> mark(
    List<(RosterStudent, AttendanceStatus, AttendanceReason?)> changes,
    String day,
  ) async {
    if (!active || !role.canMarkAttendance) {
      throw StateError('Attendance access denied');
    }
    final authorized = students.map((e) => '${e.id}/${e.classId}').toSet();
    if (changes.any(
      (c) => !authorized.contains('${c.$1.id}/${c.$1.classId}'),
    )) {
      throw StateError('Student is outside the downloaded register');
    }
    await store.queueAttendance(
      scope,
      changes.map((c) => draft(c.$1, day, c.$2, c.$3)).toList(),
    );
    status = SyncStatus.pending;
    await reload();
    await scheduleBackground?.call();
    if (active) unawaited(sync());
  }

  Future<void> readNotice(
    SchoolNotice notice, {
    bool acknowledge = false,
  }) async {
    if (!active || !notices.any((n) => n.id == notice.id)) {
      throw StateError('Notice access denied');
    }
    if (notice.read && (!acknowledge || notice.acknowledged)) return;
    await store.queueReceipt(scope, notice, acknowledge);
    await reload();
    await scheduleBackground?.call();
    unawaited(sync());
  }

  Future<void> loadNotices({bool more = false}) async {
    if (!active || noticesLoading || (more && !hasMoreNotices)) return;
    noticesLoading = true;
    error = null;
    changed();
    try {
      final page = await remote.notices(school, more ? _noticeCursor : null);
      if (!active) return;
      await store.cacheNotices(scope, page);
      hasMoreNotices = page.length == 30;
      if (page.isNotEmpty) {
        final n = page.last;
        _noticeCursor =
            '${n.important ? 1 : 0}|${n.publishedAt.toUtc().toIso8601String()}|${n.id}';
      }
      status = SyncStatus.pending;
    } catch (_) {
      status = SyncStatus.offline;
      error =
          'Couldn’t refresh notices. Downloaded circulars remain available.';
    } finally {
      await reload();
      noticesLoading = false;
      changed();
    }
  }

  Future<void> publish(String title, String body, bool important) async {
    if (!role.canPublishNotices || !active) {
      throw StateError('Notice publishing denied');
    }
    await remote.publish(school, title, body, important);
    await loadNotices();
  }

  Future<void> sync({bool retryBlocked = false}) async {
    if (!active) return;
    if (_syncTask != null) return _syncTask;
    final task = _runSync(retryBlocked);
    _syncTask = task;
    try {
      await task;
    } finally {
      _syncTask = null;
    }
  }

  Future<void> _runSync(bool retryBlocked) async {
    busy = true;
    changed();
    try {
      if (retryBlocked) await store.retryBlocked(scope);
      for (final op in await store.due(scope, clock())) {
        if (!active) break;
        try {
          Map<String, dynamic>? authoritative;
          if (op.kind == 'attendance') {
            if (!role.canMarkAttendance) {
              throw const PostgrestException(
                message: 'Forbidden',
                code: '42501',
              );
            }
            authoritative = await remote.attendance(school, op.payload);
          } else if (op.kind == 'receipt') {
            await remote.receipt(
              school,
              op.payload['notice_id'] as String,
              op.payload['acknowledge'] == true,
            );
          } else if (syncFeature != null) {
            authoritative = await syncFeature!(op);
          } else {
            throw const PostgrestException(
              message: 'Unsupported queued operation',
              code: '22023',
            );
          }
          if (active) await store.accept(scope, op, authoritative);
        } catch (e) {
          final permanent =
              e is PostgrestException &&
              ['42501', '22023', '23503', '22P02'].contains(e.code);
          await store.fail(
            scope,
            op,
            permanent ? 'permission_or_validation' : 'network_or_server',
            clock(),
            permanent: permanent,
          );
          if (!permanent) rethrow;
        }
      }
      // Continue bounded delta pages; cursor commits with each page transaction.
      for (var page = 0; page < 20 && active; page++) {
        final data = await remote.delta(school, await store.cursor(scope));
        final records = (data['records'] as List)
            .map((m) => Map<String, dynamic>.from(m as Map))
            .toList();
        if (!active) break;
        await store.mergeAttendance(scope, records, data['cursor'] as String?);
        if (data['has_more'] != true) break;
      }
      status = SyncStatus.pending;
      if (active) await afterSync?.call();
    } catch (_) {
      status = SyncStatus.offline;
    } finally {
      busy = false;
      await reload();
    }
  }

  Future<void> close({bool purge = false}) async {
    active = false;
    _timer?.cancel();
    await _syncTask;
    if (purge) await store.purgeUser(owner);
    super.dispose();
  }
}
