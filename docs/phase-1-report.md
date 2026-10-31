# Phase 1 implementation report

Scope: trusted roles and access, offline attendance, notices and push infrastructure. Phase 2–4 features are not represented as complete. The distributed build retains `ENABLE_SCHOOL_DATA=false`; no example students, records, accounts or remote database changes were created.

## What changed

| Files | Purpose |
|---|---|
| `lib/core/roles.dart`, `lib/core/data.dart`, `lib/app.dart` | Five trusted roles; unassigned-account gate; staff capability checks; session-safe refresh; separate staff/student navigation. Account holders cannot choose their actual role. |
| `lib/core/phase_one/models.dart`, `store.dart`, `cached_repository.dart`, `sync.dart` | SQLite caches and transactional outbox, user/school isolation, seven-day context cache, retries/backoff, blocked permission failures, exact-version acknowledgements, server delta cursor, redacted failure log. Logout tombstones prevent delayed/background responses from repopulating erased account caches. |
| `lib/features/attendance.dart`, `school.dart` | Lazy/searchable register, Present drafts, explicit save, exception choices, long-press reasons, mark-all-present, undo, light haptics, date selection, parent record display and sync badge. |
| `lib/features/notices.dart`, `account.dart`, `auth.dart`, `dashboard.dart` | Paginated/lazy searchable circulars, important filter, offline read/acknowledgement, 50%/90% snapping detail sheet, staff publishing, five empty workspace previews. |
| `lib/core/phase_one/push.dart`, `background.dart`, `lib/main.dart` | Deferred optional FCM registration using the current Installation ID API, foreground notifications, urgent/quiet Android channels, notification-open routing, foreground retries and OS-managed background tasks. |
| `supabase/migrations/202610310001_phase_one.sql` | Empty normalized Phase 1 tables, RLS, class/guardian scope checks, validated attendance/notice RPCs, server revisions, audit records and deduplicated absence notification outbox. Existing migration retained. |
| `supabase/functions/dispatch-school-alerts/` | Secret-protected server-only FCM dispatcher; current membership/guardian/status checks before sending, leases/backoff, generic lock-screen payloads and invalid-device cleanup. No private credentials in source. |
| `android/app/` | Notification permission/icon and backup exclusion for local school records/session storage. |
| `ios/` | Added the missing Flutter host, matching bundle ID and background-task registration. APNs capability/signing still needs the Apple/Firebase account. |
| `test/`, `tools/sql-tests/`, `docs/phase-1-contract.md` | Real SQLite failure/rollback tests, UI checks and isolated PostgreSQL permission/contract checks; declared API/dependency contract. |

## What works and how to test

In the supplied empty build, open **Preview the empty app**. Parent, teacher, student, principal and admin previews remain empty. Teacher → Attendance explains that a real assigned register must be downloaded. Parent → School → Notices displays the new circulars interface. Preview never registers push, queues school writes or loads remote business data.

To exercise real workflows, first review/apply both SQL migrations to the intended Supabase project through trusted administration. Provision real schools, active memberships, class rows in `school_content`, `erp_students`, `erp_class_students`, `erp_class_teachers` and `erp_guardians`. Actual guardian/student relationships are mandatory; do not broaden audiences to make data appear. Assign `app_metadata.workspace` only through trusted administration when using the empty build; with live records the RLS-authorized membership returned by `mobile_context()` takes precedence.

Then use a separate development configuration with `ENABLE_SCHOOL_DATA=true`:

1. Sign in as an assigned teacher online and open a class register to download it.
2. Confirm Present entries show DRAFT and that opening the register makes no attendance writes.
3. Disconnect networking. Tap Absent/Late/Leave; long-press for Sick/Excused/Unexcused. Close/reopen the app and confirm queued edits remain.
4. Use Mark all present, Undo and Save register. Reconnect; Pending should clear after accepted sync. A denied record stays pending/blocked with an explanation rather than disappearing.
5. Sign in as a guardian and confirm attendance comes only from their linked child. A parent/student calling the staff RPC directly must receive a permission error.
6. Publish a circular as authorized staff. Read and acknowledge it offline as a parent. Reconnect and verify the server receipt; another school's account must not see or acknowledge it.
7. Sign out while a request is running; the old account's cache/queue must remain removed. Signing into a different account must not expose the previous register.

Attendance is a daily register per student. Provision homeroom/register classes accordingly. Client draft timestamps are monotonic per locally edited student/day; the server accepts drafts from the previous seven days, rejects timestamps more than five minutes ahead, and returns its authoritative winner. Database edits and delta watermarks serialize per school so an uncommitted lower revision cannot be skipped. Phase 2 marks/grades must use server-authoritative version conflicts, not attendance's draft rule.

## Push setup and limits

No Firebase project settings, Apple signing/APNs configuration or server service account were provided. Push infrastructure compiles, but no real push delivery was performed or claimed.

Public Flutter build configuration needs `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID`, `FIREBASE_API_KEY`, `FIREBASE_ANDROID_APP_ID` and (for iOS) `FIREBASE_IOS_APP_ID`, matching `app.schoolday.schoolerp`. These are public app settings, not server private keys. Upload the APNs authentication key to Firebase and enable the Runner push capability in Xcode. Run and validate iOS on macOS/Xcode; it was not compiled on this Windows machine.

The Edge Function requires the server environment's `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`, plus private `FCM_SERVICE_ACCOUNT` JSON and a strong `DISPATCH_SECRET`. Do not place these in Flutter configuration. Deploy the dispatcher with gateway JWT verification disabled **only because its handler enforces its own scheduler bearer secret** (`supabase functions deploy dispatch-school-alerts --no-verify-jwt`). Configure a trusted scheduler to POST with `Authorization: Bearer <DISPATCH_SECRET>`; never call it from the mobile client.

Absence alerts are produced after server acceptance, not while the draft is only local. Superseded absence events are checked again before dispatch. Delivery is at least once, with stable notification tags/collapse IDs and retry leases; it is not an exactly-once or guaranteed immediate OS delivery claim. Offline logout attempts server unregistration and local FCM unregistration; stale undeliverable server registrations require normal dispatcher cleanup. Lock-screen payloads contain no student names, reasons or circular bodies.

An offline register requires a previous authorized download. Background execution timing is controlled by the OS; foreground resume/manual retry remains available. Android background retries are periodic and constrained to networking. The iOS host includes processing-task setup, but physical iOS scheduling and APNs delivery remain unverified.

## Validation

- `flutter analyze`: clean.
- `flutter test`: 23 behavior/SQLite/UI tests passed; 9 optional renders skipped in the normal run.
- Explicit render run: all 9 empty-screen captures passed. Attendance, notices and student screens were visually reviewed.
- `npm test` in `tools/sql-tests`: 26 PostgreSQL permission/contract checks passed using isolated PGlite, not the remote Supabase project.
- `deno check index.ts`: passed for the dispatcher.
- Dispatcher tests: 3 passed, covering method restriction and fail-closed scheduler authentication.
- Android release build: succeeded; 58,596,179 bytes (58.6 decimal MB / 55.9 MiB), application ID `app.schoolday.schoolerp`, version `1.1.0`, min SDK 24 and target SDK 36. APK signature verification passed using the existing development signing identity.
- Android emulator smoke: install, launch, empty teacher preview and Attendance navigation passed. No application fatal/Flutter exception appeared in the checked process log. The emulator initially displayed an Android System UI ANR; after dismissing that system dialog and using a smaller test display, app navigation was verified. Emulator display overrides were reset and the agent-started emulator was closed. The native screenshot is supplied separately.
- Startup performance is not certified: emulator ActivityManager cold-launch measurements were approximately 5.7 and 11.6 seconds during software-rendered VM startup. These are not a mid-range physical-device benchmark; the under-two-second physical-device target remains Phase 4 work.

SQLite checks cover an interrupted insert rollback, restart persistence, offline retry/backoff, permission failures, server winner handling, an in-flight older acknowledgement, local authorization, pending-draft delta preservation, cross-account isolation, monotonic notice acknowledgement and late writes after logout. UI checks cover a lazy 500-student register and an offline acknowledgement in a snapping sheet.

## Existing exclusions retained

The existing `payments.dart`, parent Fees navigation, invoice model/SQL fields and unavailable-checkout UI are retained without expanding them. No payment gateway is connected. No bus/GPS, QR/student-ID, pickup, visitor or language-switching feature was added. Existing `intl` remains for date formatting.

## Dependencies and remaining phases

Added `sqflite`/`path` for local storage; `workmanager` for background sync; `firebase_core`/`firebase_messaging` for optional push; `flutter_local_notifications` for presentation/channels; `sqflite_common_ffi` for desktop SQLite tests. Android `desugar_jdk_libs` supplies Java API compatibility required by notifications. PGlite and Deno are development/server validation tooling, not APK dependencies. Versions are locked in the package lockfiles.

Phase 2 remains: complete child-scoped learning/messaging, camera homework and submissions, marks grid with server-wins conflicts, templates, quiet hours and category settings. Phase 3 remains: widgets, launcher shortcuts, principal summary, emergency broadcast, report cards/biometric lock and audit UI (attendance audit persistence is already present). Phase 4 remains: data-saver/performance tuning, broader accessibility/device checks and configured crash reporting. No startup-time, 3 GB-device performance or production readiness claim is made from a desktop test alone.
