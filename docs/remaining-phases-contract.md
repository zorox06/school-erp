# Remaining phases — declared contracts

Keep existing Flutter navigation, ChangeNotifier state and repository interfaces. No seeded business records and no replacement of working screens. Existing fee interfaces remain unchanged. Preview must remain isolated from actual accounts, files, queued writes and device registration.

## Phase 2

Normalized tables: `erp_homework`, `erp_homework_classes`, `erp_assets`, `erp_submissions`, `erp_conversations`, `erp_messages`, `erp_assessments`, `erp_grades`, `erp_leave_requests`, `erp_notification_preferences`. Link every record to a school and an authorized class, child, author or conversation. Private bucket `school-files`; uploads require an authorized reserved asset and are bounded by MIME/size. No public storage URLs.

RPC contracts:
- `erp_workspace(school, child)` returns bounded role/child-scoped learning, schedule, exam, grade, conversation, leave and feed records. Child must be owned/assigned to the caller; missing parent child returns empty child-specific lists.
- `erp_learning_page(school, child, kind, after, limit)` paginates homework/worksheets.
- `erp_contacts(school, child)` returns only teachers and families linked through the caller's authorized classes/children.
- `erp_messages_page(school, conversation, after, limit)` checks participants and paginates messages.
- `erp_write(school, kind, operation_id, payload)` dispatches validated, idempotent homework/submission/message/grade/leave writes. It returns the authoritative item and a conflict flag. Grade writes require expected version; a stale write returns the server's version without overwriting it.
- `erp_reserve_asset(school, asset_id, kind, linked_id, mime, bytes)` authorizes the upload context; `erp_finish_asset(school, asset_id)` checks private storage metadata before making it usable.
- `erp_asset_access(school, asset_id)` returns a private storage path only to the author or an authorized consumer of its linked work.
- `erp_save_preferences(school, preferences)` updates only the authenticated user's category/quiet-hour settings. Native timezone identifier is supplied rather than an ambiguous timezone abbreviation.

SQLite uses the existing scoped cache/outbox, with generic feature operations added. Media is copied/compressed to app-private persistent files; write queue stores local references, reserves/uploads assets on reconnect, and only then commits the school record. Retries reuse operation/asset IDs. Server results never remove a newer in-flight local edit. Parent and student views filter by child on both server and client. Switching children immediately clears the previous child's visible records before the next cache/remote load.

Dependencies: image_picker (camera), flutter_image_compress (compression/EXIF stripping), image and pdf (English-only crop/enhance/PDF export), path_provider (private media persistence), cached_network_image (bounded thumbnail disk cache).

## Phase 3

Add authenticated principal summary, school emergency, leave-decision and audit-page RPCs. School-wide emergency broadcasts require leadership. Attendance/grade changes persist actor/before/after/time. Push leave approvals are re-authorized on receipt and queued if offline. Add Android/iOS launcher shortcuts and native timetable/homework widgets, clearing their data on signout. Report cards use a snapping sheet protected by local biometrics and re-lock on lifecycle changes. Native files stay private and use platform document viewers.

## Phase 4

Data-saver mode disables auto image loads, blur and nonessential motion; default it on for Android low-RAM/<=3 GB devices. Use lazy/paginated collections, bounded images, skeletons, accessible controls and redacted local failure logging. Optional crash delivery requires an explicitly configured public Sentry DSN; never send user data, school content or credentials in crash reports. Cold start is measured separately from VM boot and is not certified from emulator launch time alone.

## Deployment

Supabase Auth and the guarded mobile/domain contracts are deployed. The Supabase connector supplied schema-management access; live authorization checks completed inside a rolled-back transaction. Provision no school/user/example rows during deployment. Actual end-to-end authorization tests must be isolated and rolled back, not fake records left in the school project. Firebase/APNs project settings, Apple signing/App Group identifiers and any crash-reporting DSN are external configuration; do not claim delivery/build verification without them.
