# Phase 3 report

Completed source: principal summary/coverage, teacher attendance, optimistic versioned leave decisions, emergency publication, paged audit history, timetable/substitute alerts, biometric report-card sheet, role-filtered launcher shortcuts, and native timetable/homework widgets.

Key files: `features/leadership.dart`, `report_card.dart`, `timetable_edit.dart`; `core/launcher.dart`, `native_features.dart`; Android `MainActivity.kt`, `SchoolWidgetProvider.kt`, manifest/layout/provider resources; iOS AppDelegate, WidgetKit source/extension target/entitlements. Migrations `202610310003`, `004`, `006` provide guarded action, summary, audit, unread, alert-preference and substitution APIs. The dispatcher now handles categories, recipient reauthorization, quiet hours, actionable leave data and emergency priority. Leave notification actions recheck the current school/staff role and expected server version.

Manual test: open Principal overview from a leadership account; record actual teacher attendance and compare summary; approve/decline a pending leave; inspect before/after audit entries; review an emergency before publishing; assign a substitute and confirm the lesson appears without permanent roster access. Long-press the launcher icon. Opt into widgets, add both through the OS, switch children, then sign out and verify clearing. Open a report card, authenticate biometrically, background the app and confirm re-locking.

Validation: Phase 3 release build succeeded (about 63.1 MB), application tests passed, and live role/SQL contracts were checked. Final cross-phase evidence is in the final report.

External limits: Firebase/APNs/scheduler credentials are absent, so actual notification delivery and approval from a delivered push are not device-certified. iOS signing/App Group/APNs and all Xcode builds require macOS/Apple credentials. Android biometric hardware and opt-in populated widgets require real account/device verification. Empty widgets show no school/example content.
