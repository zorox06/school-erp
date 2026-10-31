import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/native_features.dart';
import '../ui/components.dart';
import '../ui/quick_sheet.dart';
import 'academics.dart';

Future<void> showReportCard(BuildContext context) =>
    quickSheet<void>(context, (context, scroll) => ReportLock(scroll: scroll));

class ReportLock extends StatefulWidget {
  final ScrollController scroll;
  const ReportLock({super.key, required this.scroll});
  @override
  State<ReportLock> createState() => _ReportLockState();
}

class _ReportLockState extends State<ReportLock> with WidgetsBindingObserver {
  final auth = LocalAuthentication();
  bool unlocked = false, checking = false;
  String? child, owner;
  String? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NativeSchoolFeatures.protectReport(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    auth.stopAuthentication();
    NativeSchoolFeatures.protectReport(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!checking && state != AppLifecycleState.resumed && mounted) {
      setState(() => unlocked = false);
    }
  }

  Future<void> unlock() async {
    final c = AppScope.of(context);
    if (c.preview || c.features == null || c.selectedChildId == null) {
      setState(
        () =>
            error = 'Sign in and select a linked child to view a report card.',
      );
      return;
    }
    final targetChild = c.selectedChildId;
    final targetOwner = c.auth.userId;
    setState(() => checking = true);
    try {
      if (!await auth.canCheckBiometrics) {
        if (mounted) {
          setState(
            () => error = 'Set up device biometrics to unlock report cards.',
          );
        }
        return;
      }
      final ok = await auth.authenticate(
        localizedReason: 'Unlock this child’s private report card',
        biometricOnly: true,
        persistAcrossBackgrounding: false,
      );
      if (mounted) {
        setState(() {
          unlocked =
              ok &&
              targetChild == c.selectedChildId &&
              targetOwner == c.auth.userId;
          child = targetChild;
          owner = targetOwner;
          error = ok ? null : 'Report card remains locked.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Biometric authentication is unavailable. Your report remains locked.',
        );
      }
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final allowed =
        unlocked &&
        child == c.selectedChildId &&
        owner == c.auth.userId &&
        c.entered;
    if (!allowed) {
      return ListView(
        controller: widget.scroll,
        padding: const EdgeInsets.all(24),
        children: [
          const IconBadge(LucideIcons.fingerprint, size: 64),
          const SizedBox(height: 22),
          Text(
            'A private view of progress.',
            style: textStyle(25, weight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(error ?? 'Use your device biometrics to open this report card.'),
          const SizedBox(height: 22),
          PrimaryButton(
            'Unlock report card',
            icon: LucideIcons.fingerprint,
            onPressed: checking ? null : unlock,
            busy: checking,
          ),
        ],
      );
    }
    final grades = c.features!
        .rows('grades')
        .where((g) => g['student_id'] == child)
        .toList();
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.all(24),
      children: [
        Text('Report card', style: textStyle(26, weight: FontWeight.w800)),
        const SizedBox(height: 16),
        if (grades.isEmpty)
          const EmptyPanel(
            icon: LucideIcons.chartNoAxesCombined,
            title: 'No marks published yet',
            message: 'Published subject marks will appear here.',
          ),
        ...grades.map(
          (g) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              '${g['subject'] ?? 'Subject'} · ${g['title'] ?? 'Assessment'}',
            ),
            subtitle: Text(g['exam_at'] as String? ?? ''),
            trailing: Text('${g['score']} / ${g['max_score']}'),
          ),
        ),
        OutlinedButton(
          onPressed: () => setState(() => unlocked = false),
          child: const Text('Lock report card'),
        ),
        TextButton(
          onPressed: () => openPage(context, const AcademicsScreen()),
          child: const Text('View exams & subject progress'),
        ),
      ],
    );
  }
}
