# Checkpoint 12 — the keyboard, one server, and the owner's view

Opened 2026-09-29, after `v3.2.0`. Two bugs I hit on the phone, and
four things I need to run Harvest for other people: a place to see how
it is used, and ways to tell people things. Ships as `v3.3.0`; screen
time moves to `v3.4.0` ([[Roadmap]]).

## Bugs

### B12-01 — The keyboard covers the field, or what comes after it (phone)

**Seen:** choosing a new sync secret after *Change PIN*: the keyboard
comes up and covers the confirm button and the second field; nothing
moves until a key is typed, and even then only the line being typed
into comes into view, never the button. The same in every sheet with a
field low in it.

**Why:** two things together.
1. A sheet's confirm button was the last thing inside its scrolling
   body, so on a long sheet (the sync secret's has three paragraphs of
   warnings) it sat below the keyboard, reachable only by scrolling.
2. A field asks to be scrolled into view the moment it takes focus —
   before the keyboard has finished opening and the view has shrunk —
   so the ask comes too early and nothing moves; the next keystroke asks
   again, with the keyboard up, and only then does the caret's line
   come into view.

**Fix:**
- `HarvestSheet` keeps its confirm button **outside** the scrolling body,
  pinned at the foot of the sheet, so it always sits right above the
  keyboard.
- One watcher for the whole app: when the keyboard has finished
  opening (the bottom inset stops changing), the field that has focus
  is scrolled into view, with room below it for what follows.
- The sync secret sheet puts its warnings after the fields, not
  before them.

**Tests:** a widget test that opens a long sheet with a keyboard inset
and finds the confirm button on screen and the focused field visible; on
the emulator, *Change PIN* → the new secret: both fields and the button
above the keyboard without typing.

### B12-02 — The server's address has to be typed (phone)

**Seen:** signing in asks for the server's address first.

**Fix:** the address is built into the app —
`https://harvest.abakdi.com` — and the field is gone. A later move of
the server is a new release. A build for development or the emulator
takes another with `--dart-define=HARVEST_SERVER=…`; an address kept by
an earlier version is replaced by the built-in one.

### B12-03 — The passphrase screen calls it a PIN

**Seen:** in passphrase mode the sync secret sheet says "a key made
from this PIN". **Fix:** it says *secret* in both modes.

## Features ([[Admin]])

| # | What | Where |
| :-- | :-- | :-- |
| F12-1 | The admin panel: accounts, active accounts, streaks, platforms, versions, downloads, all over time; the users table | web `/admin`, server `/v1/admin` |
| F12-2 | Push notifications I write, to everyone or account holders | phone (background check, local notification), web (Web Push) |
| F12-3 | A pop-up I write, shown once when the app opens | phone and web |
| F12-4 | Users are accounts; people without one are downloads only | server, spec |
| F12-5 | *Report a problem*: text, pictures and a recording, anonymous, read in the admin panel | phone, web, server |

With them: the heartbeat, *Share my streak*, *News from Harvest*, the
privacy page and the data map saying what the server now learns.

## Where it stands (2026-09-30)

- [x] B12-01 — the confirm button pinned above the keyboard in every
  sheet, and one watcher (`KeyboardReveal`) that scrolls the focused
  field into view once the keyboard has finished opening. Seen on the
  emulator: *Change PIN* → the new secret, both fields and the button in
  view with nothing typed.
- [x] B12-02 — `https://harvest.abakdi.com` built in; the field is gone;
  `--dart-define=HARVEST_SERVER` for development builds.
- [x] B12-03 — *secret* in the sheet's words, and *Set the passphrase* on
  its button in passphrase mode (the button still said *Set the PIN*,
  found on the emulator).
- [x] Found on the emulator too: the keyboard's *Done* on the password
  now signs in, as the button does.
- [x] F12-1 — `/app/admin` (web): overview, history, users, news.
- [x] F12-2 — the phone checks every three hours and on opening, and
  notifies (Android's `news` channel); the web by Web Push (VAPID).
- [x] F12-3 — the pop-up, once per device, on the phone and the web.
- [x] F12-4 — accounts only; downloads from GitHub's own count.
- [x] Tested: the server's routes (181), the web (760), the phone
  (1541); in a browser and on the emulator against a local server — the
  admin panel with GitHub's real download count, news written there
  reaching the web as a pop-up once and the phone as a pop-up once and as
  a notification, the phone's heartbeat counted once a day with the
  web's.
- [x] F12-5 — reports: from Settings on the phone and the web, for
  anyone; anonymous (no session read, no address kept); pictures
  re-encoded without their metadata (checked: no Exif left in the stored
  picture); read, marked and deleted in the admin panel's *Reports* tab.
  Tested on the emulator (text and a camera picture), in the browser
  (text), and by the server's tests (185).
- [ ] Web Push from a real browser: the permission prompt is Chrome's
  own and was not driven by hand; the subscription and the service
  worker are covered by tests.

Related: [[Admin]] · [[Phase-7-Privacy-and-Currencies]] · [[Checkpoint-11]]
