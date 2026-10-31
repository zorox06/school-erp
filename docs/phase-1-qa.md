# QA audit report — Phase 1 scope

## Evidence scope

Inspected Flutter/Supabase source, Android/iOS hosts, lockfiles and test output. Executed real SQLite transactions, isolated PostgreSQL migrations/RLS contracts, Flutter UI tests and server dispatcher authentication tests. This is a Phase 1 implementation review, not a full production security audit.

Unavailable: deployed Supabase schema/policies, real school accounts, Firebase/APNs settings, physical devices, iOS compilation, production telemetry and release signing identity. No Git history or CI pipeline was present for change-rate/DORA analysis. Android APK install, launch and empty teacher/attendance navigation were verified in the emulator after dismissing its unrelated System UI ANR. Confidence is high for the locally asserted behavior and unknown for real push delivery and deployment configuration.

## Critical findings

No confirmed critical vulnerability remains in the inspected Phase 1 paths. This does not certify the unavailable production configuration.

## Confirmed release limitations

- Development signing remains in `android/app/build.gradle.kts:37`. This is an installable development handoff, not a store-release identity.
- Push configuration is optional and absent (`lib/core/phase_one/push.dart:9`). No delivery test was possible; token/permission/platform behavior needs real configured devices.
- The SQL file is optional/unapplied and live data is disabled. Local PostgreSQL RLS tests do not prove the remote project has those policies.

## Test quality scorecard

- SQLite persistence/queue logic is real (`store.dart:18`); only network responses are substituted in sync tests. Database failures exercise rollback, not an imagined mock transaction.
- Assertions cover persisted rows, permissions, retry state, cross-account isolation and a stale acknowledgement racing a newer edit (`store.dart:239`). Logout tombstones (`store.dart:55`) are tested against late writes.
- PostgreSQL tests apply both actual migrations and exercise assigned/unassigned classes, unrelated guardians, role escalation, revoked memberships and direct write restrictions. They use an auth fixture in isolated PGlite, not a real Supabase JWT gateway.
- UI tests assert roster virtualization with 500 fixtures and offline acknowledgement in a snapping sheet. Fixtures are test-only and are not app startup seeds.
- Optional screenshots are for visual inspection; behavior tests do not rely on blindly updated goldens.
- Property-based tests: absent. Broad load/chaos testing: not performed. No coverage percentage is used as a readiness claim.

## Security posture

IDOR/class/guardian scope is covered in SQL contract tests. JWT parsing and issuer/signature validation are delegated to Supabase; actual gateway attacks are untested. Authenticated clients cannot provision their own roles. Dispatcher authentication is fail-closed and tested; dispatch claim permissions are server-only (`202610310001_phase_one.sql:258`). User-generated attendance is validated and authorized in the server RPC (`202610310001_phase_one.sql:127`). No raw tokens, names or message bodies are written into sync-failure logs.

SSRF: the dispatcher uses fixed Google/Supabase deployment endpoints; it does not fetch a URL supplied in an incoming request. Dependency CVE audit is not comprehensive; npm's SQL-tool install reported zero findings. This is not a Flutter/native dependency vulnerability certification.

## Reliability and architecture

Repository interfaces remain. SQLite cache/outbox writes commit atomically (`store.dart:162`). Accepted responses delete only the exact queued operation, preserving an in-flight newer change. Permission failures remain visible/blocked, transient failures back off, and server deltas preserve pending local drafts. Context fallback is bounded to seven days (`cached_repository.dart:7`). Server attendance revisions serialize per school to avoid cursor holes from uncommitted lower revisions.

Role enforcement is independent of UI navigation. Roster and notices use builder-based lists (`attendance.dart:12`, `notices.dart:127`). Physical 3 GB-device memory/performance remains unknown. Push uses at-least-once delivery with stable identifiers; exactly-once delivery is not claimed.

## Delivery health

Deployment frequency, lead time, change-failure rate and MTTR are unknown without production/Git evidence. No CI configuration is supplied. Local lint/tests/build are recorded in the Phase 1 report. The previous delivered source/APK is preserved separately for rollback; database deployment remains a reviewed administrative action.

## Immediate action

Before a real school pilot, configure an isolated real Supabase/Firebase environment and run the account/class/guardian, offline-resume and physical push scenarios in `phase-1-report.md`. Keep `ENABLE_SCHOOL_DATA=false` until provisioning and authorization checks are verified.

## Following delivery work

Phase 2: typed learning/messaging/marks workflows with server-authoritative grade conflicts. Phase 3: native widgets, principal/emergency/report-card features and audit UI. Phase 4: physical-device performance/accessibility, data-saver tuning, crash reporting and production delivery configuration. No dates or staffing assumptions were supplied, so no invented three-month schedule is assigned.
