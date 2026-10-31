import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/data.dart';
import '../core/phase_one/models.dart';
import '../core/phase_one/sync.dart';
import '../core/theme.dart';
import '../ui/components.dart';

class FastAttendanceScreen extends StatefulWidget {
  const FastAttendanceScreen({super.key});
  @override
  State<FastAttendanceScreen> createState() => _FastAttendanceScreenState();
}

class _FastAttendanceScreenState extends State<FastAttendanceScreen>
    with WidgetsBindingObserver {
  String? classId;
  String query = '';
  DateTime day = DateUtils.dateOnly(DateTime.now());
  bool saving = false, initialized = false;
  String get dayKey => DateFormat('yyyy-MM-dd').format(day);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      final c = AppScope.of(context);
      classId = c.selectedClassId;
      if (classId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) c.phaseOne?.loadRoster(classId!);
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      AppScope.of(context).phaseOne?.sync();
    }
  }

  Future<void> change(
    PhaseOneController p,
    List<(RosterStudent, AttendanceStatus, AttendanceReason?)> changes,
  ) async {
    if (saving || changes.isEmpty) return;
    final previous = changes.map((c) {
      final before = p.entries['${c.$1.id}/$dayKey'];
      return (c.$1, before?.status ?? AttendanceStatus.present, before?.reason);
    }).toList();
    final changedDay = dayKey;
    setState(() => saving = true);
    try {
      await p.mark(changes, changedDay);
      await HapticFeedback.lightImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changes.length == 1
                ? 'Attendance saved on this device'
                : '${changes.length} attendance entries saved on this device',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await p.mark(previous, changedDay);
              } catch (_) {
                if (mounted) {
                  tell(context, 'Couldn’t undo this change. Please try again.');
                }
              }
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        tell(
          context,
          'Couldn’t save on this device. Your register has not changed.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> reasonSheet(PhaseOneController p, RosterStudent s) async {
    final current = p.entries['${s.id}/$dayKey'];
    var status = current?.status ?? AttendanceStatus.absent;
    if (status == AttendanceStatus.present) status = AttendanceStatus.absent;
    AttendanceReason? reason = current?.reason;
    final result =
        await showModalBottomSheet<(AttendanceStatus, AttendanceReason?)>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => StatefulBuilder(
            builder: (context, setSheet) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.name, style: textStyle(22, weight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(
                      'Attendance exception',
                      style: textStyle(13, color: Palette.muted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: AttendanceStatus.values
                          .where((v) => v != AttendanceStatus.present)
                          .map(
                            (v) => ChoiceChip(
                              label: Text(_label(v.name)),
                              selected: status == v,
                              onSelected: (_) => setSheet(() => status = v),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: AttendanceReason.values
                          .map(
                            (v) => ChoiceChip(
                              label: Text(_label(v.name)),
                              selected: reason == v,
                              onSelected: (_) => setSheet(
                                () => reason = reason == v ? null : v,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, (status, reason)),
                      child: const Text('Save exception'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    if (result != null && mounted) await change(p, [(s, result.$1, result.$2)]);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = c.phaseOne;
    return Scaffold(
      appBar: AppBar(title: const Text('Class attendance')),
      body: SafeArea(
        child: !c.workspace.canMarkAttendance
            ? const Center(
                child: Text(
                  'This register is available to authorized school staff.',
                ),
              )
            : p == null
            ? const ContentList(
                children: [
                  ScreenHeading(
                    'Who’s here today?',
                    eyebrow: 'Class attendance',
                  ),
                  EmptyPanel(
                    icon: LucideIcons.users,
                    title: 'No register linked yet',
                    message: 'Your school must assign a class and download its register before attendance can be marked offline.',
                  ),
                ],
              )
            : ListenableBuilder(
                listenable: p,
                builder: (context, _) {
                  final roster = p.students
                      .where((s) => s.classId == classId)
                      .toList();
                  final filtered = roster
                      .where(
                        (s) => '${s.name} ${s.roll ?? ''}'
                            .toLowerCase()
                            .contains(query.toLowerCase()),
                      )
                      .toList();
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Tap only the exceptions.',
                                    style: textStyle(
                                      16,
                                      weight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                SyncBadge(controller: p),
                              ],
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: classId,
                              decoration: const InputDecoration(
                                labelText: 'Class',
                              ),
                              items: c.snapshot.classes
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.id,
                                      child: Text(e.title ?? 'Class'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setState(() => classId = v);
                                if (v != null) {
                                  c.chooseClass(v);
                                  p.loadRoster(v);
                                }
                              },
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    DateFormat('EEE, d MMM yyyy').format(day),
                                    style: textStyle(13),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Choose attendance date',
                                  icon: const Icon(
                                    LucideIcons.calendarDays,
                                    size: 20,
                                  ),
                                  onPressed: () async {
                                    final selected = await showDatePicker(
                                      context: context,
                                      initialDate: day,
                                      firstDate: DateTime.now().subtract(
                                        const Duration(days: 365),
                                      ),
                                      lastDate: DateTime.now(),
                                    );
                                    if (selected != null && mounted) {
                                      setState(() => day = selected);
                                    }
                                  },
                                ),
                              ],
                            ),
                            TextField(
                              decoration: const InputDecoration(
                                hintText: 'Search name or roll number',
                                prefixIcon: Icon(Icons.search),
                              ),
                              onChanged: (v) => setState(() => query = v),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TextButton.icon(
                                  onPressed: saving || roster.isEmpty
                                      ? null
                                      : () => change(
                                          p,
                                          roster
                                              .map(
                                                (s) => (
                                                  s,
                                                  AttendanceStatus.present,
                                                  null as AttendanceReason?,
                                                ),
                                              )
                                              .toList(),
                                        ),
                                  icon: const Icon(Icons.done_all, size: 19),
                                  label: const Text('Mark all present'),
                                ),
                                Text(
                                  '${roster.length} students',
                                  style: textStyle(12, color: Palette.muted),
                                ),
                              ],
                            ),
                            if (p.blockedCount > 0)
                              Text(
                                '${p.blockedCount} changes need attention. Tap sync to retry after access is corrected.',
                                style: textStyle(12, color: Palette.danger),
                              ),
                            if (p.error != null)
                              Text(
                                p.error!,
                                style: textStyle(12, color: Palette.muted),
                              ),
                            if (p.rosterLoading)
                              const LinearProgressIndicator(minHeight: 2),
                          ],
                        ),
                      ),
                      Expanded(
                        child: roster.isEmpty
                            ? const SingleChildScrollView(
                                padding: EdgeInsets.all(22),
                                child: EmptyPanel(
                                  icon: LucideIcons.clipboardList,
                                  title: 'Your register will appear here',
                                  message: 'Choose an assigned class while online to download its roster. Opening a register does not submit attendance.',
                                ),
                              )
                            : filtered.isEmpty
                            ? const Center(
                                child: Text('No students match your search.'),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                itemBuilder: (context, index) {
                                  final s = filtered[index];
                                  final entry = p.entries['${s.id}/$dayKey'];
                                  final status =
                                      entry?.status ?? AttendanceStatus.present;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Semantics(
                                      label:
                                          '${s.name}, ${_label(status.name)}${entry == null ? ', draft' : ''}. Long press to add a reason.',
                                      child: Material(
                                        color: Palette.paper,
                                        borderRadius: BorderRadius.circular(18),
                                        child: InkWell(
                                          onLongPress: saving
                                              ? null
                                              : () => reasonSheet(p, s),
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(14),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      backgroundColor:
                                                          Palette.mint,
                                                      child: Text(
                                                        s.name.characters.first
                                                            .toUpperCase(),
                                                        style: textStyle(15),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        s.name,
                                                        style: textStyle(
                                                          14,
                                                          weight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                    if (entry == null)
                                                      const Tag('DRAFT'),
                                                    if (entry?.pending == true)
                                                      const Icon(
                                                        Icons.schedule,
                                                        size: 16,
                                                        semanticLabel:
                                                            'Pending sync',
                                                      ),
                                                  ],
                                                ),
                                                if (s.roll != null)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          top: 6,
                                                        ),
                                                    child: Text(
                                                      'Roll ${s.roll}',
                                                      style: textStyle(
                                                        12,
                                                        color: Palette.muted,
                                                      ),
                                                    ),
                                                  ),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: AttendanceStatus
                                                      .values
                                                      .map(
                                                        (v) => ChoiceChip(
                                                          label: Text(
                                                            _label(v.name),
                                                          ),
                                                          selected: status == v,
                                                          onSelected: saving
                                                              ? null
                                                              : (_) =>
                                                                    change(p, [
                                                                      (
                                                                        s,
                                                                        v,
                                                                        null,
                                                                      ),
                                                                    ]),
                                                        ),
                                                      )
                                                      .toList(),
                                                ),
                                                if (entry?.reason != null)
                                                  Text(
                                                    'Reason: ${_label(entry!.reason!.name)}',
                                                    style: textStyle(
                                                      12,
                                                      color: Palette.muted,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Present is a draft until you save. Exceptions save immediately on this device.',
                              style: textStyle(11, color: Palette.muted),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: saving || roster.isEmpty
                                  ? null
                                  : () => change(
                                      p,
                                      roster.map((s) {
                                        final e = p.entries['${s.id}/$dayKey'];
                                        return (
                                          s,
                                          e?.status ?? AttendanceStatus.present,
                                          e?.reason,
                                        );
                                      }).toList(),
                                    ),
                              icon: const Icon(Icons.save_outlined, size: 19),
                              label: Text(saving ? 'Saving…' : 'Save register'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

String _label(String value) => '${value[0].toUpperCase()}${value.substring(1)}';

class SyncBadge extends StatelessWidget {
  final PhaseOneController controller;
  const SyncBadge({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final p = controller;
      final label = p.busy
          ? 'Syncing'
          : p.status == SyncStatus.synced
          ? 'Synced'
          : p.status == SyncStatus.offline
          ? 'Offline${p.pendingCount > 0 ? ' · ${p.pendingCount}' : ''}'
          : 'Pending · ${p.pendingCount}';
      return TextButton.icon(
        onPressed: p.busy ? null : () => p.sync(retryBlocked: true),
        icon: Icon(
          p.status == SyncStatus.offline
              ? Icons.cloud_off_outlined
              : Icons.sync,
          size: 16,
        ),
        label: Text(
          label,
          style: textStyle(
            11,
            color: p.status == SyncStatus.offline
                ? Palette.amber
                : Palette.teal,
          ),
        ),
      );
    },
  );
}
