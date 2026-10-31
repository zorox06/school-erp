import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'roles.dart';
import 'phase_one/models.dart';
import 'phase_one/store.dart';
import 'phase_one/sync.dart';

typedef SchoolRow = Map<String, dynamic>;

abstract interface class SchoolGateway {
  Future<dynamic> call(String name, SchoolRow parameters);
  Future<void> upload(String path, Uint8List bytes, String mime);
  Future<Uint8List> download(String path);
  Future<String> signedUrl(String path);
}

class SupabaseSchoolGateway implements SchoolGateway {
  final SupabaseClient client;
  SupabaseSchoolGateway(this.client);
  @override
  Future<dynamic> call(String name, SchoolRow parameters) =>
      client.rpc(name, params: parameters).timeout(const Duration(seconds: 20));
  @override
  Future<void> upload(String path, Uint8List bytes, String mime) async {
    try {
      await client.storage
          .from('school-files')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: mime, cacheControl: '0'),
          );
    } on StorageException catch (e) {
      if (e.statusCode != '409') rethrow;
    }
  }

  @override
  Future<Uint8List> download(String path) =>
      client.storage.from('school-files').download(path);
  @override
  Future<String> signedUrl(String path) =>
      client.storage.from('school-files').createSignedUrl(path, 120);
}

class SchoolFeatures extends ChangeNotifier {
  final PhaseOneController sync;
  final SchoolGateway gateway;
  final String owner, school;
  final Workspace role;
  final String timezone;
  String? childId;
  bool active = true, loading = false, offline = false;
  String? error;
  int conflicts = 0, _generation = 0;
  final Map<String, List<SchoolRow>> collections = {};
  SchoolRow preferences = {};
  final Map<String, String?> _cursors = {};
  final Map<String, bool> hasMore = {};
  SchoolFeatures({
    required this.sync,
    required this.gateway,
    required this.owner,
    required this.school,
    required this.role,
    required this.timezone,
  }) {
    sync.syncFeature = send;
    sync.afterSync = refresh;
  }
  LocalSchoolStore get store => sync.store;
  String get scope => sync.scope;
  String cacheKind(String kind) => '$kind/${childId ?? 'staff'}';
  List<SchoolRow> rows(String kind) => collections[kind] ?? const [];
  void changed() {
    if (active) notifyListeners();
  }

  static const kinds = [
    'homework',
    'worksheets',
    'assessments',
    'grades',
    'conversations',
    'contacts',
    'leaves',
    'submissions',
    'timetable',
  ];
  Future<void> selectChild(String? id) async {
    if (childId != id) {
      childId = id;
      _generation++;
      collections.clear();
      _cursors.clear();
      hasMore.clear();
      changed();
    }
    await loadCache();
    await refresh();
  }

  Future<void> loadCache() async {
    final generation = _generation;
    final selected = childId;
    final saved = <String, List<SchoolRow>>{};
    for (final kind in kinds) {
      saved[kind] = await store.cached(scope, '$kind/${selected ?? 'staff'}');
    }
    final settings = await store.cached(scope, 'preferences');
    if (!active || generation != _generation) return;
    collections.addAll(saved);
    if (settings.isNotEmpty) preferences = settings.first;
    changed();
  }

  Future<void> refresh() async {
    if (!active) return;
    final generation = _generation;
    final selected = childId;
    loading = true;
    error = null;
    changed();
    try {
      final result = Map<String, dynamic>.from(
        await gateway.call('erp_workspace', {
          'p_school': school,
          'p_child': selected,
        }) as Map,
      );
      if (!active || generation != _generation) return;
      final unread = Map<String, dynamic>.from(
        result['unread_counts'] as Map? ?? {},
      );
      for (final kind in kinds) {
        if (!active || generation != _generation) return;
        final values = ((result[kind] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (kind == 'conversations') {
          for (final r in values) {
            r['unread_count'] = unread[r['id']] ?? 0;
          }
        }
        await store.replaceCollection(
          scope,
          '$kind/${selected ?? 'staff'}',
          values,
          keyOf: kind == 'grades' ? gradeKey : null,
        );
        if (kind == 'conversations') hasMore[kind] = values.length == 100;
        if (kind == 'homework' || kind == 'worksheets') {
          hasMore[kind] = values.length == 30;
          if (values.isNotEmpty) {
            _cursors[kind] =
                '${values.last['created_at']}|${values.last['id']}';
          }
        }
      }
      final p = Map<String, dynamic>.from(result['preferences'] as Map? ?? {});
      final pending =
          (await store.cached(scope, 'preferences')).firstOrNull?['_pending'] ==
          true;
      if (!pending) await store.putCache(scope, 'preferences', 'settings', p);
      offline = false;
      await loadCache();
    } catch (e) {
      if (generation != _generation) return;
      offline = true;
      error = 'Updates are unavailable. Downloaded records and pending work remain on this device.';
      if (e is PostgrestException && e.code == '42501') {
        await store.purgeUser(owner);
        collections.clear();
        error = 'Your school access changed. Refresh your account before continuing.';
      }
    } finally {
      if (active && generation == _generation) {
        loading = false;
        changed();
      }
    }
  }

  static String gradeKey(SchoolRow r) =>
      '${r['assessment_id']}/${r['student_id']}';
  Future<void> moreLearning(String kind) async {
    if (loading || hasMore[kind] != true) return;
    final generation = _generation;
    final selected = childId;
    loading = true;
    changed();
    try {
      final raw = await gateway.call('erp_learning_page', {
        'p_school': school,
        'p_child': childId,
        'p_kind': kind == 'worksheets' ? 'worksheet' : 'homework',
        'p_after': _cursors[kind],
        'p_limit': 30,
      }) as List;
      if (!active || generation != _generation) return;
      final values = raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      for (final v in values) {
        await store.putCache(
          scope,
          '$kind/${selected ?? 'staff'}',
          v['id'] as String,
          v,
        );
      }
      hasMore[kind] = values.length == 30;
      if (values.isNotEmpty) {
        _cursors[kind] = '${values.last['created_at']}|${values.last['id']}';
      }
      await loadCache();
    } catch (_) {
      error = 'Couldn’t load more records.';
      offline = true;
    } finally {
      loading = false;
      changed();
    }
  }

  Future<void> loadGrades(String assessment) async {
    String? after;
    do {
      final raw = await gateway.call('erp_grade_page', {
        'p_school': school,
        'p_assessment': assessment,
        'p_after': after,
        'p_limit': 100,
      }) as List;
      for (final value in raw) {
        final r = Map<String, dynamic>.from(value as Map);
        final pending = (await store.cached(
          scope,
          cacheKind('grades'),
        )).any((e) => gradeKey(e) == gradeKey(r) && e['_pending'] == true);
        if (!pending) {
          await store.putCache(scope, cacheKind('grades'), gradeKey(r), r);
        }
      }
      after = raw.length == 100
          ? (raw.last as Map)['student_id'] as String
          : null;
    } while (active && after != null);
    await loadCache();
  }

  Future<void> moreConversations() async {
    if (loading || !active) return;
    final generation = _generation;
    final selected = childId;
    final current = rows('conversations');
    final last = current.isEmpty
        ? null
        : (List<SchoolRow>.from(current)..sort(
                (a, b) => '${b['created_at']}|${b['id']}'.compareTo(
                  '${a['created_at']}|${a['id']}',
                ),
              ))
              .last;
    loading = true;
    changed();
    try {
      final raw = await gateway.call('erp_conversations_page', {
        'p_school': school,
        'p_child': selected,
        'p_after': last == null ? null : '${last['created_at']}|${last['id']}',
        'p_limit': 40,
      }) as List;
      if (!active || generation != _generation) return;
      for (final item in raw) {
        final r = Map<String, dynamic>.from(item as Map);
        await store.putCache(
          scope,
          'conversations/${selected ?? 'staff'}',
          r['id'] as String,
          r,
        );
      }
      hasMore['conversations'] = raw.length == 40;
      await loadCache();
    } catch (_) {
      error = 'Couldn’t load more conversations.';
    } finally {
      loading = false;
      changed();
    }
  }

  Future<void> queue(
    String kind,
    SchoolRow payload, {
    String? collection,
    String? key,
    SchoolRow? optimistic,
  }) async {
    if (!active) throw StateError('Account is no longer active');
    if ([
          'homework',
          'worksheet',
          'assessment',
          'grade',
          'feedback',
          'timetable',
        ].contains(kind) &&
        !role.isStaff) {
      throw StateError('Staff action required');
    }
    if (['emergency', 'staff_attendance'].contains(kind) &&
        !role.isLeadership) {
      throw StateError('Leadership action required');
    }
    if (kind == 'leave_decision' && !role.isStaff) {
      throw StateError('Staff action required');
    }
    if (kind == 'leave' && role != Workspace.parent) {
      throw StateError('Guardian action required');
    }
    if (kind == 'submission' && !role.canSubmitWork) {
      throw StateError('Family action required');
    }
    final id = operationId();
    final data = {...payload, '_view_child': childId};
    await store.queueFeature(
      scope,
      kind,
      id,
      data,
      cacheKind: collection == null ? null : cacheKind(collection),
      cacheKey: key ?? id,
      optimistic: optimistic == null
          ? null
          : {
              ...optimistic,
              'id': optimistic['id'] ?? id,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            },
    );
    await loadCache();
    await sync.reload();
    if (sync.scheduleBackground != null) await sync.scheduleBackground!();
    unawaited(sync.sync());
  }

  Future<Map<String, dynamic>?> send(QueuedOperation op) async {
    final payload = {...op.payload}..removeWhere((k, v) => k.startsWith('_'));
    final attachments = (payload.remove('attachments') as List?) ?? [];
    final assetIds = <String>[];
    for (final value in attachments) {
      final file = Map<String, dynamic>.from(value as Map);
      final localFile = File(file['path'] as String);
      if (!await localFile.exists()) {
        throw const PostgrestException(
          message: 'Local attachment is missing. Attach it again.',
          code: '22023',
        );
      }
      final bytes = await localFile.readAsBytes();
      if (bytes.length != file['bytes'] || bytes.length > 10485760) {
        throw const PostgrestException(
          message: 'Attachment unavailable or changed',
          code: '22023',
        );
      }
      final linked = op.kind == 'submission'
          ? payload['homework_id']
          : (payload['class_ids'] as List).first;
      final path = await gateway.call('erp_reserve_asset', {
        'p_school': school,
        'p_asset': file['id'],
        'p_kind': op.kind,
        'p_linked': linked,
        'p_mime': file['mime'],
        'p_bytes': bytes.length,
      }) as String;
      await gateway.upload(path, bytes, file['mime'] as String);
      await gateway.call('erp_finish_asset', {
        'p_school': school,
        'p_asset': file['id'],
      });
      assetIds.add(file['id'] as String);
    }
    if (attachments.isNotEmpty) payload['asset_ids'] = assetIds;
    if (op.kind == 'preferences') {
      await gateway.call('erp_save_preferences', {
        'p_school': school,
        'p_preferences': payload,
      });
      return payload;
    }
    final result = Map<String, dynamic>.from(
      await gateway.call(
        [
              'leave_decision',
              'emergency',
              'timetable_change',
              'staff_attendance',
            ].contains(op.kind)
            ? 'erp_action'
            : 'erp_write',
        {
          'p_school': school,
          'p_kind': op.kind,
          'p_operation': op.operationId,
          'p_payload': payload,
        },
      ) as Map,
    );
    if (result['conflict'] == true) {
      conflicts++;
      error = 'A newer school mark was kept. Review the current mark before editing again.';
      changed();
    }
    return result['record'] == null
        ? null
        : Map<String, dynamic>.from(result['record'] as Map);
  }

  Future<List<SchoolRow>> messages(String conversation, {String? after}) async {
    final kind = 'messages/$conversation';
    try {
      final result = await gateway.call('erp_messages_page', {
        'p_school': school,
        'p_conversation': conversation,
        'p_after': after,
        'p_limit': 40,
      }) as List;
      for (final item in result) {
        final r = Map<String, dynamic>.from(item as Map);
        await store.putCache(scope, kind, r['id'] as String, r);
      }
      hasMore[kind] = result.length == 40;
      if (result.isNotEmpty) {
        final r = result.last as Map;
        _cursors[kind] = '${r['created_at']}|${r['id']}';
      }
    } catch (_) {
      offline = true;
    }
    if (after == null) {
      try {
        await gateway.call('erp_read_conversation', {
          'p_school': school,
          'p_conversation': conversation,
        });
      } catch (_) {}
    }
    final cached = await store.cached(scope, kind);
    cached.sort(
      (a, b) =>
          (a['created_at'] as String).compareTo(b['created_at'] as String),
    );
    return cached;
  }

  String? messageCursor(String conversation) =>
      _cursors['messages/$conversation'];
  Future<void> sendMessage(String conversation, String body) async {
    final id = operationId();
    await store.queueFeature(
      scope,
      'message',
      id,
      {'conversation_id': conversation, 'body': body},
      cacheKind: 'messages/$conversation',
      cacheKey: id,
      optimistic: {
        'id': id,
        'sender_id': owner,
        'body': body,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
    await sync.reload();
    unawaited(sync.sync());
    if (sync.scheduleBackground != null) await sync.scheduleBackground!();
  }

  Future<void> savePreferences(SchoolRow value) async {
    final p = {...preferences, ...value, 'timezone': timezone}
      ..removeWhere(
        (k, v) =>
            k.startsWith('_') || ['school_id', 'user_id', 'id'].contains(k),
      );
    await store.queueFeature(
      scope,
      'preferences',
      operationId(),
      p,
      cacheKind: 'preferences',
      cacheKey: 'settings',
      optimistic: p,
    );
    preferences = p;
    changed();
    await sync.reload();
    unawaited(sync.sync());
    if (sync.scheduleBackground != null) await sync.scheduleBackground!();
  }

  Future<void> close() async {
    active = false;
    _generation++;
    sync.afterSync = null;
    super.dispose();
  }
}
