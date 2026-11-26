part of '../screen.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});
  @override
  State<AuditScreen> createState() => _AuditState();
}

class _AuditState extends State<AuditScreen> {
  final rows = <SchoolRow>[];
  bool busy = false, more = true;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Future<void> load() async {
    final c = AppScope.of(context);
    final h = c.features;
    if (h == null || busy || !c.workspace.isLeadership) return;
    setState(() => busy = true);
    try {
      final result = await h.gateway.call('erp_audit_page', {
        'p_school': h.school,
        'p_before': rows.lastOrNull?['id'],
        'p_limit': 40,
      }) as List;
      if (mounted) {
        setState(() {
          rows.addAll(result.map((e) => Map<String, dynamic>.from(e as Map)));
          more = result.length == 40;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Audit history could not be loaded.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Audit history')),
    body: ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == rows.length) {
          return Column(
            children: [
              if (error != null) InfoBanner(error!),
              if (rows.isEmpty && !busy)
                const EmptyPanel(
                  icon: LucideIcons.history,
                  title: 'No edits recorded',
                  message: 'Attendance and grade changes retain actor, time and before/after values.',
                ),
              if (more)
                TextButton(
                  onPressed: busy ? null : load,
                  child: Text(busy ? 'Loading…' : 'Load more'),
                ),
            ],
          );
        }
        final r = rows[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['action'] as String? ?? 'School edit',
                  style: textStyle(16, weight: FontWeight.w800),
                ),
                Text('${r['actor_name'] ?? r['actor']} · ${r['at']}'),
                Text(
                  'Before: ${r['before_value'] ?? '—'}',
                  style: textStyle(12),
                ),
                Text('After: ${r['after_value'] ?? '—'}', style: textStyle(12)),
              ],
            ),
          ),
        );
      },
    ),
  );
}
