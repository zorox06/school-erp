import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/data.dart';
import '../../core/phase_one/models.dart';
import '../../core/phase_one/sync.dart';
import '../../core/theme.dart';
import '../../ui/components.dart';

part 'widgets/status.dart';

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
    final approved =
        AppScope.of(context).features
            ?.rows('leaves')
            .any(
              (r) =>
                  r['student_id'] == s.id &&
                  r['status'] == 'approved' &&
                  (r['starts_on']?.toString() ?? 'z').compareTo(dayKey) <= 0 &&
                  (r['ends_on']?.toString() ?? '').compareTo(dayKey) >= 0,
            ) ??
        false;
    if (current == null && approved) status = AttendanceStatus.leave;
    AttendanceReason? reason =
        current?.reason ?? (approved ? AttendanceReason.excused : null);
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
                    if (approved)
                      const InfoBanner('Approved leave for this date'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ActionChip(
                        label: const Text('Bus delay · late, excused'),
                        onPressed: () => setSheet(() {
                          status = AttendanceStatus.late;
                          reason = AttendanceReason.excused;
                        }),
                      ),
                    ),
                    Text(s.name, style: textStyle(22, weight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    Text(
                      'Attendance exception',
                      style: textStyle(13, color: context.tones.muted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: AttendanceStatus.values
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
                      onPressed: () => Navigator.pop(context, (
                        status,
                        status == AttendanceStatus.present ? null : reason,
                      )),
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
                  final counts = <AttendanceStatus, int>{};
                  for (final student in roster) {
                    final status =
                        p.entries['${student.id}/$dayKey']?.status ??
                        AttendanceStatus.present;
                    counts.update(
                      status,
                      (count) => count + 1,
                      ifAbsent: () => 1,
                    );
                  }

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
                                  style: textStyle(
                                    12,
                                    color: context.tones.muted,
                                  ),
                                ),
                              ],
                            ),
                            if (p.blockedCount > 0)
                              Text(
                                '${p.blockedCount} changes need attention. Tap sync to retry after access is corrected.',
                                style: textStyle(
                                  12,
                                  color: context.tones.danger,
                                ),
                              ),
                            if (p.error != null)
                              Text(
                                p.error!,
                                style: textStyle(
                                  12,
                                  color: context.tones.muted,
                                ),
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
                            : LayoutBuilder(
                                builder: (context, box) {
                                  final scale =
                                      MediaQuery.textScalerOf(context)
                                          .scale(14) /
                                      14;
                                  final cols = (box.maxWidth / (150 * scale))
                                      .floor()
                                      .clamp(1, 5);
                                  return GridView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      2,
                                      16,
                                      8,
                                    ),
                                    gridDelegate:
                                        SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: cols,
                                          crossAxisSpacing: 8,
                                          mainAxisSpacing: 8,
                                          mainAxisExtent:
                                              104 * scale.clamp(1, 3.5),
                                        ),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final s = filtered[index],
                                          entry = p
                                              .entries['${filtered[index].id}/$dayKey'];
                                      final status =
                                          entry?.status ??
                                          AttendanceStatus.present;
                                      final ink = switch (status) {
                                        AttendanceStatus.absent =>
                                          context.tones.coral,
                                        AttendanceStatus.late =>
                                          context.tones.amber,
                                        _ => context.tones.teal,
                                      };
                                      return Surface(
                                        radius: 13,
                                        padding: const EdgeInsets.all(10),
                                        onTap: saving
                                            ? null
                                            : () => reasonSheet(p, s),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              s.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: textStyle(
                                                14,
                                                weight: FontWeight.w800,
                                                height: 1.18,
                                              ),
                                            ),
                                            if (s.roll != null)
                                              Text(
                                                'Roll ${s.roll}',
                                                maxLines: 1,
                                                style: textStyle(
                                                  11,
                                                  color: context.tones.muted,
                                                ),
                                              ),
                                            Text(
                                              '${_label(status.name)}${entry == null
                                                  ? ' · Draft'
                                                  : entry.pending
                                                  ? ' · Queued'
                                                  : ''}',
                                              maxLines: 2,
                                              style: textStyle(12, color: ink),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              children: [
                                for (final status in AttendanceStatus.values)
                                  Text(
                                    '${counts[status] ?? 0} ${_label(status.name)}',
                                    style: textStyle(
                                      12,
                                      weight: FontWeight.w800,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              'Present is a draft until you save. Exceptions save immediately on this device.',
                              style: textStyle(11, color: context.tones.muted),
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
