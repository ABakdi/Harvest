# Web

Phase 6 ([[Phase-6-Sync-Accounts-and-Web]]). Harvest in a browser.
It has two faces:
- a **public site**: what Harvest is, the APK, and the button that
  installs the web app;
- the **app itself**: the whole of Harvest, local-first like the phone
  ([[ADR-012-Web-Client]]), and installable as a PWA.

## Why it belongs here

I spend half the day at a laptop. Logging an expense or checking a
seed in should not mean reaching for the phone, and a note is simply
better written on a keyboard. The phone stays the primary device,
because the alarms, the steps, the trail and the camera are all
there. The web is where the typing happens.

## The public site

| Route | What it is |
| :--- | :--- |
| `/` | **Home.** One screen of what Harvest is (the field, the streak, the four pillars), three sections with real screenshots, and two buttons: **Get the Android app** and **Open Harvest in the browser**. Where the browser can install it, the second one becomes **Install Harvest**. |
| `/download` | The latest APK: version, date, size, SHA-256, the release notes, and how to allow the install. It is fed by `GET /v1/releases/latest`, which reads the GitHub release and caches it for an hour. |
| `/privacy` | What leaves the device, in plain words, generated from the same list as [[Business-Rules]] #13. |
| `/login` · `/register` · `/forgot` · `/reset/:token` · `/verify/:token` | [[Accounts]] |

The public pages are light: they use neither the local store nor the
sync, and render in well under a second on a phone.

## Installing it

- A **web app manifest**: name *Harvest*, short name *Harvest*, the
  olive-branch icon at every size including maskable, the brand-green
  theme and the cream background, `display: standalone`, and
  `start_url: /app`.
- A **service worker** (Workbox, via `vite-plugin-pwa`):
  - the app shell is precached, so `/app` opens with no connection;
  - updates install in the background, and a small toast offers
    *Reload to update*;
  - it never caches API responses, because the data is in IndexedDB
    already.
- **The install button** listens for `beforeinstallprompt`. On iOS
  Safari, which has no prompt, it shows the two steps (Share → Add to
  Home Screen) instead.

## The app

Everything under `/app` is the app, laid out like the phone but for a
wide screen:
- a rail on the left: Field, Body, Records, Granary, Farmer;
- the screen in the middle;
- on wide windows, a detail panel on the right. A seed, a note or an
  expense opens beside the list rather than over it.

**Keyboard first.**
- `N` new seed, `E` expense, `/` search, `G` then `F`/`B`/`R`/`M`/`P`
  to go to a tab.
- `J`/`K` move through the field, and `Space` checks the focused seed
  in.
- Every action on screen is reachable without a mouse.

**What arrives when** (the milestones in
[[Phase-6-Sync-Accounts-and-Web]]):

| Milestone | Screens |
| :--- | :--- |
| M6.4 | Public site, install, accounts, the app shell, settings, sync status |
| M6.5 | Field (today, check-ins, undo), seeds (plant, edit, archive), Goals board, Notes (editor, folders, links, search), expenses (log, edit, the month) |
| M6.6 | Vault, budgets, calendar, stats, farmer and streak details, Gallery (view; upload once files sync), Body (sleep, weight, steps view), Gym (programs, history; sessions stay phone-first), Places (the map, day and range views) |

Some things stay **phone-only by nature**: the alarms, the steps
source, the trail recorder, the camera flow, the home-screen widget
and the app lock. The web shows their data, and says where it came
from.

## Look and language

- **shadcn/ui** components, themed with the Harvest tokens:
  terracotta, sage, soil and cream, Nunito, the same radii and the
  same five theme presets, light and dark
  ([[Theming-and-Design-System]]).
- **English and Arabic**, with RTL, from the same strings as the phone
  where the words are the same. Money uses Western digits, as on the
  phone ([[Finances]]).
- **Accessible by default**: Radix primitives underneath, visible focus,
  labelled icon buttons, and AA contrast in both themes.

## Rules

| # | Rule |
| :-- | :--- |
| W1 | The web app is local-first: every screen works from IndexedDB, and the network is only for sync and sign-in. |
| W2 | The web computes derived state (streaks, balances, progress) with `packages/core`, from history, exactly as the phone does. It never asks the server for a number. |
| W3 | The public pages never load the local store or the private tier. |
| W4 | The service worker caches the shell, never data, and an update is never forced mid-edit. |
| W5 | A signed-out browser holds nothing. Signing out clears IndexedDB, after a warning if anything is still waiting to sync. |

Related: [[ADR-012-Web-Client]] · [[Accounts]] · [[Sync-API]] · [[Dashboard-and-Widgets]]
