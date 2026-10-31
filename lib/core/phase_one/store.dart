import 'package:flutter/foundation.dart';

import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'models.dart';

String operationId() {
  final r = Random.secure();
  final b = List.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final s = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

class LocalSchoolStore {
  final Database db;
  LocalSchoolStore(this.db);
  static Future<LocalSchoolStore> open({
    DatabaseFactory? factory,
    String? location,
  }) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      location ?? path.join(await f.getDatabasesPath(), 'schoolday-offline.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE revoked_users (owner TEXT PRIMARY KEY)',
          );
          await db.execute(
            'CREATE TABLE context (owner TEXT PRIMARY KEY, payload TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE cache (scope TEXT NOT NULL, kind TEXT NOT NULL, item_key TEXT NOT NULL, payload TEXT NOT NULL, pending INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(scope,kind,item_key))',
          );
          await db.execute(
            'CREATE TABLE outbox (scope TEXT NOT NULL, item_key TEXT NOT NULL, operation_id TEXT NOT NULL, kind TEXT NOT NULL, payload TEXT NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, next_attempt INTEGER NOT NULL DEFAULT 0, blocked INTEGER NOT NULL DEFAULT 0, PRIMARY KEY(scope,item_key))',
          );
          await db.execute(
            'CREATE TABLE cursors (scope TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE sync_failures (id INTEGER PRIMARY KEY AUTOINCREMENT, scope TEXT NOT NULL, category TEXT NOT NULL, at INTEGER NOT NULL)',
          );
          for (final table in ['cache', 'outbox', 'cursors', 'sync_failures']) {
            await db.execute(
              "CREATE TRIGGER guard_${table}_logout BEFORE INSERT ON $table WHEN EXISTS(SELECT 1 FROM revoked_users WHERE owner=substr(NEW.scope,1,instr(NEW.scope,':')-1)) BEGIN SELECT RAISE(IGNORE); END",
            );
          }
          await db.execute(
            'CREATE TRIGGER guard_context_logout BEFORE INSERT ON context WHEN EXISTS(SELECT 1 FROM revoked_users WHERE owner=NEW.owner) BEGIN SELECT RAISE(IGNORE); END',
          );
        },
      ),
    );
    return LocalSchoolStore(db);
  }

  String scope(String owner, String school) => '$owner:$school';
  Future<void> activateUser(String owner) => db
      .delete('revoked_users', where: 'owner=?', whereArgs: [owner])
      .then((_) {});
  Future<void> saveContext(String owner, Map<String, dynamic> value) => db
      .insert('context', {
        'owner': owner,
        'payload': jsonEncode(value),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<Map<String, dynamic>?> context(String owner) async {
    final rows = await db.query(
      'context',
      where: 'owner=?',
      whereArgs: [owner],
    );
    return rows.isEmpty
        ? null
        : jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
  }

  Future<void> purgeUser(String owner) => db.transaction((tx) async {
    await tx.insert('revoked_users', {
      'owner': owner,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await tx.delete('context', where: 'owner=?', whereArgs: [owner]);
    for (final table in ['cache', 'outbox', 'cursors', 'sync_failures']) {
      await tx.delete(table, where: 'scope LIKE ?', whereArgs: ['$owner:%']);
    }
  });
  Future<List<Map<String, dynamic>>> cached(String scope, String kind) async {
    final rows = await db.query(
      'cache',
      where: 'scope=? AND kind=?',
      whereArgs: [scope, kind],
    );
    if (rows.length > 100) return compute(_decodeCacheRows, rows);
    return _decodeCacheRows(rows);
  }

  Future<void> putCache(
    String scope,
    String kind,
    String key,
    Map<String, dynamic> payload,
  ) => db
      .insert('cache', {
        'scope': scope,
        'kind': kind,
        'item_key': key,
        'payload': jsonEncode(payload),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<void> cacheRoster(String scope, List<RosterStudent> students) =>
      db.transaction((tx) async {
        for (final s in students) {
          await tx.insert('cache', {
            'scope': scope,
            'kind': 'roster',
            'item_key': s.id,
            'payload': jsonEncode(s.toJson()),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
  Future<void> replaceRoster(
    String scope,
    String classId,
    List<RosterStudent> students,
  ) => db.transaction((tx) async {
    final current = await tx.query(
      'cache',
      where: 'scope=? AND kind=?',
      whereArgs: [scope, 'roster'],
    );
    for (final row in current) {
      if ((jsonDecode(row['payload'] as String) as Map)['class_id'] ==
          classId) {
        await tx.delete(
          'cache',
          where: 'scope=? AND kind=? AND item_key=?',
          whereArgs: [scope, 'roster', row['item_key']],
        );
      }
    }
    for (final s in students) {
      await tx.insert('cache', {
        'scope': scope,
        'kind': 'roster',
        'item_key': s.id,
        'payload': jsonEncode(s.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  });
  Future<void> queueAttendance(String scope, List<AttendanceEntry> entries) =>
      db.transaction((tx) async {
        for (final e in entries) {
          final payload = jsonEncode(e.toJson());
          await tx.insert('cache', {
            'scope': scope,
            'kind': 'attendance',
            'item_key': e.key,
            'payload': payload,
            'pending': 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          await tx.insert('outbox', {
            'scope': scope,
            'item_key': e.key,
            'operation_id': e.operationId,
            'kind': 'attendance',
            'payload': payload,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
  Future<void> replaceCollection(
    String scope,
    String kind,
    List<Map<String, dynamic>> rows, {
    String Function(Map<String, dynamic>)? keyOf,
  }) => db.transaction((tx) async {
    await tx.delete(
      'cache',
      where: 'scope=? AND kind=? AND pending=0',
      whereArgs: [scope, kind],
    );
    for (final row in rows) {
      final key = keyOf?.call(row) ?? row['id'] as String;
      final pending = await tx.query(
        'cache',
        columns: ['pending'],
        where: 'scope=? AND kind=? AND item_key=?',
        whereArgs: [scope, kind, key],
      );
      if (pending.firstOrNull?['pending'] == 1) continue;
      await tx.insert('cache', {
        'scope': scope,
        'kind': kind,
        'item_key': key,
        'payload': jsonEncode(row),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  });
  Future<void> queueFeature(
    String scope,
    String kind,
    String id,
    Map<String, dynamic> payload, {
    String? cacheKind,
    String? cacheKey,
    Map<String, dynamic>? optimistic,
  }) => db.transaction((tx) async {
    final values = {
      ...payload,
      '_cache_kind': ?cacheKind,
      '_cache_key': ?cacheKey,
    };
    if (cacheKind != null && optimistic != null) {
      await tx.insert('cache', {
        'scope': scope,
        'kind': cacheKind,
        'item_key': cacheKey ?? id,
        'payload': jsonEncode(optimistic),
        'pending': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await tx.insert('outbox', {
      'scope': scope,
      'item_key': '$kind/${cacheKey ?? id}',
      'operation_id': id,
      'kind': kind,
      'payload': jsonEncode(values),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
  Future<void> queueReceipt(
    String scope,
    SchoolNotice notice,
    bool acknowledge,
  ) => db.transaction((tx) async {
    final rows = await tx.query(
      'cache',
      where: 'scope=? AND kind=? AND item_key=?',
      whereArgs: [scope, 'notice', notice.id],
    );
    final previous = rows.isEmpty
        ? notice.toJson()
        : jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
    final payload = {
      'notice_id': notice.id,
      'acknowledge': acknowledge || previous['acknowledged'] == true,
    };
    await tx.insert('cache', {
      'scope': scope,
      'kind': 'notice',
      'item_key': notice.id,
      'payload': jsonEncode({
        ...previous,
        'read': true,
        'acknowledged': payload['acknowledge'],
      }),
      'pending': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await tx.insert('outbox', {
      'scope': scope,
      'item_key': 'notice/${notice.id}',
      'operation_id': operationId(),
      'kind': 'receipt',
      'payload': jsonEncode(payload),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  });
  Future<List<QueuedOperation>> due(String scope, DateTime now) async =>
      (await db.query(
        'outbox',
        where: 'scope=? AND blocked=0 AND next_attempt<=?',
        whereArgs: [scope, now.millisecondsSinceEpoch],
        orderBy: 'next_attempt, item_key',
        limit: 50,
      )).map(QueuedOperation.fromRow).toList();
  Future<int> pending(String scope) async =>
      Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM outbox WHERE scope=?', [scope]),
      ) ??
      0;
  Future<int> blocked(String scope) async =>
      Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM outbox WHERE scope=? AND blocked=1',
          [scope],
        ),
      ) ??
      0;
  Future<void> accept(
    String scope,
    QueuedOperation sent,
    Map<String, dynamic>? authoritative,
  ) => db.transaction((tx) async {
    final removed = await tx.delete(
      'outbox',
      where: 'scope=? AND item_key=? AND operation_id=?',
      whereArgs: [scope, sent.key, sent.operationId],
    );
    // A newer local edit made while this request was in flight must survive.
    if (removed == 0) return;
    final kind = sent.kind == 'attendance'
        ? 'attendance'
        : sent.kind == 'receipt'
        ? 'notice'
        : sent.payload['_cache_kind'] as String?;
    final key = sent.kind == 'attendance'
        ? sent.key
        : sent.kind == 'receipt'
        ? sent.payload['notice_id']
        : sent.payload['_cache_key'] ?? sent.operationId;
    if (kind == null) return;
    if (authoritative != null) {
      await tx.insert('cache', {
        'scope': scope,
        'kind': kind,
        'item_key': key,
        'payload': jsonEncode(authoritative),
        'pending': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await tx.update(
        'cache',
        {'pending': 0},
        where: 'scope=? AND kind=? AND item_key=?',
        whereArgs: [scope, kind, key],
      );
    }
  });
  Future<void> mergeAttendance(
    String scope,
    List<Map<String, dynamic>> records,
    String? cursor,
  ) => db.transaction((tx) async {
    for (final r in records) {
      final e = AttendanceEntry.fromJson(r);
      final local = await tx.query(
        'cache',
        where: 'scope=? AND kind=? AND item_key=? AND pending=1',
        whereArgs: [scope, 'attendance', e.key],
      );
      if (local.isEmpty) {
        await tx.insert('cache', {
          'scope': scope,
          'kind': 'attendance',
          'item_key': e.key,
          'payload': jsonEncode(r),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    if (cursor != null) {
      await tx.insert('cursors', {
        'scope': scope,
        'value': cursor,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  });
  Future<String?> cursor(String scope) async {
    final r = await db.query('cursors', where: 'scope=?', whereArgs: [scope]);
    return r.firstOrNull?['value'] as String?;
  }

  Future<void> fail(
    String scope,
    QueuedOperation op,
    String category,
    DateTime now, {
    bool permanent = false,
  }) => db.transaction((tx) async {
    final attempts = op.attempts + 1;
    final delay = min(3600, 15 * pow(2, min(attempts, 8)).toInt());
    await tx.update(
      'outbox',
      {
        'attempts': attempts,
        'blocked': permanent ? 1 : 0,
        'next_attempt': now
            .add(Duration(seconds: delay))
            .millisecondsSinceEpoch,
      },
      where: 'scope=? AND item_key=? AND operation_id=?',
      whereArgs: [scope, op.key, op.operationId],
    );
    // Never store message bodies, tokens, student names or raw server errors in logs.
    await tx.insert('sync_failures', {
      'scope': scope,
      'category': category,
      'at': now.millisecondsSinceEpoch,
    });
    await tx.rawDelete(
      'DELETE FROM sync_failures WHERE scope=? AND id NOT IN (SELECT id FROM sync_failures WHERE scope=? ORDER BY id DESC LIMIT 100)',
      [scope, scope],
    );
  });
  Future<void> retryBlocked(String scope) => db
      .update(
        'outbox',
        {'blocked': 0, 'next_attempt': 0},
        where: 'scope=?',
        whereArgs: [scope],
      )
      .then((_) {});
}

List<Map<String, dynamic>> _decodeCacheRows(List<Map<String, Object?>> rows) =>
    rows
        .map(
          (r) => <String, dynamic>{
            ...jsonDecode(r['payload'] as String) as Map<String, dynamic>,
            '_pending': r['pending'] == 1,
          },
        )
        .toList();
