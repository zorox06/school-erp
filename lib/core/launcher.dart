import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';

import 'data.dart';

class SchoolLauncher {
  final AppController controller;
  final void Function(Map<String, dynamic>) open;
  final QuickActions shortcuts = const QuickActions();
  String? _identity;
  bool _scheduled = false;
  bool _running = false;
  bool _dirty = false;
  SchoolLauncher(this.controller, this.open);
  Future<void> initialize() async {
    if (kIsWeb) return;
    await HomeWidget.setAppGroupId('group.app.schoolday.schoolerp');
    await shortcuts.initialize((type) => open({'type': type}));
    HomeWidget.widgetClicked.listen((uri) {
      if (uri != null && uri.scheme == "schoolday") open(widgetRoute(uri));
    });
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (uri != null && uri.scheme == "schoolday") open(widgetRoute(uri));
    controller.addListener(changed);
    changed();
  }

  void changed() {
    if (_scheduled) return;
    _scheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      _scheduled = false;
      unawaited(update());
    });
  }

  Future<void> update() async {
    if (_running) {
      _dirty = true;
      return;
    }
    _running = true;
    try {
      do {
        _dirty = false;
        final c = controller;
        final identity = c.entered && !c.signingOut && c.accessAssigned
            ? '${c.auth.userId}/${c.snapshot.schoolId}/${c.workspace.name}/${c.selectedChildId}'
            : null;
        if (identity != _identity) {
          _identity = identity;
          await shortcuts.clearShortcutItems();
          if (identity != null) {
            await shortcuts.setShortcutItems([
              ShortcutItem(
                type: c.workspace.canMarkAttendance
                    ? 'attendance'
                    : c.workspace == Workspace.student
                    ? 'homework'
                    : 'notices',
                localizedTitle: c.workspace.canMarkAttendance
                    ? 'Mark attendance'
                    : c.workspace == Workspace.student
                    ? 'Homework'
                    : 'Notices',
                icon: 'ic_schoolday',
              ),
            ]);
          }
        }
        final enabled = identity != null && c.widgetEnabled;
        final today = DateTime.now();
        final slots = enabled
            ? c.timetableItems
                  .where(
                    (r) =>
                        r.date != null &&
                        r.date!.toLocal().year == today.year &&
                        r.date!.toLocal().month == today.month &&
                        r.date!.toLocal().day == today.day,
                  )
                  .take(3)
                  .toList()
            : <SchoolRecord>[];
        final homework = enabled
            ? c
                  .learningItems(false)
                  .where(
                    (r) => r.status != 'submitted' && r.status != 'reviewed',
                  )
                  .take(3)
                  .toList()
            : <SchoolRecord>[];
        await HomeWidget.saveWidgetData<String>(
          'timetable',
          enabled
              ? slots
                    .map(
                      (r) =>
                          '${r.date!.toLocal().hour.toString().padLeft(2, '0')}:${r.date!.toLocal().minute.toString().padLeft(2, '0')}  ${r.title ?? 'Lesson'}',
                    )
                    .join('\n')
              : '',
        );
        await HomeWidget.saveWidgetData<String>(
          'homework',
          enabled
              ? homework
                    .map(
                      (r) =>
                          '${r.title ?? 'Homework'}${r.date == null ? '' : ' · ${r.date!.toLocal().day}/${r.date!.toLocal().month}'}',
                    )
                    .join('\n')
              : '',
        );
        for (final (kind, items) in [
          ('timetable', slots),
          ('homework', homework),
        ]) {
          final target = Uri(
            scheme: 'schoolday',
            host: kind,
            queryParameters: enabled
                ? {
                    'school_id': c.snapshot.schoolId!,
                    if (!c.workspace.isStaff && c.selectedChildId != null)
                      'child_id': c.selectedChildId!,
                    if (items.length == 1) 'entity_id': items.first.id,
                  }
                : null,
          );
          await HomeWidget.saveWidgetData<String>(
            '${kind}_url',
            target.toString(),
          );
        }
        await HomeWidget.saveWidgetData<bool>('enabled', enabled);
        await HomeWidget.saveWidgetData<String>(
          'updated',
          enabled ? today.toIso8601String() : '',
        );
        await HomeWidget.updateWidget(
          qualifiedAndroidName:
              'app.schoolday.schoolday.TimetableWidgetProvider',
          iOSName: 'SchooldayTimetable',
        );
        await HomeWidget.updateWidget(
          qualifiedAndroidName:
              'app.schoolday.schoolday.HomeworkWidgetProvider',
          iOSName: 'SchooldayHomework',
        );
      } while (_dirty);
    } catch (_) {
      /* Widgets remain optional when the platform host is unavailable. */
    } finally {
      _running = false;
    }
  }

  Future<void> clear() async {
    while (_running) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    _identity = null;
    await shortcuts.clearShortcutItems();
    await HomeWidget.saveWidgetData<String>('timetable', '');
    await HomeWidget.saveWidgetData<String>('homework', '');
    await HomeWidget.saveWidgetData<String>(
      'homework_url',
      'schoolday://homework',
    );
    await HomeWidget.saveWidgetData<String>(
      'timetable_url',
      'schoolday://timetable',
    );
    await HomeWidget.saveWidgetData<bool>('enabled', false);
    await HomeWidget.saveWidgetData<String>('updated', '');
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'app.schoolday.schoolday.TimetableWidgetProvider',
      iOSName: 'SchooldayTimetable',
    );
    await HomeWidget.updateWidget(
      qualifiedAndroidName: 'app.schoolday.schoolday.HomeworkWidgetProvider',
      iOSName: 'SchooldayHomework',
    );
  }
}

Map<String, dynamic> widgetRoute(Uri uri) => {
  'type': uri.host,
  for (final key in ['school_id', 'child_id', 'entity_id'])
    if (uri.queryParameters[key] != null) key: uri.queryParameters[key],
};
