# Phase 1 contract (declared before implementation)

Keep Flutter's existing ChangeNotifier, Navigator and repository boundary. Empty preview must never fetch, queue or seed school records. Existing fee interfaces are retained without extension. The newer brief adds admin, principal and student roles alongside parent/teacher.

## Backend additions

An optional second Supabase migration extends trusted `school_memberships` roles. Add normalized `erp_students`, `erp_class_students`, `erp_class_teachers`, `erp_guardians`, `erp_attendance`, `erp_notices`, `erp_notice_receipts`, `erp_device_tokens`, `erp_notification_outbox` and `erp_audit_events`. Class records reference existing `school_content` class IDs. No inserts of business/example records. No automatic deployment.

Authenticated, permission-checked RPCs:

- `erp_roster(school, class, after, limit)` returns a keyset-paginated authorized roster.
- `erp_sync_attendance(school, changes)` validates class/child scope, accepts idempotent operation IDs and returns authoritative records. Draft changes use last-write-wins with a bounded client timestamp and deterministic operation-ID tie breaker. Committed marks/grades are not introduced in Phase 1 and must be server-authoritative in Phase 2.
- `erp_attendance_delta(school, cursor)` returns an authorized bounded delta using a server revision cursor protected by a per-school transaction lock.
- `erp_notices(school, child, after, limit)` returns paginated authorized notices and this user's receipt.
- `erp_notice_receipt(school, notice, acknowledge)` records a read and optionally acknowledgement idempotently.
- `erp_publish_notice(school, title, body, important)` requires staff and creates a school circular.
- `erp_register_device(school, token, platform)` binds a push token to the authenticated actor; `erp_unregister_device(token)` removes only that actor's binding.

Clients cannot modify memberships, guardian links, teacher assignments, notification dispatch or audit history. RLS and RPC checks apply independently of UI gating. Trusted administration provisions these relationships outside the mobile app.

## Offline behavior

SQLite tables cache school-scoped rosters, notices, attendance, delta cursors, an operation outbox, and redacted sync failures. An edit and queue entry commit in one transaction. Entries are scoped to authenticated user + school; logout removes that user's cache and queue. Acknowledgements only remove the exact version sent, preserving edits made during an in-flight request. Requests retry with bounded exponential backoff. Authorization/validation failures are blocked for review rather than retried forever. Network failure preserves all pending edits. A background job and foreground/resume timer attempt sync; neither promises exact OS scheduling.

Missing attendance rows render Present as an uncommitted draft. Opening a roster never writes an attendance record. Explicit Save register queues the full loaded register; exception changes queue immediately. A parent absence notification is emitted only after the server accepts an Absent transition, never merely from local draft UI. A deduplicated outbox is delivered by a server-only FCM dispatcher; no administrative credentials enter Flutter.

## Dependencies

- sqflite + path: transactional local SQLite and portable database paths.
- workmanager: OS-managed background queue retries.
- firebase_core + firebase_messaging: optional Firebase initialization and FCM token/message handling.
- flutter_local_notifications: Android channels and foreground notification presentation.
- sqflite_common_ffi (development only): real SQLite persistence/transaction tests on this Windows workspace.

Push requires real Firebase app options and trusted server FCM service-account configuration. The shipped empty build stays opt-out and usable without them. iOS host configuration can be generated here, but signed iOS compilation/device verification requires macOS/Xcode and APNs setup.

Development SQL checks use @electric-sql/pglite (PostgreSQL in WebAssembly); it is not shipped in Flutter. Device registration stores Firebase Installation IDs through the SDK’s onRegistered API; the legacy table/parameter name token is retained internally.
