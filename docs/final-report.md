# Schoolday 1.4 delivery report

The source in `C:/Users/newar/Desktop/school erp` now includes phases 1–4. `Schoolday.apk` on the Desktop is the latest Android build. School business data remains empty; missing names and figures remain null/empty states.

## Delivered Android build

- Version **1.4.0+5**, minimum Android **7 / API 24**, target API **36**.
- Universal APK: **70,582,546 bytes** (70.58 MB / 67.31 MiB), below 100 MB.
- SHA-256: `82a999063f961d61b64c0b63bd972c0b310ffe0d91a8e8ea30358d0eac492d73`.
- Release-mode, locally installable build using the existing debug signing identity. A production keystore and store configuration are still required before Play Store distribution.

## Implemented features

| Area | Current behavior |
|---|---|
| Roles | Parent, teacher, student, principal and admin workspaces; actual roles come from trusted server memberships. Preview cannot grant account access or write school records. |
| Attendance | Present drafts, exception taps/reasons, mark-all/undo/haptics, explicit save, real SQLite queue, LWW attendance, class/guardian permissions and audit history. |
| Circulars | Lazy paginated/searchable notices, read receipts, required important-notice acknowledgement, snapping sheets and staff publishing. |
| Learning | Camera homework, due dates/multiple classes, worksheets, private attachments, crop/enhance/rotate scanning to PDF, submissions and staff feedback. |
| Communication | Approved class/family contacts, search, teacher templates, private cached conversations, older-message pagination and queued sends. Family lookup supports classes beyond the first contact batch. |
| Children | Shared child avatar switcher, immediately cleared child-specific collections, scoped caches/APIs and automatic closing of old detail routes. Existing statements are child-filtered. |
| Academics | Assessment creation, numeric marks grid/next field, all per-assessment marks through pages, server-wins conflicts, exam countdowns and subject charts. |
| Leave / leadership | Snapping leave request, versioned approval/decline, daily attendance with coverage, actual teacher attendance and pending-leave summary. |
| Safety | Leadership-only emergency publication, private biometric report-card preview with lifecycle/account/child re-locking, paged actor/before/after audit trail. |
| Timetable | Dated lesson and substitute updates; a substitute sees their own lesson without receiving permanent class/student access. Existing news/event views remain connected to the school-content adapter. |
| Native features | Role-filtered launcher shortcuts; Android widget providers and iOS WidgetKit extension source for timetable/homework. Widgets are opt-in, follow the child and clear on logout. Private native document viewers are connected. |
| Alerts | Category toggles, device/teacher quiet hours, urgency channels, actionable leave routing, recipient reauthorization and server-side outbox/dispatcher. Actual transport requires external configuration below. |
| Polish | Manrope/teal design, lazy lists, thumbnails, compressed private media, reduced-motion/data-saver mode, <=3 GB Android defaults, accessible scanner controls/large-text fixes, skeleton startup, bulk cache decoding off the UI thread and redacted diagnostics. |

## Supabase verification

The connected project `lhjfprlqsuhtiuckeniq` has **eight deployed migrations**, covering the original contract, attendance/notices, learning/messages, leadership, notification actions, large-school pages, substitution scope and performance indexes. The `dispatch-school-alerts` Edge Function is deployed.

The final build enables the real repositories with `ENABLE_SCHOOL_DATA=true`; this flag does not seed records. Auth settings return HTTP 200. Anonymous mobile-context/write requests and unauthorized dispatcher calls return HTTP 401.

Actual live-database role checks ran inside a transaction and rolled back: assigned roster access, attendance writes, parent RLS, unrelated-child denial, homework/grade visibility, server-wins grade conflict, parent emergency denial, leave approval, principal summary and audit history. Final counts remain **0 users, schools, students, homework, grades, leave requests, messages, notices, assets and notification-queue records**. No test school/account/student was left behind.

Every public table has RLS enabled. The `school-files` bucket is private, with JPEG/PNG/PDF and 10 MB limits. Only the public publishable client key is shipped. Secret/service-role keys are absent from Flutter and the source archive. Rotate privileged credentials previously shared in chat before real deployment.

The performance advisor now has no performance warnings: only unused-index information is expected on empty tables. The security advisor retains 33 authenticated SECURITY DEFINER notices for intentionally guarded APIs/helpers and two no-policy information notices for RPC/server-only device/outbox tables. These are documented design choices, not a claim of independent security certification. See [Supabase's SECURITY DEFINER review guidance](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).

## Validation evidence

| Check | Result |
|---|---|
| Flutter static analysis | Clean, no issues |
| App/SQLite/unit/widget tests | **41 passed**; 9 optional capture cases excluded from this normal run |
| Optional visual captures | **9 passed**, rendered with bundled fonts |
| Isolated PostgreSQL tests | **68 checks passed**, including 501-student and 501-grade pagination, privacy, idempotency, conflicts, quiet hours and substitute permissions |
| Dispatcher | Deno type check and **3 authorization tests passed** |
| Final APK | Successful release build, installed on Android API 36 emulator |
| Native smoke | Login, teacher preview and attendance empty state verified; both widget providers registered; zero Flutter/Android runtime errors after the widget lookup correction |
| Existing payments | Source byte-for-byte unchanged against the original delivered source archive |
| iOS files | Plists and project structure checked; extension source included, **not Xcode-built or device-tested** |

The final emulator cold launch measured **3.644 seconds**. A busy host and an earlier emulator System UI ANR affected this environment; the about-two-second cold-start target is **not certified**. Measure and profile on a physical mid-range phone before rollout. No live-account camera upload, biometric enrollment, populated widget or real push delivery is claimed from an empty-account preview.

## External setup and remaining validation

1. **Real accounts/data:** provision actual school records and active memberships through trusted administration. Zero accounts exist by request, so a real email/password sign-in and end-to-end user file transfer need genuine provisioned accounts.
2. **Push:** provide the public Firebase app identifiers/build values, configure APNs for Apple devices, and set server-only `FCM_SERVICE_ACCOUNT` and `DISPATCH_SECRET`. Add a trusted scheduler for the dispatcher. Until then device push is unavailable; the app explains this. Emergency alerts use the highest configured channel/time-sensitive priority available, without bypassing OS permissions.
3. **Apple:** use macOS/Xcode, a signing team, Push Notifications capability and the App Group `group.app.schoolday.schoolerp` for Runner/SchooldayWidgets. Validate WidgetKit, biometric and background behavior on real Apple devices. iOS screenshot prevention is OS-limited; the app covers private reports in app-switcher/background transitions.
4. **Crash transport:** set a public `SENTRY_DSN` to enable delivery. With no DSN, remote crash reporting is off; local redacted categories remain. Replay, screenshots and view-hierarchy capture are disabled.
5. **Release:** supply production signing, required store/privacy information and real-device acceptance tests. Some upstream plugins emit AGP/Kotlin compatibility notices; this tested toolchain uses the current compatible opt-out settings.

## Manual acceptance sequence

Use real staff/parent accounts after provisioning: publish homework with a photo and due date, submit a scanned PDF as a linked parent, review feedback, message an approved contact, switch children, enter marks from two devices to check server-wins behavior, request/approve leave, inspect audit history, opt into native widgets and verify logout clearing. Repeat attendance and messaging offline across restart, reconnect and inspect pending/synced status. Test notification permissions, quiet hours and actual emergency/leave delivery after Firebase/APNs setup. Use large text, data saver and screen-reader navigation.

## Changed source and handover

- `core/school_features.dart`, `core/media.dart`, the existing SQLite/sync/background layer: interchangeable feature gateway, offline operations, scoping, private media and cache lifecycle.
- `features/homework.dart`, `scanner.dart`, `messages.dart`, `academics.dart`, `leave.dart`, `leadership.dart`, `report_card.dart`, `timetable_edit.dart`, `alert_preferences.dart`, `feed.dart`: feature screens and real API integration.
- Shared app/header/components, `core/alert_router.dart`, attachments, charts, skeletons and diagnostics: navigation, child selection, performance and accessibility.
- Android MainActivity/widget/provider resources and iOS AppDelegate/WidgetKit target: native functionality.
- `supabase/migrations`, the dispatcher and `tools/sql-tests`: deployed contracts and isolated authorization/scale checks.
- `docs/phase-2-report.md`, `phase-3-report.md`, `phase-4-report.md`: per-phase implementation/manual-test notes. Phase 1 documents describe the earlier historical delivery; this report supersedes its disabled-data/remaining-phase statements.

New dependencies and reasons: `image_picker` camera; `flutter_image_compress` resizing/EXIF removal; `path_provider` private persistence; pinned `cached_network_image`/`flutter_cache_manager` bounded thumbnails and cleanup; `image`/`pdf` English-only crop/enhance/PDF export; `local_auth` biometric reports; `quick_actions` launcher shortcuts; `home_widget` native widget storage/updates; pinned compatible `sentry_flutter` 9.x optional redacted reporting. Existing date-formatting `intl` remains; no new app localization libraries or language switchers were added.

Existing out-of-scope **Fees/statement/payment-history UI and invoice adapter remain**. No new payment gateway, UPI, receipts, fee reminders, bus/GPS, QR/ID, pickup/visitor, Live Activities, Dynamic Island or language-support features were built. PDF dependencies include unused transitive barcode helpers; there is no QR/barcode feature in the app.
