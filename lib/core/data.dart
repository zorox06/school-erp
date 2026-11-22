import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'roles.dart';
import 'phase_one/sync.dart';
import 'school_features.dart';
export 'roles.dart';

class SchoolRecord {
  final String id;
  final String? title, description, category, status;
  final DateTime? date;
  final Map<String, dynamic> fields;
  const SchoolRecord({
    required this.id,
    this.title,
    this.description,
    this.category,
    this.status,
    this.date,
    this.fields = const {},
  });
  factory SchoolRecord.fromJson(Map<String, dynamic> v) => SchoolRecord(
    id: v['id'] as String,
    title: v['title'] as String?,
    description: (v['description'] ?? v['body']) as String?,
    category: v['category'] as String?,
    status: v['status'] as String?,
    date: DateTime.tryParse((v['date'] ?? v['due_at'])?.toString() ?? ''),
    fields: v,
  );
}

class SchoolSnapshot {
  factory SchoolSnapshot.fromJson(Map<String, dynamic> m) {
    List<SchoolRecord> records(String key) => ((m[key] as List?) ?? [])
        .map((e) => SchoolRecord.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return SchoolSnapshot(
      schoolId: m['school_id'] as String?,
      schoolName: m['school_name'] as String?,
      displayName: m['display_name'] as String?,
      role: parseWorkspace(m['role']),
      children: records('children'),
      classes: records('classes'),
      homework: records('homework'),
      worksheets: records('worksheets'),
      timetable: records('timetable'),
      attendance: records('attendance'),
      news: records('news'),
      events: records('events'),
      conversations: records('conversations'),
      invoices: records('invoices'),
      notifications: records('notifications'),
    );
  }
  Map<String, dynamic> toJson() {
    List<Map<String, dynamic>> records(List<SchoolRecord> r) => r
        .map(
          (e) => {
            ...e.fields,
            'id': e.id,
            'title': e.title,
            'description': e.description,
            'category': e.category,
            'status': e.status,
            'date': e.date?.toIso8601String(),
          },
        )
        .toList();
    return {
      'school_id': schoolId,
      'school_name': schoolName,
      'display_name': displayName,
      'role': role?.name,
      'children': records(children),
      'classes': records(classes),
      'homework': records(homework),
      'worksheets': records(worksheets),
      'timetable': records(timetable),
      'attendance': records(attendance),
      'news': records(news),
      'events': records(events),
      'conversations': records(conversations),
      'invoices': records(invoices),
      'notifications': records(notifications),
    };
  }

  final String? schoolId, schoolName, displayName;
  final Workspace? role;
  final List<SchoolRecord> children,
      classes,
      homework,
      worksheets,
      timetable,
      attendance,
      news,
      events,
      conversations,
      invoices,
      notifications;
  const SchoolSnapshot({
    this.schoolId,
    this.schoolName,
    this.displayName,
    this.role,
    this.children = const [],
    this.classes = const [],
    this.homework = const [],
    this.worksheets = const [],
    this.timetable = const [],
    this.attendance = const [],
    this.news = const [],
    this.events = const [],
    this.conversations = const [],
    this.invoices = const [],
    this.notifications = const [],
  });
}

abstract interface class SchoolRepository {
  Future<SchoolSnapshot> load();
  Future<void> saveItem(String collection, Map<String, dynamic> values);
}

class EmptySchoolRepository implements SchoolRepository {
  const EmptySchoolRepository();
  @override
  Future<SchoolSnapshot> load() async => const SchoolSnapshot();
  @override
  Future<void> saveItem(String collection, Map<String, dynamic> values) async =>
      throw const SchoolDataUnavailable();
}

class SchoolDataUnavailable implements Exception {
  const SchoolDataUnavailable();
  @override
  String toString() =>
      'Your school needs to connect your account before you can save changes.';
}

/// Replace this adapter to move to a custom REST API without rebuilding the UI.
/// It is disabled by default: no school data is fetched or written in this build.
class SupabaseSchoolRepository implements SchoolRepository {
  final SupabaseClient client;
  SupabaseSchoolRepository(this.client);
  @override
  Future<SchoolSnapshot> load() async {
    if (client.auth.currentUser == null) return const SchoolSnapshot();
    final result = await client.rpc('mobile_context');
    if (result == null) return const SchoolSnapshot();
    final m = Map<String, dynamic>.from(result as Map);
    return compute(SchoolSnapshot.fromJson, m);
  }

  @override
  Future<void> saveItem(String collection, Map<String, dynamic> values) async =>
      client.rpc(
        'mobile_create_item',
        params: {'item_kind': collection, 'item_data': values},
      );
}

abstract interface class AuthRepository {
  String? get userId;
  bool get configured;
  String? get email;
  bool get signedIn;
  Workspace? get assignedWorkspace;
  Stream<bool> get changes;
  Future<void> signIn(String email, String password);
  Future<void> resetPassword(String email);
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient? client;
  SupabaseAuthRepository(this.client);
  @override
  String? get userId => client?.auth.currentUser?.id;
  @override
  bool get configured => client != null;
  @override
  String? get email => client?.auth.currentUser?.email;
  @override
  bool get signedIn => client?.auth.currentSession != null;
  @override
  Workspace? get assignedWorkspace {
    // Trusted app_metadata only; never use editable user_metadata for roles.
    final role = client?.auth.currentUser?.appMetadata['workspace'];
    return parseWorkspace(role);
  }

  @override
  Stream<bool> get changes =>
      client?.auth.onAuthStateChange.map((e) => e.session != null) ??
      const Stream.empty();
  @override
  Future<void> signIn(String email, String password) async {
    if (client == null) {
      throw const AuthException(
        'Account services are temporarily unavailable.',
      );
    }
    await client!.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> resetPassword(String email) async {
    if (client == null) {
      throw const AuthException(
        'Account services are temporarily unavailable.',
      );
    }
    await client!.auth.resetPasswordForEmail(email.trim());
  }

  @override
  Future<void> signOut() async {
    await client?.auth.signOut(scope: SignOutScope.local);
  }
}

class AppController extends ChangeNotifier {
  final Future<PhaseOneController> Function(
    String owner,
    String school,
    Workspace role,
  )?
  createPhaseOne;
  final Future<void> Function(String? owner)? onLeaving;
  final Future<String?> Function(bool enabled)? updatePush;
  String? pushStatus;
  PhaseOneController? phaseOne;
  SchoolFeatures? features;
  Future<SchoolFeatures> Function(PhaseOneController sync)? createFeatures;
  void _featureChanged() {
    if (!_disposed) notifyListeners();
  }

  int _refreshVersion = 0;
  bool _disposed = false;
  bool signingOut = false;
  bool notificationsBusy = false;
  bool dataSaver = false;
  bool widgetEnabled = false;
  Future<void> setWidgets(bool v) async {
    widgetEnabled = v;
    await (await SharedPreferences.getInstance()).setBool("widgets", v);
    notifyListeners();
  }

  Future<void> setDataSaver(bool v) async {
    dataSaver = v;
    await (await SharedPreferences.getInstance()).setBool("dataSaver", v);
    notifyListeners();
  }

  bool get accessAssigned => liveDataEnabled
      ? _snapshot.schoolId != null && _snapshot.role != null
      : _snapshot.role != null || auth.assignedWorkspace != null;
  final AuthRepository auth;
  final SchoolRepository repository;
  final bool liveDataEnabled;
  SchoolSnapshot _snapshot = const SchoolSnapshot();
  set snapshot(SchoolSnapshot value) => _snapshot = value;
  SchoolSnapshot get snapshot {
    if (workspace != Workspace.parent || _snapshot.invoices.isEmpty) {
      return _snapshot;
    }
    return SchoolSnapshot.fromJson({
      ..._snapshot.toJson(),
      'invoices': _snapshot.invoices
          .where(
            (r) =>
                (r.fields['student_id'] ??
                        r.fields['child_id'] ??
                        (r.fields['data'] as Map?)?['child_id']) ==
                    selectedChildId &&
                selectedChildId != null,
          )
          .map(
            (r) => {
              ...r.fields,
              'id': r.id,
              'title': r.title,
              'status': r.status,
            },
          )
          .toList(),
    });
  }

  Workspace workspace = Workspace.parent;
  bool loading = false, notificationsEnabled = false, compactView = false;
  String? loadError, selectedChildId, selectedClassId;
  StreamSubscription<bool>? _subscription;
  SharedPreferences? _preferences;
  AppController({
    required this.auth,
    required this.repository,
    this.liveDataEnabled = false,
    this.createPhaseOne,
    this.onLeaving,
    this.updatePush,
  });
  bool get entered => auth.signedIn;
  List<SchoolRecord> learningItems(bool worksheet) {
    if (features == null) {
      return worksheet ? snapshot.worksheets : snapshot.homework;
    }
    return features!
        .rows(worksheet ? 'worksheets' : 'homework')
        .map(
          (r) => SchoolRecord.fromJson({
            ...r,
            'status': r['_pending'] == true
                ? 'pending'
                : r['submission'] is Map
                ? ((r['submission'] as Map)['feedback'] == null
                      ? 'submitted'
                      : 'reviewed')
                : r['status'],
          }),
        )
        .toList();
  }

  List<SchoolRecord> get timetableItems => features == null
      ? snapshot.timetable
      : features!
            .rows('timetable')
            .map(
              (r) => SchoolRecord.fromJson({
                ...r,
                ...Map<String, dynamic>.from(r['data'] as Map? ?? {}),
              }),
            )
            .toList();
  bool get canWrite =>
      auth.signedIn &&
      liveDataEnabled &&
      snapshot.schoolId != null &&
      snapshot.role != null;
  Future<void> initialize() async {
    _preferences = await SharedPreferences.getInstance();
    notificationsEnabled =
        _preferences?.getBool('notification_preference') ?? false;
    compactView = _preferences?.getBool('compact_view') ?? false;
    _subscription = auth.changes.listen((active) async {
      if (_disposed) return;
      if (!active) {
        _refreshVersion++;
        final old = phaseOne;
        final oldFeatures = features;
        features = null;
        oldFeatures?.removeListener(_featureChanged);
        unawaited(oldFeatures?.close());
        phaseOne = null;
        await old?.close(purge: true);
        if (!signingOut) await onLeaving?.call(old?.owner);
        if (_disposed || auth.signedIn) return;
        snapshot = const SchoolSnapshot();
        selectedChildId = null;
        selectedClassId = null;
        notifyListeners();
      } else {
        await refresh();
      }
    });
    if (auth.signedIn) await refresh();
  }

  Future<void> refresh() async {
    if (!auth.signedIn || signingOut) return;
    loading = true;
    final version = ++_refreshVersion;
    final owner = auth.userId;
    loadError = null;
    notifyListeners();
    try {
      final loaded = await repository.load();
      if (_disposed || version != _refreshVersion || owner != auth.userId) {
        return;
      }
      final previousSchool = _snapshot.schoolId;
      final previousRole = _snapshot.role;
      final previousChild = selectedChildId;
      snapshot = loaded;
      workspace = snapshot.role ?? auth.assignedWorkspace ?? Workspace.parent;
      if (phaseOne != null &&
          (phaseOne!.owner != auth.userId ||
              phaseOne!.school != snapshot.schoolId ||
              phaseOne!.role != workspace)) {
        final old = phaseOne!;
        final oldFeatures = features;
        features = null;
        oldFeatures?.removeListener(_featureChanged);
        await oldFeatures?.close();
        phaseOne = null;
        await old.close(purge: true);
      }
      if (phaseOne == null &&
          liveDataEnabled &&
          snapshot.schoolId != null &&
          auth.userId != null &&
          createPhaseOne != null) {
        final created = await createPhaseOne!(
          auth.userId!,
          snapshot.schoolId!,
          workspace,
        );
        if (_disposed || version != _refreshVersion || owner != auth.userId) {
          await created.close(purge: true);
          return;
        }
        phaseOne = created;
      }
      selectedChildId = snapshot.children.any((e) => e.id == selectedChildId)
          ? selectedChildId
          : snapshot.children.firstOrNull?.id;
      if (previousSchool != null &&
          (previousSchool != loaded.schoolId ||
              previousRole != loaded.role ||
              previousChild != selectedChildId)) {
        onChildChanged?.call();
      }
      selectedClassId = snapshot.classes.any((e) => e.id == selectedClassId)
          ? selectedClassId
          : snapshot.classes.firstOrNull?.id;
      if (features == null && phaseOne != null && createFeatures != null) {
        final next = await createFeatures!(phaseOne!);
        if (_disposed || version != _refreshVersion || owner != auth.userId) {
          await next.close();
          return;
        }
        features = next;
        next.addListener(_featureChanged);
        unawaited(phaseOne!.sync());
        await next.selectChild(selectedChildId);
      } else if (features != null) {
        await features!.selectChild(selectedChildId);
      }
    } catch (e) {
      if (_disposed || version != _refreshVersion || owner != auth.userId) {
        return;
      }
      if (e is AuthException ||
          (e is PostgrestException &&
              ['42501', 'PGRST301', 'PGRST302'].contains(e.code))) {
        onChildChanged?.call();
        snapshot = const SchoolSnapshot();
        selectedChildId = null;
        selectedClassId = null;
        final old = phaseOne;
        final oldFeatures = features;
        features = null;
        oldFeatures?.removeListener(_featureChanged);
        await oldFeatures?.close();
        phaseOne = null;
        await old?.close(purge: true);
      }
      loadError = 'We couldn’t load your school updates. Please try again.';
    } finally {
      if (!_disposed && version == _refreshVersion) {
        loading = false;
        notifyListeners();
      }
    }
  }

  VoidCallback? onChildChanged;
  void chooseChild(String id) {
    if (id == selectedChildId) return;
    if (!snapshot.children.any((c) => c.id == id)) return;
    selectedChildId = id;
    unawaited(features?.selectChild(id));
    notifyListeners();
    onChildChanged?.call();
  }

  void chooseClass(String id) {
    selectedClassId = id;
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    if (notificationsBusy) return;
    notificationsBusy = true;
    notifyListeners();
    try {
      pushStatus = updatePush == null
          ? 'Device alerts are not configured.'
          : await updatePush!(value);
      notificationsEnabled = value && pushStatus == null;
      await features?.savePreferences({'enabled': notificationsEnabled});
      await _preferences?.setBool(
        'notification_preference',
        notificationsEnabled,
      );
      notifyListeners();
    } finally {
      notificationsBusy = false;
      if (!_disposed) notifyListeners();
    }
  }

  void setCompactView(bool value) {
    compactView = value;
    _preferences?.setBool('compact_view', value);
    notifyListeners();
  }

  Future<void> leave() async {
    _refreshVersion++;
    signingOut = true;
    widgetEnabled = false;
    await _preferences?.remove("widgets");
    try {
      final oldFeatures = features;
      features = null;
      oldFeatures?.removeListener(_featureChanged);
      await oldFeatures?.close();
      final old = phaseOne;
      phaseOne = null;
      await old?.close(purge: true);
      await onLeaving?.call(auth.userId);
      if (auth.signedIn) await auth.signOut();
      snapshot = const SchoolSnapshot();
      selectedChildId = null;
      selectedClassId = null;
      notifyListeners();
    } finally {
      signingOut = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshVersion++;
    features?.removeListener(_featureChanged);
    unawaited(features?.close());
    unawaited(phaseOne?.close());
    _subscription?.cancel();
    super.dispose();
  }
}
