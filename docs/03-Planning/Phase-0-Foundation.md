# Phase 0 — Foundation

Goal: an empty but *real* app — themed, localized, navigable, with the database and platform plumbing in place — so every later phase is pure feature work. Architecture references: [[Architecture-Overview]].

## M0.1 — Project scaffold
- [x] Flutter project (`com.harvest.app`), Android min SDK 26, target latest
- [x] Strict lints (`very_good_analysis` or equivalent), CI-ready analyze+test script
- [x] Folder layout per [[Architecture-Overview]] (app/ core/ features/)
- [x] Riverpod + codegen wired ([[State-Management]]); build_runner workflow documented
- [x] `go_router` shell: Field, Stats, Settings tabs (empty screens)

## M0.2 — Design system
- [x] Token file: palette, spacing, radii, type scale ([[Theming-and-Design-System]])
- [x] Light + dark `ThemeData`, `ThemeMode` setting persisted
- [ ] Nunito + Arabic companion font bundled
- [ ] Signature components v1: CropCard, StreakFlame, XPBar, BigBouncyButton
- [ ] Golden tests: each component × {light, dark} × {LTR, RTL}

## M0.3 — Localization
- [x] gen-l10n configured; `app_en.arb`, `app_ar.arb` ([[Localization]])
- [x] In-app language switcher (system/en/ar), persisted
- [ ] RTL audit checklist added to PR template

## M0.4 — Database
- [x] Drift set up with schema v1 ([[Local-Database]]): commitments, check_ins, streaks, ledger, quests, pomodoro_sessions, outbox, settings
- [x] Repository interfaces in domain + Drift implementations
- [x] `HarvestDay` value type + 3 AM boundary logic with unit tests ([[Business-Rules]])
- [ ] Migration test harness

## M0.5 — Platform plumbing
- [x] `flutter_local_notifications` init, channels, permission flow ([[Notifications-and-Background]])
- [x] `workmanager` 3 AM job registered + lazy-on-open fallback (no-op body for now)
- [x] Haptics wrapper

**Exit:** the shell runs on a device in both languages and themes; `flutter test` green.
