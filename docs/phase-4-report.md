# Phase 4 report

Completed source: low-RAM data saver defaults, reduced route/tab motion, manual image loading, cached resized thumbnails, compressed private uploads, lazy screen lists, large-text fixes, accessible scanner crop controls, subject charts with spoken values, a skeleton first view, deferred optional SDK startup, off-main large-cache decoding, redacted crash/sync logging and session-safe cleanup.

Key files: `core/diagnostics.dart`, `media.dart`, `school_features.dart`, `phase_one/store.dart`, `main.dart`, `app.dart`; `ui/skeleton.dart`, `components.dart`, `subject_chart.dart`, `attachments.dart`; scanner and shared child header. Sentry is pinned to a compatible 9.x release to retain Android API 24 support. No new localization libraries were added. Existing `intl` date formatting remains.

Manual test: enable Data saver in Account; navigate and verify reduced motion/manual thumbnails. Test large system text and screen-reader labels. Edit attendance offline, restart and reconnect; verify pending state/retry. Sign out during network activity, then verify no school records or widget contents reappear. Test cold start on a real mid-range phone in release mode; the about-two-second target is not claimed from an emulator or boot skeleton alone.

Validation results, release size and outstanding external setup are in `final-report.md`. Native iOS compilation and real push delivery remain outside this Windows environment’s verification capabilities.
