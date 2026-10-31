import 'dart:async';

/// Retains generic alert navigation until authenticated school context is ready.
/// School/role checks remain in the dispatcher and backend action RPC.
class SchoolAlertRouter {
  final bool Function() ready;
  final Future<void> Function(Map<String, dynamic>) dispatch;
  final Map<String, Map<String, dynamic>> _pending = {};
  final Set<String> _handled = {};
  bool _flushing = false;
  int _generation = 0;
  SchoolAlertRouter({required this.ready, required this.dispatch});
  String key(Map<String, dynamic> data) =>
      '${data['event_id'] ?? data['entity_id'] ?? data['type']}/${data['action'] ?? 'open'}';
  void receive(Map<String, dynamic> data) {
    final id = key(data);
    if (_handled.contains(id) || _pending.containsKey(id)) return;
    _pending[id] = Map.from(data);
    if (_pending.length > 20) _pending.remove(_pending.keys.first);
    unawaited(flush());
  }

  Future<void> flush() async {
    if (_flushing || !ready()) return;
    _flushing = true;
    final generation = _generation;
    try {
      while (_pending.isNotEmpty && ready() && generation == _generation) {
        final id = _pending.keys.first;
        final data = _pending.remove(id)!;
        if (_handled.contains(id)) continue;
        _handled.add(id);
        if (_handled.length > 100) _handled.remove(_handled.first);
        try {
          await dispatch(data);
        } catch (_) {
          /* A denied/stale action must not crash or repeat indefinitely. */
        }
      }
    } finally {
      _flushing = false;
    }
  }

  void clear() {
    _generation++;
    _pending.clear();
    _handled.clear();
  }
}
