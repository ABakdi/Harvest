# 🌱 Harvest

*Cultivate your day. Harvest your potential.*

Harvest is a gamified life-management app I'm building with Flutter,
with a web version and a sync server of its own. It
takes the streak psychology that keeps people coming back to Duolingo and
points it at the pillars of an ordinary day — what you get done, what you
spend, and in time what you do with your body and your attention — while
staying minimalist, local-first, and entirely under my control. No
telemetry, and nothing leaves the phone unless I ask: the account and
sync are optional forever.

The whole idea is one streak, fed by everything. Duolingo asks for a
lesson a day and that single anchor is enough to pull people back for
years — but it only covers one narrow slice of a life, and the bar never
moves. Here the bar is mine to raise, and the streak is fed by whatever
I decide matters this month.

**Status: v3.0 in beta — the phone, the web and the server.** On top
of v2's training log, sleep, steps and body weight, Phase 5 added a
goals board, a trail with every action pinned on a free map, and voice
notes; Phase 6 added an optional account, sync with the money and the
places end-to-end encrypted, and the whole app in a browser — which
now writes everything the phone writes, except what needs the phone
itself (alarms, steps, the trail, the widget, the lock). The latest
build is on the [releases page](https://github.com/ABakdi/Harvest/releases).

v2.0 went through four betas first: [Checkpoint 6](docs/05-Checkpoints/Checkpoint-6.md)
is the first week's findings, fixed, and the
[second audit](docs/06-Audit/Audit-v2-Beta.md) read the whole of the
new half and fixed what it found;
[Checkpoint 7](docs/05-Checkpoints/Checkpoint-7.md) is the ten things
the next days asked for; [Checkpoint 8](docs/05-Checkpoints/Checkpoint-8.md)
closes the day's steps on its own. The
[third audit](docs/06-Audit/Audit-v2.md) read v2.0.0 after release.

**Next:** `v3.0.0` proper once the beta has been lived in, then
[Phase 7](docs/03-Planning/Phase-7-Screen-Time.md), screen time. The
repository is a monorepo: `apps/mobile` (Flutter), `apps/web`
(React), `apps/server` (Express), the shared `packages/`, and
`deploy/` to run it all.

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
  reachable straight from its reminder; a nudge stops the moment its
  reason is gone, and four a day is the cap.
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
- **Home-screen widget** — a wide card with your streak, today's spend
  and wallet, what's still due cycling one card at a time, and two
  buttons to log an expense or plant a seed. Pick what it shows in
  Settings, and it shrinks to fit what you picked.
- **Calendar and stats** — a month view of everything due, an activity
  heat-map, project burn-up, habit streaks, and a weekly harvest report.
- **The lock and the export** — the whole app behind your phone's own
  fingerprint or PIN, and one tap to drop every row into a spreadsheet
  in Downloads with the totals as live formulas.
- **The Body** — a training log built for one hand between sets:
  programs with days and target sets (a weight, a % of a training max,
  or an open `1+`), a session screen where a set that went to plan is
  one tap, a rest timer you can type, a clock that pauses, the record
  to beat on every exercise, and days that go round. Beside it, last
  night written down in eight seconds with a sleep-debt gauge, steps
  from the phone's own health store, and a weight chart that shows the
  trend and never judges it.
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
installing v1.0.0. From v0.9.5-beta onward it updates in place.

From v1.1.0 the export is a zip that **imports**, so moving to a new
phone is: take an archive, install, bring it back.

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
| [Notifications](docs/01-Specification/Notifications.md) | The gentle-to-urgent reminder system, the comeback ladder, the daily cycle |
| [Notes](docs/01-Specification/Notes.md) | Markdown notes with links between them (Phase 3) |
| [Gallery](docs/01-Specification/Gallery.md) | Albums, the daily picture, the timelapse (Phase 3) |
| [Finances](docs/01-Specification/Finances.md) | Expense logging, budgets, the vault |
| [Wishlist](docs/01-Specification/Wishlist.md) | To buy vs. someday: two lists with estimated prices (Phase 6) |
| [Health](docs/01-Specification/Health.md) | Sleep, steps and body weight (Phase 4) |
| [Gym](docs/01-Specification/Gym.md) | Programs, sessions, sets and personal records (Phase 4) |
| [Goals](docs/01-Specification/Goals.md) | The board on the field: what it takes, and the seeds that get me there (Phase 5) |
| [Places](docs/01-Specification/Places.md) | The trail, a geotag on every action, the map (Phase 5) |
| [Accounts](docs/01-Specification/Accounts.md) | The optional account (Phase 6) |
| [Web](docs/01-Specification/Web.md) | The home page, the PWA, the app in a browser (Phase 6) |
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
| [Sync API](docs/02-Architecture/Sync-API.md) | The wire contract: records, push, pull, errors |
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
| [Phase 3 — Notes, Gallery and the Archive](docs/03-Planning/Phase-3-Notes-and-Gallery.md) | Markdown notes, photo albums, the zip archive and its importer ✅ |
| [Phase 4 — Health and Gym](docs/03-Planning/Phase-4-Health-and-Gym.md) | Steps, weight, the training log, sleep ✅ |
| [Phase 5 — Goals, Places and Voice](docs/03-Planning/Phase-5-Goals-Places-and-Voice.md) | Goals board, trail and geotags on a map, voice notes, read aloud, assist |
| [Phase 6 — Sync, Accounts and the Web](docs/03-Planning/Phase-6-Sync-Accounts-and-Web.md) | Express + MongoDB server, accounts, sync, the React web app and PWA |
| [Phase 7 — Screen Time](docs/03-Planning/Phase-7-Screen-Time.md) | Usage caps, interventions |
| [Phase 8 — Social and Reach](docs/03-Planning/Phase-8-Social-and-Reach.md) | Rankings, iOS |

### Checkpoints

| Note | What's in it |
| :--- | :--- |
| [Checkpoint 1](docs/05-Checkpoints/Checkpoint-1.md) | Road to v1: progress review, bugs, gap list, and the dogfooding rounds |
| [Checkpoint 2](docs/05-Checkpoints/Checkpoint-2.md) | The app lock and the spreadsheet export |
| [Checkpoint 3](docs/05-Checkpoints/Checkpoint-3.md) | Eleven things a fortnight of living with it turned up |
| [Checkpoint 4](docs/05-Checkpoints/Checkpoint-4.md) | Numbers on the charts, filterable money, and a day that keeps my hours |
| [Checkpoint 5](docs/05-Checkpoints/Checkpoint-5.md) | Records under one tab, and an editor worth writing in |
| [Checkpoint 6](docs/05-Checkpoints/Checkpoint-6.md) | Steps that count, one way to split a screen, and a gym that knows what day it is |
| [Checkpoint 7](docs/05-Checkpoints/Checkpoint-7.md) | Finish where the thumb is, a record's moment, and settings as a place |
| [Checkpoint 8](docs/05-Checkpoints/Checkpoint-8.md) | The day's steps written down at 3 AM, and an expense on the day it belongs to |
| [Checkpoint 9](docs/05-Checkpoints/Checkpoint-9.md) | The Wishlist, the web writing everything the phone writes, and a deployment I can run |

### Audit

| Note | What's in it |
| :--- | :--- |
| [Audit Home](docs/06-Audit/Audit-Home.md) | The code, security and UX audit: method, counts, remediation status |
| [Security Audit](docs/06-Audit/Security-Audit.md) | Android surface, data at rest, backups, notifications, inputs, signing |
| [Code Quality Audit](docs/06-Audit/Code-Quality-Audit.md) | Correctness, error handling, state management, duplication, tests |
| [UX Audit](docs/06-Audit/UX-Audit.md) | Every screen, component by component: keep, simplify, merge, remove |
| [Audit 2 — the v2 beta](docs/06-Audit/Audit-v2-Beta.md) | Business logic, what the specs never said, code quality and security, read again on the v2 beta |
| [Audit 3 — v2.0.0](docs/06-Audit/Audit-v2.md) | What changed since audit 2, the screens of the new half, the specs against the code, and the deferred list |
| [Audit 4 — v3 beta, by hand](docs/06-Audit/Audit-v3-Beta.md) | The phone on the emulator and the web as deployed, used screen by screen |

### Decisions

| ADR | Decision |
| :--- | :--- |
| [ADR-001](docs/04-Decisions/ADR-001-State-Management.md) | Riverpod over Bloc |
| [ADR-002](docs/04-Decisions/ADR-002-Local-Database.md) | Drift over Isar / Realm / Hive |
| [ADR-003](docs/04-Decisions/ADR-003-UI-Toolkit.md) | Material 3 + a custom design system |
| [ADR-004](docs/04-Decisions/ADR-004-Localization.md) | gen-l10n with ARB files |
| [ADR-005](docs/04-Decisions/ADR-005-Local-First-Sync.md) | Outbox pattern toward MongoDB |
| [ADR-006](docs/04-Decisions/ADR-006-Export-Format.md) | The workbook is the backup format |
| [ADR-007](docs/04-Decisions/ADR-007-Archive-Format.md) | The archive is a zip, and it comes back |
| [ADR-008](docs/04-Decisions/ADR-008-Exercise-Catalogue.md) | The exercise list is borrowed, the animations are fetched |
| [ADR-009](docs/04-Decisions/ADR-009-Monorepo.md) | One repository for the phone, the web and the server |
| [ADR-010](docs/04-Decisions/ADR-010-Maps.md) | MapLibre on OpenFreeMap, never Google |
| [ADR-011](docs/04-Decisions/ADR-011-Backend.md) | Express 5, TypeScript, zod, MongoDB |
| [ADR-012](docs/04-Decisions/ADR-012-Web-Client.md) | The web is local-first too: React 19, Vite, shadcn/ui |
| [ADR-013](docs/04-Decisions/ADR-013-Assist-Providers.md) | Writing assist behind one interface |

## Stack

- **Flutter** (Android first, iOS next) · Material 3 + a custom design system
- **Riverpod** (codegen) for state · **Drift**/SQLite for local-first storage
- **fl_chart** for charts · **table_calendar** for the calendar
- **flutter_local_notifications** + **workmanager** for reminders and the 3 AM reset
- **English + Arabic** with full RTL support via gen-l10n
- Local-first forever; sync through my own server (MongoDB) is optional, with the private tier sealed on the device
- **Web:** React 19, Vite, TypeScript, Tailwind + shadcn/ui, Dexie (IndexedDB), a PWA
- **Server:** Express 5, TypeScript, zod, MongoDB, argon2id, JWT with rotating refresh tokens
- **Maps:** MapLibre on OpenFreeMap tiles, no Google anywhere

## Development

The phone app lives in `apps/mobile`; run the Flutter commands there.

```sh
cd apps/mobile
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```

The web app, the server and the shared packages are a pnpm workspace
at the root:

```sh
pnpm install
pnpm dev          # web on :5173, server on :4000
pnpm test         # every package
pnpm typecheck
```

To run the whole thing on a server of my own — database, API and the
site behind Caddy with its certificate — see
[Deployment](docs/02-Architecture/Deployment.md):

```sh
cp deploy/.env.example deploy/.env
docker compose -f deploy/compose.yaml --env-file deploy/.env up -d --build
```

Schema changes follow the migration workflow in
[Local Database](docs/02-Architecture/Local-Database.md): bump the
version, write the step, dump and generate the schema, add the upgrade
test. Signature components have golden coverage in `test/goldens`
(regenerate with `flutter test --update-goldens test/goldens`).

### Release builds

Signing material lives outside the repo. Create the keystore once and
point `apps/mobile/android/key.properties` (git-ignored) at it:

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

Without the file, a release build stops rather than go out on the
debug key; `-PallowDebugSigning=true` lets a local release run through
anyway (never for distribution). Release builds
shrink and obfuscate; keep the symbol map with the tag you ship:

```sh
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

Toolchain pinned for reproducible builds: Flutter 3.47.2 (Dart 3.13),
JDK 21, Android minSdk 26.

## Project layout

```
apps/
  mobile/           the Flutter app
    lib/
      app/          router, shell, bootstrap
      core/         Drift database, HarvestDay, platform glue, theme and widgets
      features/     commitments, field, gamification, planner, pomodoro,
                    finances, calendar, stats, settings, security, export,
                    import, widget, onboarding, notes, gallery, records,
                    body, health, gym, farmer, goals, places, assist,
                    sync, account, wishlist
      l10n/         ARB files (en, ar)
    packages/harvest_steps/   the Health Connect / step-sensor plugin
    drift_schemas/  exported schema snapshots (v1 … v21)
    test/           unit, widget, migration and golden tests
  web/              the React web app and PWA
  server/           the Express sync and accounts API
packages/
  contracts/        zod schemas for every API body and synced table
  core/             the domain rules in TypeScript
deploy/             Compose + Caddy: the database, the server and the site
docs/               the Obsidian vault
```

## Roadmap

| Phase | Delivers | Status |
| :--- | :--- | :---: |
| 0 — Foundation | Scaffold, design system, l10n, DB, routing | ✅ |
| 1 — Productivity Core | Commitments, plan ritual, streaks, XP, pomodoro, notifications | ✅ |
| 2 — Finances | Expense quick-log, budgets, gauge, vault | ✅ |
| — | Four checkpoints: calendar, app lock, export, seed notes and history, the archive, the comeback ladder, the widget, the daily cycle | ✅ **v1.0** |
| 3 — Notes, Gallery & the Archive | Markdown notes with links; photo albums that are seeds; the zip archive **and an importer** | ✅ **v1.1** |
| 4 — Health & the Gym | Steps, body weight, and a training log — programs, sessions, personal records — plus the sleep alarm | ✅ **v2.0** |
| 5 — Goals, Places & Voice | A goals board, a trail and a geotag on every action on a free map, voice notes, read aloud, an assist in notes | ✅ |
| 6 — Sync, Accounts & the Web | Express + MongoDB server, optional accounts, sync, the whole app in the browser as a PWA | ✅ **v3.0.0-beta.1** |
| 7 — Screen Time | Usage caps, weed-pull interventions | v3.1 |
| 8 — Social & Reach | Rankings, the share card, iOS polish | |

### What's coming in Phase 5

[Goals](docs/01-Specification/Goals.md): a board on the field for the
things a streak cannot hold, with a living list of what each one takes
and the seeds I plant from it.
[Places](docs/01-Specification/Places.md): a trail recorded in the
background while I want it, a geotag on every action, and a map of
each day with its expenses, pictures, notes and check-ins pinned where
they happened. It is drawn with MapLibre on OpenFreeMap: open source,
free, and no Google.
[Voice](docs/01-Specification/Notes.md): recordings inside notes,
dictation, read aloud, and an assist that summarises, rewrites,
translates and transcribes, only when asked, with my own key.

Then Phase 6 takes it off the phone: an optional account, sync with the
private tier end-to-end encrypted, and the whole app in the browser,
installable, with a home page and the APK download.

The exercise catalogue is 1,324 exercises from an
[open dataset](https://github.com/hasaneyldrm/exercises-dataset). The
words ship in the app; the animations are fetched when you open an
exercise and cached forever, with a button to grab them all before a
trip and a switch to never fetch at all
([ADR-008](docs/04-Decisions/ADR-008-Exercise-Catalogue.md)).

Working rule: each phase ends with a tagged release I install and live
with before starting the next — dogfooding is the QA department.

## Privacy

Everything is stored on the device in a local SQLite database. Financial
data never leaves the phone in plaintext. When sync arrives it will be
opt-in, finances and location are end-to-end encrypted before they
leave, and you can keep everything local forever. Nothing is sold,
nothing is shared.
