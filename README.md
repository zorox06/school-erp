# Schoolday 1.4

Flutter/Dart School ERP with separate parent, teacher, student, principal and admin workspaces. The teal/cream Manrope interface follows the supplied Schoolday Figma direction and improves empty states, shared navigation, quick actions and accessibility.

## Build and run

Use Flutter 3.47.5 / Dart 3.13.4. Android supports API 24+; the iOS host targets iOS 15+ and requires macOS/Xcode for validation and signing.

```powershell
Copy-Item config/build.public.json config/supabase.local.json
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config/supabase.local.json
.\build-desktop.ps1
```

The build script creates a debug APK for local testing. For a signed release use `./build-desktop.ps1 -Release`. Configure the ignored `android/key.properties` with `storeFile` (absolute path or relative to the android directory), `storePassword`, `keyAlias` and `keyPassword`. Release packaging requires all four settings and a private keystore.

## Shared Supabase backend

Both clients use the public configuration for the shared Supabase project. Its configured hostname failed DNS resolution during the latest verification. All migration files in `supabase/migrations` have been applied, and `dispatch-school-alerts` is deployed. `ENABLE_SCHOOL_DATA=true` enables the real repositories; it does not seed any records. Public client configuration is in `config/build.public.json`. School names, identities and business figures remain null until actual records exist; collections are empty.

Create real accounts through trusted Supabase administration, then link profiles, active school memberships, classes, students, guardians and teacher assignments. The app cannot self-assign privileges. A valid account without a membership sees the school-access gate. No account or password has been invented for this delivery.

The private `school-files` bucket accepts JPEG/PNG/PDF up to 10 MB. Every upload first reserves an authorized asset, then verifies storage metadata. Downloads require signed access and server authorization. The client contains no secret/service-role key. Rotate privileged keys previously shared in chat before a real school rollout.

## What works

- Offline teacher attendance: Present drafts, exception taps/reasons, explicit save, undo, mark-all, haptics and queued delta sync.
- Paginated circulars with offline read/acknowledgement and snapping detail sheets.
- Camera homework with due date/multiple classes, private attachments, document crop/enhance/rotate/PDF submissions and teacher feedback.
- Approved family/staff contacts, searchable conversations, message templates, cached message history and paginated older messages.
- Shared child avatar switcher; child-scoped learning, attendance, conversations and existing statements. Child changes close old detail routes.
- Assessment creation, numeric marks grid with next-field navigation, per-assessment grade pages and server-wins version conflicts. Exams/countdowns and subject charts.
- Snapping leave requests/report-card preview. Local biometric report lock re-locks on lifecycle or account/child changes.
- Principal daily summary with coverage, actual absent-teacher records, leave approval/decline, emergency broadcasts and paginated audit history.
- Timetable/substitute updates; a substitute sees their lesson without receiving permanent student/class access.
- Role-specific launcher shortcuts and native Android/iOS timetable/homework widgets. Widgets require explicit opt-in and clear on sign-out.
- Category alert preferences, teacher/device quiet hours, urgent/emergency channels and actionable leave routing.
- SQLite outbox and per-account caches, persistent compressed media, bounded thumbnails, low-RAM data saver, reduced motion, skeleton boot view, background retries, off-main bulk cache decoding and redacted diagnostics.

## External setup still required

Push transport cannot deliver until Firebase/APNs and a trusted scheduler are configured. Supply public Firebase build values: `FIREBASE_PROJECT_ID`, `FIREBASE_SENDER_ID`, `FIREBASE_API_KEY`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_APP_ID`. Upload the app identifiers to the matching Firebase project. On the server, set `FCM_SERVICE_ACCOUNT` and `DISPATCH_SECRET`, then schedule authenticated POSTs to the deployed dispatcher. These private values must never enter Flutter configuration. The dispatcher rejects app/anonymous calls and fails closed without its secrets.

Android notification permission/channels and iOS settings govern actual delivery; emergency priority does not bypass OS restrictions. iOS needs a signing team, Push Notifications capability, APNs authentication, and the `group.app.schoolday.schoolerp` App Group on Runner and SchooldayWidgets. The extension target and Swift WidgetKit source are included. Windows cannot compile or device-test iOS.

`SENTRY_DSN` is optional public build configuration. With no DSN, crash transport is off; local redacted error categories still work. Error payloads strip user, request, breadcrumb, message and school content. Do not enable replay/screenshots for school data.

## Verification

See `docs/final-report.md`, phase reports and test sources. Isolated fixtures never seed the live project. Live role checks run in a transaction and roll back. No physical mid-range-device cold-start, camera, biometric, APNs or live push delivery is certified by an emulator/UI test.

## Replace Supabase later

Keep screens and `AppController`. Replace `AuthRepository`, `SchoolRepository`, `PhaseOneRemote` and `SchoolGateway`. The gateway wraps feature RPCs and private file storage; the local SQLite cache/outbox remains separate. Preserve school/role/child authorization and the documented write/conflict contracts on your replacement server.

## Existing excluded functionality

The existing Fees/statement/payment-history screens and invoice adapter remain; no payment gateway or other new payment feature was added. No bus/GPS, QR/student-ID, pickup/visitor, Live Activities or language-switching functionality was added. PDF dependencies contain transitive barcode utilities, but the app does not implement QR/barcode features.

## Coordinating mobile and web

The [web client](https://github.com/zorox06/school-erp-web) uses the same Supabase accounts, school roles, RPCs and private bucket. Mobile owns the migrations and shared fee examples. From the web checkout, run `node scripts/mobile-contract.mjs "../school erp"` after backend or configuration changes. Append `--sync` to refresh its contract fixtures and public defaults, then run the browser suite. A live release requires the same reachable project URL and publishable key in both builds.
