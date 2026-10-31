import 'package:supabase_flutter/supabase_flutter.dart';

import '../data.dart';
import 'store.dart';

/// Context is cached per authenticated user, never shared with preview/accounts.
class CachedSchoolRepository implements SchoolRepository {
  final SchoolRepository remote;
  final String? Function() owner;
  final Future<LocalSchoolStore> Function() local;
  CachedSchoolRepository({
    required this.remote,
    required this.owner,
    required this.local,
  });
  @override
  Future<SchoolSnapshot> load() async {
    final user = owner();
    if (user == null) return const SchoolSnapshot();
    final db = await local();
    if (owner() != user) return const SchoolSnapshot();
    await db.activateUser(user);
    try {
      final snapshot = await remote.load();
      if (owner() != user) return const SchoolSnapshot();
      await db.saveContext(user, {
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        ...snapshot.toJson(),
      });
      return snapshot;
    } catch (e) {
      if (e is AuthException ||
          (e is PostgrestException &&
              ['42501', 'PGRST301', 'PGRST302'].contains(e.code))) {
        await db.purgeUser(user);
        rethrow;
      }
      final cached = await db.context(user);
      final saved = DateTime.tryParse(cached?['saved_at'] as String? ?? '');
      if (cached == null ||
          saved == null ||
          DateTime.now().toUtc().difference(saved) > const Duration(days: 7)) {
        rethrow;
      }
      return SchoolSnapshot.fromJson(cached);
    }
  }

  @override
  Future<void> saveItem(String collection, Map<String, dynamic> values) =>
      remote.saveItem(collection, values);
}
