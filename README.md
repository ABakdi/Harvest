# 🌱 Harvest

*Cultivate your day. Harvest your potential.*

Harvest is a gamified life-management app I'm building with Flutter. It
takes the streak psychology that keeps people coming back to Duolingo and
points it at the four pillars of an ordinary day — productivity, money,
health, and focus — while staying minimalist, local-first, and entirely
under my control. No accounts, no cloud, nothing leaves the phone.

**Status:** v1 candidate. Productivity core and finances are complete and
in daily use; gym & health is next. Grab the latest build from the
[releases page](https://github.com/ABakdi/Harvest/releases).

## Table of contents

- [What it does](#what-it-does)
- [Screens](#screens)
- [Install](#install)
- [Documentation](#documentation)
  - [Overview](#overview)
  - [Specification](#specification)
  - [Architecture](#architecture)
  - [Planning](#planning)
  - [Checkpoints](#checkpoints)
  - [Audit](#audit)
  - [Decisions](#decisions)
- [Stack](#stack)
- [Development](#development)
- [Project layout](#project-layout)
- [Roadmap](#roadmap)
- [Privacy](#privacy)

## What it does

- **The Field** — every habit, project, and to-do due today as a crop on
  one screen. One tap checks in; a streak flame, XP bar, and farmer ranks
  keep score. Projects log quantities toward a target with a 2× daily cap.
- **Streaks that forgive** — a global streak fed by a Daily Harvest Goal,
  per-commitment streaks, streak freezes bought with coins, and a 3 AM day
  boundary so a 1 AM check-in still counts for the evening it belongs to.
- **The plan ritual** — an evening planner and a morning review, each
  reachable straight from its reminder; reminders escalate from gentle to
  urgent and learn the best time to nudge.
- **Focus timer** — a pomodoro attached to any commitment, adjustable
  block lengths, a live mini-timer in the app bar, and pause/abandon from
  the notification shade.
- **The Granary** — expense quick-log in under five seconds, a monthly
  budget with a floating daily limit and a green/amber/red gauge, smart
  repeat suggestions, custom categories, multi-currency (DZD, USD, EUR)
  with exchange rates, weekly and monthly charts.
- **The Vault** — wallet, savings pots per currency, and debts, each with
  its total and its own transaction ledger that says what every move was.
- **Notes that carry over** — a note per seed per day, so tomorrow's
  sheet opens with yesterday's quoted above it: *stopped on page 143*.
  Today's shows on the card, and the whole run is in the seed's history.
- **A seed's own screen** — its streak, its best, an eight-week strip of
  the days you showed up, and a timeline of everything you logged and
  wrote, day by day.
- **Archive, and delete** — retiring a seed asks why, and the answer is
  kept with it on the Archive screen; restore it, or delete it for good
  with its whole history, confirmed first.
- **It notices when you stop** — miss a day, three, a week, a fortnight,
  a month, and Harvest says something warm and gets out of the way.
  Never more than one a day, never any shame.
- **Home-screen widget** — the streak, today's field, your rank. Tap to
  open.
- **Calendar and stats** — a month view of everything due, an activity
  heat-map, project burn-up, habit streaks, and a weekly harvest report.
- **The lock and the export** — the whole app behind your phone's own
  fingerprint or PIN, and one tap to drop every row into a spreadsheet
  in Downloads with the totals as live formulas.
- **Five looks, two languages** — Harvest, Sunrise, Ocean, Orchard, and
  Dusk presets, each light and dark, in English and Arabic with full RTL.

## Screens

| Field | Granary — Today | Granary — Vault |
| :---: | :---: | :---: |
| Today's crops, streak, XP, budget pulse | Budget gauge and the day's expenses | Wallet / Savings / Debts, each with its ledger |

## Install

Android only for now (API 26+).

1. Download the APK from the latest
   [release](https://github.com/ABakdi/Harvest/releases).
2. Allow installs from unknown sources when the phone asks.
3. Open Harvest and plant your first seed.

From v0.9.5-beta the release is signed with a real upload key. Builds up
to v0.9.4-beta went out on the debug keystore, and Android will not
install over a differently-signed APK — so if you are on one of those,
export your data first (Settings → My data), then uninstall before
installing a newer build.

## Documentation

Everything about Harvest — what it is, how it works, how it's built, and
in what order — lives in the [`docs/`](docs/Home.md) Obsidian vault.
Start at the [vault home](docs/Home.md) or jump straight in below.

### Overview

| Note | What's in it |
| :--- | :--- |
| [Vision](docs/00-Overview/Vision.md) | Why the app exists and what it must feel like |
| [Product Requirements](docs/00-Overview/Product-Requirements.md) | The consolidated PRD |
| [Glossary](docs/00-Overview/Glossary.md) | The farming vocabulary and entity names |

### Specification

| Note | What's in it |
| :--- | :--- |
| [Core Entities](docs/01-Specification/Core-Entities.md) | The data model: projects, habits, to-dos, and friends |
| [Productivity Engine](docs/01-Specification/Productivity-Engine.md) | Commitments, check-ins, the daily plan ritual |
| [Gamification](docs/01-Specification/Gamification.md) | Streaks, XP, coins, ranks |
| [Pomodoro](docs/01-Specification/Pomodoro.md) | The focus timer |
| [Notifications](docs/01-Specification/Notifications.md) | The gentle-to-urgent reminder system |
| [Finances](docs/01-Specification/Finances.md) | Expense logging, budgets, the vault |
| [Health and Gym](docs/01-Specification/Health-and-Gym.md) | Sleep tracking, alarm, workouts |
| [Screen Time](docs/01-Specification/Screen-Time.md) | Usage caps and interventions |
| [Onboarding](docs/01-Specification/Onboarding.md) | First-run experience |
| [Dashboard and Widgets](docs/01-Specification/Dashboard-and-Widgets.md) | Home screen, reports, widgets |
| [Business Rules](docs/01-Specification/Business-Rules.md) | The immutable rules: day reset, over-log cap, … |

### Architecture

| Note | What's in it |
| :--- | :--- |
| [Architecture Overview](docs/02-Architecture/Architecture-Overview.md) | Layers, data flow, package layout |
| [State Management](docs/02-Architecture/State-Management.md) | Riverpod conventions |
| [Local Database](docs/02-Architecture/Local-Database.md) | Drift schema, repositories, migrations |
| [Sync Strategy](docs/02-Architecture/Sync-Strategy.md) | Local-first now, MongoDB sync later |
| [Theming and Design System](docs/02-Architecture/Theming-and-Design-System.md) | Presets, type, components, motion |
| [Localization](docs/02-Architecture/Localization.md) | English + Arabic, RTL |
| [Notifications and Background](docs/02-Architecture/Notifications-and-Background.md) | Scheduling, the 3 AM reset, alarms |

### Planning

| Note | What's in it |
| :--- | :--- |
| [Roadmap](docs/03-Planning/Roadmap.md) | All phases at a glance |
| [Phase 0 — Foundation](docs/03-Planning/Phase-0-Foundation.md) | Scaffold, design system, l10n, DB ✅ |
| [Phase 1 — Productivity Core](docs/03-Planning/Phase-1-Productivity-Core.md) | The MVP ✅ |
| [Phase 2 — Finances](docs/03-Planning/Phase-2-Finances.md) | Expenses, budgets, gauge ✅ |
| [Phase 3 — Health and Gym](docs/03-Planning/Phase-3-Health-and-Gym.md) | Sleep alarm and debt, workouts |
| [Phase 4 — Screen Time](docs/03-Planning/Phase-4-Screen-Time.md) | Usage caps, interventions |
| [Phase 5 — Sync and Social](docs/03-Planning/Phase-5-Sync-and-Social.md) | Accounts, sync, rankings, widgets |

### Checkpoints

| Note | What's in it |
| :--- | :--- |
| [Checkpoint 1](docs/05-Checkpoints/Checkpoint-1.md) | Road to v1: progress review, bugs, gap list, and the dogfooding rounds |
| [Checkpoint 2](docs/05-Checkpoints/Checkpoint-2.md) | The app lock and the spreadsheet export |
| [Checkpoint 3](docs/05-Checkpoints/Checkpoint-3.md) | Eleven things a fortnight of living with it turned up |

### Audit

| Note | What's in it |
| :--- | :--- |
| [Audit Home](docs/06-Audit/Audit-Home.md) | The code, security and UX audit: method, counts, remediation status |
| [Security Audit](docs/06-Audit/Security-Audit.md) | Android surface, data at rest, backups, notifications, inputs, signing |
| [Code Quality Audit](docs/06-Audit/Code-Quality-Audit.md) | Correctness, error handling, state management, duplication, tests |
| [UX Audit](docs/06-Audit/UX-Audit.md) | Every screen, component by component: keep, simplify, merge, remove |

### Decisions

| ADR | Decision |
| :--- | :--- |
| [ADR-001](docs/04-Decisions/ADR-001-State-Management.md) | Riverpod over Bloc |
| [ADR-002](docs/04-Decisions/ADR-002-Local-Database.md) | Drift over Isar / Realm / Hive |
| [ADR-003](docs/04-Decisions/ADR-003-UI-Toolkit.md) | Material 3 + a custom design system |
| [ADR-004](docs/04-Decisions/ADR-004-Localization.md) | gen-l10n with ARB files |
| [ADR-005](docs/04-Decisions/ADR-005-Local-First-Sync.md) | Outbox pattern toward MongoDB |

## Stack

- **Flutter** (Android first, iOS next) · Material 3 + a custom design system
- **Riverpod** (codegen) for state · **Drift**/SQLite for local-first storage
- **fl_chart** for charts · **table_calendar** for the calendar
- **flutter_local_notifications** + **workmanager** for reminders and the 3 AM reset
- **English + Arabic** with full RTL support via gen-l10n
- Local-first forever; server sync (MongoDB) arrives in Phase 5

## Development

```sh
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```

Schema changes follow the migration workflow in
[Local Database](docs/02-Architecture/Local-Database.md): bump the
version, write the step, dump and generate the schema, add the upgrade
test. Signature components have golden coverage in `test/goldens`
(regenerate with `flutter test --update-goldens test/goldens`).

### Release builds

Signing material lives outside the repo. Create the keystore once and
point `android/key.properties` (git-ignored) at it:

```sh
keytool -genkey -v -keystore ~/keys/harvest-upload.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias harvest
```

```properties
storeFile=/home/you/keys/harvest-upload.jks
storePassword=…
keyAlias=harvest
keyPassword=…
```

Without the file, release builds fall back to the debug key with a
warning (fine for a dev machine, never for distribution). Release builds
shrink and obfuscate; keep the symbol map with the tag you ship:

```sh
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

Toolchain pinned for reproducible builds: Flutter 3.47.2 (Dart 3.13),
JDK 21, Android minSdk 26.

## Project layout

```
lib/
  app/            router, shell, bootstrap
  core/
    db/           Drift database and migrations
    domain/       HarvestDay and other shared rules
    platform/     haptics, day reset, notifications glue
    ui/           theme, tokens, shared widgets
  features/
    commitments/  habits, projects, to-dos, check-ins
    field/        the dashboard
    gamification/ streaks, XP, coins, ranks
    planner/      plan ritual and notification planning
    pomodoro/     the focus timer
    finances/     expenses, budget, vault
    calendar/     month view
    stats/        heat-map, reports
    settings/     preferences, rates
    security/     the app lock
    export/       the spreadsheet workbook
    widget/       the home-screen widget
    onboarding/
  l10n/           ARB files (en, ar)
assets/icon/      the olive-branch launcher icon and its SVG sources
docs/             the Obsidian vault
drift_schemas/    exported schema snapshots (v1 … v9)
test/             unit, migration, and golden tests
```

## Roadmap

| Phase | Delivers | Status |
| :--- | :--- | :---: |
| 0 — Foundation | Scaffold, design system, l10n, DB, routing | ✅ |
| 1 — Productivity Core | Commitments, plan ritual, streaks, XP, pomodoro, notifications | ✅ |
| 2 — Finances | Expense quick-log, budgets, gauge, vault | ✅ |
| 3 — Gym & Health | Sleep alarm + debt, workout plans & sessions | next |
| 4 — Screen Time | Usage caps, weed-pull interventions | |
| 5 — Sync & Social | Accounts, MongoDB sync, rankings, iOS polish | |

The compact home-screen widget came forward out of phase 5 in
[Checkpoint 3](docs/05-Checkpoints/Checkpoint-3.md) — nothing about a
widget needed a sync server.

Working rule: each phase ends with a tagged release I install and live
with before starting the next — dogfooding is the QA department.

## Privacy

Everything is stored on the device in a local SQLite database. Financial
data never leaves the phone in plaintext. When sync arrives it will be
opt-in and end-to-end encrypted, or you keep everything local. Nothing is
sold, nothing is shared.
