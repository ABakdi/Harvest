# Audit 4 — v3.0.0-beta.2, by hand

*2026-09-25, on the beta.2 tree. The first three audits read the code.
This one used the apps: the phone on the emulator, screen by screen,
and the web as it is deployed — the production images behind Caddy,
the real server and a real database — in a browser. Nothing was
changed while testing.*

## How it was run

- **The phone**: v3.0.0-beta.2, release build, on the `harvest` AVD
  (API 36), first on data upgraded from v2.0.0 through beta.1, then
  from a clean install through the first run. Every tab, sheet and
  setting was driven by touch, with logcat and the database read after
  each step.
- **The web**: `deploy/` run in production mode on this machine, with a
  mail catcher for the verification link; two browsers on one account,
  English and Arabic, light and dark, a laptop window and a phone-width
  one. Console errors, failed requests and policy violations were
  collected on every page.
- Every finding has an ID, a severity, the steps, what I saw and what
  I expected. `P4-` is the phone, `W4-` the web, `X4-` both.

## Counts

| | Blocker | Major | Minor | Polish |
| :--- | :---: | :---: | :---: | :---: |
| Phone | 1 | 5 | 10 | 16 |
| Web | – | 6 | 8 | 15 |
| Both (found on one, true of the other) | – | 3 | 3 | – |

## Phone

| ID | Severity | Finding |
| :--- | :--- | :--- |
| P4-01 | Blocker | Opening Places made the app's memory climb past 1.4 GB until Android killed it; Records remembered Places as its tab, so Records then died on every open. |
| P4-02 | Major | Times filled in by the database's own default were UTC written without a zone and read as local: every expense and every movement an hour early here. |
| P4-03 | Major | A session left open for eleven days: the clock read 15977 minutes, and finishing it said *checked in for today* while it checked in the day it started. |
| P4-04 | Major | Undo snackbars never went away; they followed me to other tabs and covered the Trash entry and the Plant button. |
| P4-05 | Major | After a permission prompt the Wishlist stopped showing what was saved to it until the tab was switched. |
| P4-06 | Major | Back left the app from any tab but the Field, and with the notes drawer open. |
| P4-07 | Minor | Sign in with empty fields said *Something went wrong (ArgumentError)*, and the error followed to Create account. |
| P4-08 | Minor | Health Connect's Connect answered *Not allowed yet* at once, with no system dialog, round and round. |
| P4-09 | Minor | A goal item's menu said *Removed* for *Remove*. |
| P4-10 | Minor | Tapping the label of *From the wallet* (and *Allow reminders*) did nothing; only the switch did. |
| P4-11 | Minor | A project log cut at the daily cap only said *Daily cap reached*, not what was dropped. |
| P4-12 | Minor | The first run's last page said *Two more* and listed five; its seed chips barely showed being chosen, and a quick tap chose the neighbour. |
| P4-13 | Minor | A voice note's embed drew a stray *!* and a dashed link, with the player floating mid-page. |
| P4-14 | Minor | Arabic: the Wishlist tab label cut off, a minus after the amount, two kinds of digits on one screen. |
| P4-15 | Minor | Notification permission asked for a debt with no reminder, and after a first run with reminders off. |
| P4-16 | Minor | `[bootstrap] resume failed: StateError` on every return to the app. |
| P4-17 … 32 | Polish | Calendar badges clipped and today unreadable when another day is picked; the heatmap's month cut and today coloured as a streak with none running; the Plant button over *Plan*; money written four ways; the edit sheet's button saying *Log*; *Move to folder* asking for a typed path; Assist offered with no provider; a check mark for To-Do and for *selected*; the seed's page only behind ⋮; no *20 of 100* on a project; exercise names in lower case; a new target set not copying the last; the plate sheet only behind the label; the empty weight card pointing at a button that says something else; Fetch leaving the DZD rates looking broken; a trend note in a warning colour. |

## Web

| ID | Severity | Finding |
| :--- | :--- | :--- |
| W4-01 | Major | Plant on a goal's step could open with the previous item's title and link the wrong item. |
| W4-02 | Major | Typing in a note and closing the tab within two seconds lost it. |
| W4-03 | Major | Arabic: everything inside the Granary and Body tabs was laid out left to right. |
| W4-04 | Major | Before the passphrase, the Field showed a budget computed without the expenses it could not read. |
| W4-05 | Major | Sync pulled only on focus or every fifteen minutes: two open windows stayed stale. |
| W4-06 | Major | A search result for a seed opened the Field, not the seed. |
| W4-07 | Minor | Records with all three halves off still showed Notes. |
| W4-08 | Minor | *6 check-ins over 1 days*. |
| W4-09 | Minor | A reset page kept an old server error beside a new one. |
| W4-10 | Minor | An invalid rate stayed in its field after it was refused; the amount error stayed after a valid sum. |
| W4-11 | Minor | The program editor turned 61.3 kg into 61.25 without a word. |
| W4-12 | Minor | `/download` offered only v2.0.0, with the betas out. |
| W4-13 | Minor | Focus fell to the page after a dialog opened from the keyboard closed. |
| W4-14 | Minor | The calendar spec promised projects on the grid; neither app has them, on purpose. |
| W4-15 … 29 | Polish | Dialogs repeating their title as their description; no word after pausing a seed, restoring a note or moving money; raw markdown in a seed's note on its card; a paused seed counted as due; the quietest day counted from before the account; the exercise chips clipped; *1324* ungrouped; kg/lb only reachable from the weight dialog; wishlist prices in the colour of debt; two names for one night; a place card covering the place. |

## Both

| ID | Severity | Finding |
| :--- | :--- | :--- |
| X4-01 | Major | An expense logged on a future day was saved and then nowhere to be seen, edited or deleted. |
| X4-02 | Major | A project accepted a daily amount larger than its total, and a log could pass the total. |
| X4-03 | Major | A settled debt hid its payments, so a mistaken last payment could not be taken back; and it settled without the celebration Finances promises. |
| X4-04 | Minor | Pounds shown unrounded in the program editor, the session's fields, *Last time* and records — 132.28 lb for a bar that can only hold 132.25. |
| X4-05 | Minor | The quietest day counted days before the first seed. |
| X4-06 | Minor | Wishlist prices drawn in the colour the app uses for debt. |

## What held up

Planting, check-ins and undo; the over-log cap; the focus timer; the
planner, calendar and goals; sums in an amount and the budget's daily
limit, correct to the centime; the vault's guards; the Wishlist's
totals per currency; notes with links, backlinks and the trash; sleep,
weight and a whole gym session with its records; the archive out and
back; Arabic and dark mode on the whole; and on the web, no page error
and no policy violation on any screen, the shell opening offline, and
a second browser catching up in seconds.

## Status

Every finding was fixed, then **retested by hand the same way it was
found** — the phone on the emulator, the web as deployed — and the few
that failed the retest were fixed again. What the retest turned up is
in the second table.

| Area | Fixed, and how it was checked |
| :--- | :--- |
| Places (P4-01) | The cause was a day whose points all sat in one spot: fitting the map to a box of no size sent it to zoom 25, where the tiles are stretched past any sense and memory runs away. One spot now centres at 15, the zoom stops at 19, and Records reopens on Places only once the map has drawn. On the emulator: 150–190 MB instead of 2.5 GB, tiles on both bases, six round trips without a kill. |
| Times (P4-02) | Schema v22 stamps every default on the phone's own clock and rewrites the old UTC stamps; sync stops sending them an hour off. The retest's expenses and moves showed the device's time to the minute. |
| Gym (P4-03, X4-04) | A session past its day asks to finish as of that day or drop it, names the day, ends at its last set, and counts hours or days (Y14). Pounds read to the quarter pound everywhere, fields and volume included (Y8). |
| The shell (P4-04, P4-06, P4-16) | Undo messages go after six seconds and with the tab; Back closes the drawer, then goes to the Field, then leaves; nothing fails on resume. |
| Money (P4-05, P4-15, X4-01, X4-03, X4-06) | The Wishlist stays live through a permission prompt, which is asked only for a reminder; money logged ahead is listed under Upcoming and counts on its day, in the totals and in the wallet; a settled debt keeps its payments, and settling is celebrated; estimates are not drawn in the colour of debt. |
| Projects (X4-02, P4-11) | One rule on both sides: no daily amount above the total, no log past what is left, and what a cap leaves out is said, even when the log completes the project. |
| First run, account, Health Connect (P4-07, P4-08, P4-12) | The account form checks itself before asking the server; Health Connect shows its own dialog (the plugin started the request in a way Android 14 ignores); the first run's picks are unmistakable. |
| Arabic (P4-14, W4-03) | Every number in Western digits; amounts held left to right with their sign in front; tab strips that scroll instead of clipping; the Radix parts of the web following the page's direction. |
| The web (W4-01 … W4-13) | All passed the retest; W4-02 needed a second fix — each keystroke is copied to the browser's storage before the autosave, so not even a reload in the same breath loses it. A refresh the server turns away no longer stops the app from opening. |

### What the retest found

| ID | Severity | Finding | Status |
| :--- | :--- | :--- | :--- |
| R4-01 | Major | In pounds, the web's set dialog could open a 60 kg set as *60 lb* and save it that way. | Fixed: nothing opens before the unit is known, and an untouched load keeps its grams. |
| R4-02 | Minor | Saved places' names were not drawn on the phone's map: the plugin sent the font in a way the map refuses. | Fixed: the names are their own layer, with the font as a literal. The emulator draws no text at all, so this one waits for a real phone. |
| R4-03 | Minor | A wallet expense dated ahead took the money today. | Fixed on both sides (above). |
| R4-04 | Minor | The web's *Save* needed two clicks after the *Kept as* hint; the place card covered the map; set labels broke apart in Arabic. | Fixed. |

## Still open

- **Geotags after a restart on the emulator** were all *unavailable*.
  The emulator's GPS had no last position and served a stale mock one;
  I expect a real phone to behave, and will check it there.
- **The map's text** — street names and place names — cannot be seen on
  the emulator's software renderer; a real phone is the test.
- **Real days**: the 3 AM judging and streaks over several days were
  not lived through here.

Related: [[Audit-v2]] · [[Checkpoint-9]] · [[Web]]
