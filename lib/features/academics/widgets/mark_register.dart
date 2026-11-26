part of '../screen.dart';

class MarksScreen extends StatefulWidget {
  final SchoolRow assessment;
  const MarksScreen({super.key, required this.assessment});
  @override
  State<MarksScreen> createState() => _MarksState();
}

class _MarksState extends State<MarksScreen> {
  final edits = <String, String>{};
  final errors = <String, String>{};
  bool loading = true, saving = false;
  String query = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AppScope.of(context).phaseOne
          ?.loadRoster(widget.assessment['class_id'] as String);
      if (!mounted) return;
      try {
        await AppScope.of(context).features
            ?.loadGrades(widget.assessment['id'] as String);
      } catch (_) {
        if (mounted) {
          tell(
            context,
            'Downloaded marks shown. Refresh before changing marks that are missing.',
          );
        }
      }
      if (mounted) setState(() => loading = false);
    });
  }

  Future<void> save() async {
    final c = AppScope.of(context);
    final h = c.features;
    if (h == null || !c.canWrite) return;
    final max = (widget.assessment['max_score'] as num).toDouble();
    errors.clear();
    for (final e in edits.entries) {
      final score = num.tryParse(e.value);
      if (score == null || score < 0 || score > max) {
        errors[e.key] = 'Enter 0 to $max';
      }
    }
    if (errors.isNotEmpty) {
      setState(() {});
      return;
    }
    setState(() => saving = true);
    try {
      for (final e in edits.entries) {
        final old = h
            .rows('grades')
            .where(
              (g) =>
                  g['assessment_id'] == widget.assessment['id'] &&
                  g['student_id'] == e.key,
            )
            .firstOrNull;
        final p = <String, dynamic>{
          'assessment_id': widget.assessment['id'],
          'student_id': e.key,
          'score': num.parse(e.value),
          'expected_version': old?['version'] ?? 0,
        };
        await h.queue(
          'grade',
          p,
          collection: 'grades',
          key: '${widget.assessment['id']}/${e.key}',
          optimistic: {...p, 'version': old?['version'] ?? 0},
        );
      }
      edits.clear();
      if (mounted) {
        tell(context, 'Edited marks saved. Newer server marks take priority.');
      }
    } catch (_) {
      if (mounted) {
        tell(context, 'Some marks couldn’t be saved. Review pending sync.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final students = (c.phaseOne?.students ?? [])
        .where(
          (s) =>
              s.classId == widget.assessment['class_id'] &&
              s.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.assessment['title'] as String? ?? 'Marks'),
        actions: [
          TextButton(
            onPressed: saving ? null : save,
            child: const Text('Save edits'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: TextField(
              decoration: const InputDecoration(hintText: 'Search student'),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (c.features?.conflicts != 0 && c.features?.conflicts != null)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SyncPill(
                RecordSyncState.conflict,
                'Newer school mark kept · review',
              ),
            ),
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('No students in this register.'))
                : FocusTraversalGroup(
                    child: ListView.builder(
                      itemCount: students.length,
                      itemBuilder: (context, i) {
                        final s = students[i];
                        final old = c.features
                            ?.rows('grades')
                            .where(
                              (g) =>
                                  g['assessment_id'] ==
                                      widget.assessment['id'] &&
                                  g['student_id'] == s.id,
                            )
                            .firstOrNull;
                        return ListTile(
                          title: Text(s.name),
                          subtitle: old?['_pending'] == true
                              ? const SyncPill(
                                  RecordSyncState.queued,
                                  'Saved locally',
                                )
                              : s.roll == null
                              ? null
                              : Text('Roll ${s.roll}'),
                          trailing: SizedBox(
                            width: 120,
                            child: TextFormField(
                              key: ValueKey(
                                '${s.id}/${old?['version']}/${old?['_pending']}',
                              ),
                              initialValue:
                                  edits[s.id] ?? old?['score']?.toString(),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: 'Mark',
                                errorText: errors[s.id],
                                suffixText:
                                    '/ ${widget.assessment['max_score']}',
                              ),
                              onChanged: (v) => edits[s.id] = v,
                              onFieldSubmitted: (_) =>
                                  FocusScope.of(context).nextFocus(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
