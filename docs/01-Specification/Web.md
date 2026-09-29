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
because the alarms, the steps and the trail are there. The web is
where the typing happens, and anything the phone can do that does not
need the phone's own hardware, the web does too.

## The public site

| Route | What it is |
| :--- | :--- |
| `/` | **Home.** One screen of what Harvest is (the field, the streak, the four pillars), three sections with real screenshots, and two buttons: **Get the Android app** and **Open Harvest in the browser**. Where the browser can install it, the second one becomes **Install Harvest**. |
| `/download` | The latest APK: version, date, size, SHA-256, the release notes, and how to allow the install. It is fed by `GET /v1/releases/latest`, which reads the GitHub releases and caches them for an hour; a newer beta is named beside the release. |
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
    the two heavy parts few visits open, the map and the full exercise
    catalogue, are not installed up front but kept the first time they
    are fetched;
  - updates install in the background, and a small toast offers
    *Reload to update*;
  - it never caches API responses, because the data is in IndexedDB
    already.
- **The install button** listens for `beforeinstallprompt`. On iOS
  Safari, which has no prompt, it shows the two steps (Share → Add to
  Home Screen) instead. Once the install is accepted it says the app is
  on its way: on Android, Chrome builds the app through Google's
  servers, which fetch the manifest and icons from the site itself and
  can take a minute — so the site must already answer on its domain
  when it is installed. The manifest lists PNG icons only.

## The app

Everything under `/app` is the app, and it needs an account: the
browser keeps a copy of the field, but the local-first app is the
phone's. The public pages and the sign-in page say so, and that the
Android app works without one.

On a wide window it is laid out like the phone but for a wide screen:
- a rail on the left with the phone's tabs in the phone's order —
  Field, Granary, Records, Body, Farmer — and Settings at its foot;
- the screen in the middle. Notes open beside their list; a seed, a
  goal or a program opens as its own page, and an expense in a dialog.

Notes on a wide window is laid out the way Obsidian's desktop app is:
the vault as a tree of folders and notes down the side (folding
chevrons, a small row of new note, new folder, new voice note, sort and
fold-all, the open note marked, its edge dragged wider or narrower), and
the note beside it in a readable column about 700 px wide, its title a
large heading, under a thin bar with its path, the Read/Write switch and
its actions. Switching Read and Write keeps my place. The page fills the
window and never scrolls itself: the tree and the note each scroll on
their own.

Below 768 px Notes is the phone's Notes: one note in place, the vault in
a drawer from the ☰ beside the account circle, the note's title (and its
folder) in the app bar with the microphone, *+* and ⋮ (Assist, Record,
Read aloud, Move to folder, Print, Delete — which asks first). It opens
on the note I was last in; Back closes a note and shows the notes, and
a note closed that way stays closed the next time. The note reads as
rendered markdown and a tap writes where it lands, with the markdown
toolbar on the keyboard while I write; links on the caret's line and
the notes that link here are chips. A note made and left empty is
dropped when I leave it.

Scrollbars are thin, in the theme's colours, with no arrows, and show
only while the pointer is over what scrolls; strips of tabs and chips
that scroll by swipe show none.

Below 768 px it *is* the phone's layout: the bottom bar with the same
tabs, the account circle and the tab's title in the app bar (a back
arrow on a screen pushed over a tab), the tab row under it, the
screen's main action floating above the bar, and forms as bottom
sheets. The bar and the floating action step aside while the on-screen
keyboard is up.

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
| M6.5 | Public site, install, accounts, the app shell, settings, sync status |
| M6.6 | Field (today, check-ins, undo), seeds (plant, edit, archive), Goals board, Notes (editor, folders, links, search), expenses (log, edit, the month) |
| M6.7 | Vault, budgets, calendar, stats, farmer and streak details, Gallery, Body, Gym, Places (the map, day and range views) — first as views |
| M6.8 | Pictures and recordings, fetched by the name of their own bytes and opened with the sync PIN ([[Sync-API]], files) |
| M6.10 | The Wishlist, the Granary's fourth tab ([[Wishlist]]) |
| M6.11 | Everything the phone writes, written here too: a seed's own page and its notes, the focus timer, tomorrow's plan, a freeze bought with coins, the weekly report; the vault's moves, debts, the budget, categories, sums in an amount and the Insights tab; nights and weights; the program editor and a whole session run in the browser; albums, pictures uploaded and the timelapse; folders, tables, recordings, read aloud and print in notes; week and month on the map, a stay named, location history deleted; every setting the phone syncs, the first run, and the archive, exported and imported |
| M6.12 | Records → Lists: every list in one place, a pasted link filling itself in, and the Granary's Wishlist tab folded into it ([[Lists]]); items reorder with Alt+↑/↓ |
| M6.13 | Goals with requirements, tasks and subtasks ([[Goals]]): Alt+↑/↓ moves an item within its section or its task, *Move under…* nests one; Records reads *Notes · Lists · Gallery · Places* |

Some things stay **phone-only by nature**: the alarms and reminders,
the steps source, the trail recorder, the home-screen widget and the
app lock. The web shows their data, and Settings lists them under
*On the phone* rather than leaving them out without a word.

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

## Decisions made while building it

- **Closed days are judged on the phone only.** The web updates
  streaks live on check-in and undo, and the Farmer screen says that
  the 3 AM judging (freezes, breaks) happens on the phone.
- **Links are computed from note bodies**, as on the phone; `note_links`
  rows are merged when pulled but never relied on or written.
- **No hard delete of a seed on the web**: archive is how a seed retires
  there, because a hard delete's children would not follow it in sync.
- **Theme, preset and language live in the browser** (`localStorage`),
  because the public pages read them and must not open IndexedDB (W3).
  Preferences with meaning beyond the look — the daily goal, the default
  currency, note folders — are synced settings.
- **Buying a freeze is allowed on the web; spending one is not.** A
  freeze is spent by the 3 AM judging, which stays on the phone.
- **The focus timer runs per device.** A running timer is kept in
  `pomodoro.active`, a key that never syncs; the finished blocks are
  `pomodoro_sessions` rows like the phone's. A block ends with a
  notice on the page, not a system notification.
- **One gym session at a time, across devices.** Starting one refuses
  while another is running, even one the phone began. Two devices that
  both start offline can still end up with two; the gym then shows the
  newest. The exercise catalogue is bundled, as on the phone; its
  animations are not fetched.
- **Money is written here too**, behind the same PIN gate, and
  the guards live in the repositories rather than the dialogs: a pot
  cannot be overdrawn, a debt cannot be overpaid, currencies never
  mix.
- **Feature switches hide the web's tabs.** Body shows while Health or
  the Gym is on, Records while Notes, the Gallery or Places is.
- **The first run is asked once, and only of an empty account**: after
  the first sync, with no `onboarding.done` and no seeds at all, so a
  new browser on an old account is never asked.
- **Geotags from the browser are opt-in and device-local.**
  `web.geotagging` is off by default, needs Places on, and uses the
  browser's own location, and writes a geotag only once it has a place
  or knows it has none, so nothing pending ever reaches the phone
  ([[Places]] PL3). Switching Places on from the browser asks for no
  permission: the phone asks when it next needs a location, and until
  then its trail stays off.
- **A gym program's picture is offered here too**, before or after the
  session as the program says, with *Not now*.
- **Settings are written the way the phone writes them**, down to the
  encoding: the time rates were fetched is local time with no offset,
  as the phone stores it.
- **Reading aloud and dictation stay on the computer.** Read aloud uses
  local voices only; dictation shows only where the browser recognises
  speech on the device, never through a vendor's server
  ([[Business-Rules]] #13).
- **Transcribe goes through the server's assist.** A recording in a
  note has *Transcribe* on its player when the server offers an assist.
  The dialog first says the recording goes to the server's model, and
  nothing is sent until I press *Send*; the words come back as they are
  written and go under the recording as a quote when I choose *Insert*.
  A recording over 8 MB, or a day's assist already spent, is refused
  before anything leaves ([[Notes]] N10).
- **Pictures are uploaded like the phone's**: resized to a 1600 px long
  edge, hashed, sealed and sent; the row learns the file's name only
  once the server has it. On the web, *Share* is a download.
- **The archive is the phone's archive.** The same zip and the same
  sheets, in both directions; the web writes its timestamps in UTC.
  Whether an export carries the location sheets is chosen per browser.
- **The access token stays in memory.** A reload refreshes; a refresh the
  server turns away (429, 5xx) opens the app from what the browser
  holds, as offline does, and asks again later with a growing pause.
  Only a 401 signs out.
- **A note being typed is never lost to a reload**: each keystroke is
  copied to the browser's own storage before the autosave, and put back
  on the next load if it is newer than the note.
- **Token refreshes are serialised across tabs** with the Web Locks API:
  a refresh token used twice revokes the session everywhere
  ([[Accounts]] AC4).

## Rules

| # | Rule |
| :-- | :--- |
| W1 | The web app is local-first: every screen works from IndexedDB, and the network is only for sync and sign-in. |
| W2 | The web computes derived state (streaks, balances, progress) with `packages/core`, from history, exactly as the phone does. It never asks the server for a number. |
| W3 | The public pages never load the local store or the private tier. |
| W4 | The service worker caches the shell, never data, and an update is never forced mid-edit. |
| W5 | A signed-out browser holds nothing. Signing out clears IndexedDB, after a warning if anything is still waiting to sync. |

Related: [[ADR-012-Web-Client]] · [[Accounts]] · [[Sync-API]] · [[Dashboard-and-Widgets]]
