# Audit 6 — v3.1: security, quality, and the phone and the web by hand

*2026-09-27/28, on `dev` after v3.1.0-beta.1, which was never
published. Four reads side by side: one for security, one for code
quality and performance, and two by hand, the phone on the emulator and
the web in a browser. Then I fixed what they found, and used both apps
again before v3.1.0-beta.2 ([[Checkpoint-11]]).*

## How it was run

- **Security**: accounts and data on the server, the web, the phone,
  the contracts and `deploy/`, with the new pieces first: the key share
  behind the sync PIN, start over, and the database encryption on the
  phone. Every route probed with two accounts, only against local
  servers and the emulator.
- **Code quality and performance**: the phone, the web and the server,
  read slice by slice and measured on a seeded account of 31,438 rows
  (two years of check-ins, 2,000 expenses, 300 notes, 5,000 trail points,
  100 gym sessions). The web pushed it all and fresh browsers pulled it
  back; the phone was probed on the host against the real schema.
- **The phone by hand**: the release build on the emulator, every tab,
  sheet, menu and settings page, in English and Arabic, light and dark,
  at font scale 1.3, at 320 and 274 dp wide, and offline.
- **The web by hand**: the production build in headless Chromium, at
  widths from 1440 down to 360, in English and Arabic, light and dark,
  with text at 150–200%, by keyboard only, with axe-core on every
  screen, and offline.
- IDs: `S6-` security, `Q6-` bugs and quality, `P6-` performance, `U6-`
  the phone by hand, `W6-` the web by hand.

**Where it ended:** 140 findings — 139 fixed, 1 documented — and three
more found by hand before the beta, all fixed. One
fixed finding keeps a small remainder (W6-12), and one part of Q6-23 was
declined (SV-14).

## Security

| ID | Severity | Where | Finding | Status |
| :-- | :-- | :-- | :-- | :-- |
| S6-01 | Medium | Server, web | Signed-in API answers had no `Cache-Control`, so the browser kept pulled notes, lists and the email in its disk cache after sign-out. | **Fixed** — Every `/v1` answer, errors included, is `no-store`, and sign-out sends `Clear-Site-Data: "cache"`. |
| S6-02 | Medium | Web | Signing out offline wiped the browser but left the refresh cookie and the server session: the next person to open `/app` was signed in. | **Fixed** — A sign-out that never reached the server is owed, and is settled before any refresh at the next start and before a new sign-in. |
| S6-03 | Medium | Server | The per-email limit refused the right password too: 20 wrong ones an hour from one machine kept the owner out for good, and a reset didn't lift it. | **Fixed** — Failures are counted per email and network at 20 an hour, with a ceiling of 200 an hour per email; a right password or a reset clears them. |
| S6-04 | Medium | Server, both clients | Any signed-in session could read the key share and the key check, and so find a 4–6 digit PIN offline in minutes. | **Fixed** — The share leaves the server only after an online proof of the PIN, 5 wrong tries per 15 minutes and 20 a day; the verifier is sealed under the environment key too; Accounts.md says what a stolen session can and cannot do. |
| S6-05 | Medium | Phone | The secure store reset itself on any Keystore error; the phone then set the encrypted database aside, opened empty without a word, and deleted the older copy the next time. | **Fixed** — The store no longer resets on error; a missing key shows "Can't open your data" with Try again; every set-aside file is kept, stamped, and never deleted. |
| S6-06 | Medium | Phone | The password for Delete account and Start over was typed in plain view, with suggestions, keyboard learning and a capital first letter. | **Fixed** — A real password prompt: hidden, no autocorrect, no suggestions or learning, no capitals. |
| S6-07 | Medium | Server, both clients | After a start over, a device still on the old key could upload a picture under it; the server then held that hash for good, and no device could open or replace it. Private rows had the same window. | **Fixed** — Start over moves a key epoch; every sealed push and file upload names its epoch, a stale one is refused with nothing stored, and the device asks for the PIN again. |
| S6-08 | Medium | Phone | A synced memory's path could be absolute, and Empty trash would then delete whatever file it named, the database included. | **Fixed** — The gallery deletes only safe relative paths; the contracts refuse unsafe ones and the phone drops such rows on pull. |
| S6-09 | Low | Web, phone | The archive checks covered only the outer zip: a 400 KB archive could hold a workbook part of 400 MB and crash the app. | **Fixed** — The workbook is inflated with caps per part, in total and on the entry count, on both apps; the phone does it off the UI isolate. |
| S6-10 | Low | Server | Forgot and resend answered faster for an address with no account, which told who has one. | **Fixed** — Both answer first and do the work after; the timing no longer tells. |
| S6-11 | Low | Web | Unsaved note drafts in localStorage survived sign-out. | **Fixed** — Signing out clears the drafts with the rest. |
| S6-12 | Low | Phone | `http://` was accepted for the account server and the assist, sending the password, tokens and key share in the clear. | **Fixed** — `https://` only; plain `http://` only to this device or the emulator's host. |
| S6-13 | Low | Phone | The home-screen widget wrote money and task titles outside the encrypted database, even with money hidden. | **Fixed** — What the widget doesn't show isn't written: no money when it is hidden, no task titles while the app lock is on. |
| S6-14 | Low | Server | Mail was limited per sender only, so a few addresses could send hundreds of reset mails to one person. | **Fixed** — At most 3 mails an hour and 10 a day per recipient; past that nothing is sent and the answer doesn't change. |
| S6-15 | Polish | Server | Any old refresh token of a session, up to 30 days old, could sign that device out. | **Fixed** — Only the current token, or one within its 30-second grace, signs a device out. |
| S6-16 | Polish | Server | The server still stored the endpoint settings no client syncs since S5-01. | **Fixed** — They are accepted and not stored. |
| S6-17 | Polish | Web | Decrypted files became untyped Blobs; an HTML or SVG file opened in a tab would have run as the app. | **Fixed** — A file's type comes from its first bytes, from an allow-list, never HTML or SVG. |
| S6-18 | Polish | Deploy | Database passwords went into the Mongo script unescaped, and Deployment.md said to back up `.env` together with the database. | **Fixed** — Passwords escaped and names checked; `.env` is backed up in another place, under another key. |
| S6-19 | Polish | Phone | A stale comment about outbound requests; the end-of-life sqlite and sqlcipher flutter libs in the lock; `archive` 3 held back. | **Documented** — The comment is fixed. The end-of-life libs come with drift_flutter 0.3.1, and archive 3 is held by excel; both move when those packages do. |

## Quality: High

| ID | Severity | Where | Finding | Status |
| :-- | :-- | :-- | :-- | :-- |
| Q6-01 | High | Server, all | A file between 16 and 25 MB never synced: MongoDB refuses a document over 16 MiB, and every upload failed with a 500. | **Fixed** — File bytes live in GridFS; the 25 MB limit is real, and a 24.9 MB file round-trips byte for byte. |
| Q6-02 | High | Server | Since S5-07 the body is read before the account lock, so a push or upload could land after the account was deleted (Q5-56 undone). | **Fixed** — Push and upload check the account again under its lock once the body has arrived; start over is covered by S6-07. |
| Q6-03 | High | Server, phone, web | Batches were counted in rows, not bytes: one batch over 5 MB got 413 and stopped sync for good. | **Fixed** — A 4 MB push limit in the contracts; both clients fill batches by bytes and halve one on 413. |
| Q6-04 | High | Web | A render error, or a chunk missing after a deploy, blanked the app with React Router's developer page. | **Fixed** — Translated error screens on the site and in `/app`, a boundary inside the shell, and a missing chunk saves the edits and reloads once. |
| Q6-05 | High | Web | The sync key was cached per tab: after a start over in one tab, another wiped the new key or went on sealing under the old one. | **Fixed** — Tabs tell each other when the key changes, and a tab clears only its own key. |

## Quality: the rest

| ID | Severity | Where | Finding | Status |
| :-- | :-- | :-- | :-- | :-- |
| Q6-06 | Medium | Web | Two tabs synced at once, pushed every row twice, and the `stale` answers rewound the pull cursor to 0. | **Fixed** — One sync at a time across tabs, through Web Locks. |
| Q6-07 | Medium | Phone, web | A seed could get two notes for one day, after which the phone could never save that day's note again. | **Fixed** — One note per seed and day, the newest wins: a core rule with fixtures on both apps; the write is one transaction behind a busy guard. |
| Q6-08 | Medium | Phone | Four isolates opened the database with no busy timeout: a write meeting a lock failed at once, and trail points were dropped. | **Fixed** — A 5-second busy timeout on every connection. |
| Q6-09 | Medium | Web | Reload for an update reloaded every other tab without saving its edits. | **Fixed** — Only the asking tab reloads; the others save first, and a failed save asks before reloading. |
| Q6-10 | Medium | Web | 255 `void`ed promises: refused money rules, contract refusals and a full store failed in silence. | **Fixed** — One action helper that names the failure in a toast, at 192 user actions and 50 background calls; a last-resort toast for anything unhandled; the lint now counts `void`. |
| Q6-11 | Low | Phone | "Syncing" could stay on for good if the key check threw. | **Fixed** — The check is inside the `try`. |
| Q6-12 | Low | Phone | Three undos and Remove exercise ignored their failures; the target-set save had no catch. | **Fixed** — All guarded, with a message when they fail. |
| Q6-13 | Low | Phone | Gym history stopped at the newest 50 sessions and re-read them on every ticked set. | **Fixed** — History pages as it scrolls; a burst of ticks is one read. |
| Q6-14 | Low | Web | The file upload pass swallowed its errors and retried forever. | **Fixed** — Failures are logged and wait longer each time, 1 minute up to 1 hour; after 3 the gallery says some files could not be sent. |
| Q6-15 | Low | Server | The quota's running total was charged before the write and never released on a failure. | **Fixed** — Charge, sequence and write sit in one `try`, and the total is recounted on a failure. |
| Q6-16 | Low | Server | A refresh was three separate writes; a failure between them left a used token with no successor, which revoked the session. | **Fixed** — The successor is written first, then the old token is marked used with its successor in one update. |
| Q6-17 | Low | Server | Nothing timed out: the assist stream, the database and the account lock could each hang an account's sync. | **Fixed** — 60 seconds for the model, cancelled when the caller leaves; 30 seconds per database operation; a lock wait over 30 seconds answers 429 with `Retry-After`. |
| Q6-18 | Low | Web | A verified account still showed as unverified; the memory list fetched again on every change; an interval leaked. | **Fixed** — The fresher account re-renders, the memory list keeps its files, and the interval is cleared. |
| Q6-19 | Low | Web | The production bundle shipped react-router's development build (95 KB and the "Hey developer" box). | **Fixed** — The production build, and a fallback on the lazy `/app` route. |
| Q6-20 | Low | Web, core | Rules written twice: amount parsing, the currency list, and "savings low". | **Fixed** — The web's own parser is gone; the currencies and the savings rule come from core, with fixtures, on both apps. |
| Q6-21 | Low | Web | Create and add buttons with no busy guard: a double click made two programs, days or sets. | **Fixed** — Busy guards on every one. |
| Q6-22 | Low | Web | Smaller defects: one failed save hid the others, file bookkeeping read every row, an imported picture got a UTC day, two switches not exhaustive. | **Fixed** — `allSettled`, indexed counts, the Harvest Day, and record keys from the contracts. |
| Q6-23 | Polish | Server | Three database round trips before every sync call, a hand-written list of file tables, used refresh tokens kept 30 days, a sweep with `$nin`, dead exports. | **Fixed** — Session and user in one read, one touch a minute; file tables derived from the contracts; the sweep uses a cursor; dead exports gone. **Declined** for the refresh tokens (SV-14): reuse detection needs them, so they stay 30 days. |
| Q6-24 | Polish | All | No formatter on the web; the pubspec said "A new Flutter project."; stale and misplaced comments on the phone. | **Fixed** — The pubspec and the phone's comments are corrected. I chose not to add a formatter to the web: it has a house style, and reformatting the whole tree would bury the history. On the web I wrapped the long lines in the files I split and fixed the stale comments on lazy loading and the router. |
| Q6-25 | Polish | Phone, web | Dead code on both apps, and three duration formatters on the phone that disagreed. | **Fixed** — Removed, test seams marked `@visibleForTesting`, and one `formatDuration`. |
| Q6-26 | Polish | All | Tests that slept on the wall clock, and no server tests for Q6-01 to Q6-03. | **Fixed** — The tests wait on conditions; the server tests are there, and the race test pulls while it pushes. |
| Q6-27 | Polish | All | The largest files, worth splitting along seams already in the code. | **Fixed** — No change in behaviour. The phone: migrations out of `database.dart`, one function per sheet, `places_screen.dart` in four files, the import tables apart. The web: `notes.tsx` 1,247 → 106 lines (vault, sidebar, folders, editor, trash), `places.tsx` 1,089 → 406 (map, timeline, save card), `import.ts` 1,100 → 270 (one planner per sheet group, the 33-sheet order checked identical). |

## Performance

| ID | Severity | Where | Finding | Status |
| :-- | :-- | :-- | :-- | :-- |
| P6-01 | Medium | Web | A first sync of the seeded account took 95 s, with 78 long tasks (16.8 s, the longest 527 ms), and the app lagged through it. | **Fixed** — Each page is read and written in bulk, over only the tables it touches: 13.8 s with 1 long task of 52 ms. |
| P6-02 | Medium | Server, web | A push cost five round trips per row under the account lock, and the web re-read the whole outbox before every batch. | **Fixed** — One read, one sequence range and one bulk write per batch, from about 480 to about 9,700 rows/s; the web reads the outbox once per run. |
| P6-03 | Medium | Phone | The Field re-read every check-in ever made after each check-in, undo and pulled page. | **Fixed** — Totals by `GROUP BY` in SQL; the calendar reads only its visible weeks. |
| P6-04 | Medium | Phone | Each note autosave loaded every note, bodies included, once per link. | **Fixed** — Link titles from one titles-only read, and no reindex when the links haven't changed. |
| P6-05 | Medium | Server | Each file was held whole in memory and copied again on download. | **Fixed** — Downloads stream a few chunks at a time: 30 parallel downloads of 16.7 MB use 63 MB instead of 513. |
| P6-06 | Medium | Phone | A pull scanned the whole outbox once per pulled row: 1.4 s a page against a 20k outbox. | **Fixed** — An outbox index, and one outbox read per page. |
| P6-07 | Medium | Phone | File sync and the archive held whole files in memory on the UI isolate. | **Fixed** — Hashing is streamed off the UI isolate; export and import open their files from paths inside an isolate. |
| P6-08 | Low | Server, all | Every push came back on the next pull. | **Fixed** — A pull leaves out the caller's own writes. |
| P6-09 | Low | Web | The service worker precached 4.7 MB on install, the map and the exercise catalogue included. | **Fixed** — The shell only, 2.1 MB; the map, its worker and the catalogue are cached when first opened. |
| P6-10 | Low | Web | Opening `/app` in a new browser downloaded 450 KB of gzipped script before the Field drew. | **Fixed** — Archive, Calendar, Farmer, Goal, Lists, Onboarding, Focus, Seed and Settings load when first opened; three shared pieces moved out of those screens, and the gym's name list comes with the gym. The first load went from 436 to 396 KB gzipped, the app chunk from 194 to 154 KB, and a test fails if a screen creeps back into it. |
| P6-11 | Low | Phone | Hot filters scanned whole tables: check-ins, the ledger, sets, memories, expenses, links. | **Fixed** — The indexes in one v25 migration, written down in Local-Database.md. |
| P6-12 | Low | Phone | Most syncs of two or more rows started a second sync 2 s later. | **Fixed** — The debounce is cancelled when nothing waits, and answered rows go in one statement. |
| P6-13 | Polish | Phone | Nothing was drawn until the database was fully prepared. | **Fixed** — A plain frame in the launch colour at once; the Keystore is read while the file is checked, and the key check stays. |
| P6-14 | Polish | Phone | Lists that grow without bound built every tile at once. | **Fixed** — Built as they scroll. |
| P6-15 | Polish | Web | Opening Places cost about 1 s of main thread, and the map style logged warnings. | **Fixed** — The day list draws first; the map loads in its own chunk behind a placeholder and starts when the page is idle. The longest task went from about 500 ms to 245 ms at 4× CPU slowdown, and the road-shield warnings are gone. |

## Phone by hand

| ID | Severity | Where | Finding | Status |
| :-- | :-- | :-- | :-- | :-- |
| U6-01 | High | Notes | Assist in a note's menu did nothing, and said nothing. | **Fixed** — The provider is held while it is asked, with a timeout; an unreachable server counts as none and opens the setup sheet. |
| U6-02 | High | Sync PIN, Devices | Closing the PIN sheet while it checked also closed the page under it; "Sign out there" could pop two pages. | **Fixed** — The sheet can't be closed while it works and pops only itself; Devices runs once. |
| U6-03 | Medium | Field | The phone never showed progress toward the daily harvest goal, so the streak looked broken. | **Fixed** — The goal line under the XP bar and in the streak sheet. |
| U6-04 | Medium | Goals | Achieve then delete a goal, again and again, farmed +50 XP. | **Fixed** — Deleting an achieved goal takes the 50 back, and restoring gives it again, on both apps. |
| U6-05 | Medium | Sign-in, onboarding | Signing in merged the phone's own seeds into the account without asking, and onboarding planted templates first. | **Fixed** — "I have an account" in onboarding, and signing in to an existing account asks what to do with this phone's seeds. |
| U6-06 | Medium | Granary | Planned purchases jumped to the Records tab, and Back landed on the Gallery. | **Fixed** — The list opens inside the Granary, and Back returns there. |
| U6-07 | Medium | Notes | Back from an open note left the Records tab. | **Fixed** — Back closes the note first. |
| U6-08 | Medium | Notes | A new note left untouched stayed behind as "Untitled". | **Fixed** — An untouched note is discarded on leaving. |
| U6-09 | Medium | Theme | The brand colours used as text failed contrast: amber XP and coins at 1.65–1.8, orange at 3.2, white on the gradients down to 1.8. | **Fixed** — Text colours checked against their background in every look, light and dark; dark ink on the gradients; the Dusk gradient deepened to match on both apps (#7c3aed → #db2777). |
| U6-10 | Medium | Money sheets | The money sheets took sums, but the system keypad had no "+". | **Fixed** — One amount field with the app's keypad in every money sheet. |
| U6-11 | Medium | Expense sheet | On a normal phone the Log button was below the fold. | **Fixed** — Log is in view at 1080×2400. |
| U6-12 | Medium | Narrow and large text | At 320 and 274 dp and at 1.3× text, segments broke mid-word, chart labels collided, tabs clipped, and the FAB covered the last card. | **Fixed** — Text-only segments and fitted bar labels on narrow screens, scrolling Records tabs, an icon-only bottom bar when it's tight, the day date on its own line, room for the FAB. |
| U6-13 | Medium | Arabic | The streak chip read "0 يوم", with no zero form. | **Fixed** — Every Arabic plural has a zero form, and a test requires one. |
| U6-14 | Low | Goals | An achieved goal looked exactly like an active one. | **Fixed** — "Achieved on…" or "Dropped" under the title, and an empty state on the board. |
| U6-15 | Low | Pause | Pausing a seed gave no feedback and barely changed the card. | **Fixed** — A paused card is dimmed with no check circle, and pausing offers Undo. |
| U6-16 | Low | Snackbars | Snackbars covered the floating button. | **Fixed** — Each tab has its own messenger, so the button moves up. |
| U6-17 | Low | Gym | Start with no program only toasted; Create with an empty name closed silently. | **Fixed** — With no program, Start becomes New program; Create waits for a name. |
| U6-18 | Low | Devices | Sign out there acted at once with no feedback; offline had no retry; no way to sign the others out. | **Fixed** — A confirmation and a snackbar, Retry, the sign-in date, and "Sign out all other devices". |
| U6-19 | Low | Sync PIN | "Forget it on this device" acted at once, and entering the PIN once took 17 s with no word. | **Fixed** — It asks first, and the sheet says making the key can take up to about 20 seconds on an older phone. |
| U6-20 | Low | Account | The account sheet and the Account page used different names and status. | **Fixed** — One name, the same status lines, and Verified as a plain label. |
| U6-21 | Low | Farmer | The heatmap's first month label was clipped, and there were no weekday labels. | **Fixed** — Mon/Wed/Fri labels, and a month that doesn't fit isn't drawn. |
| U6-22 | Low | Planner, Calendar | List cards touched each other. | **Fixed** — The Field's gap between cards. |
| U6-23 | Low | Text fields | Titles opened the keyboard in lowercase. | **Fixed** — Sentence case on every title field. |
| U6-24 | Low | Accessibility | Menus read "Show menu", a category's remove read "Cancel", a done circle still said "Check in", a hidden FAB stayed in the tree. | **Fixed** — Tooltips on every menu, the sync PIN menu included; "Remove {name}" with Undo; "Undo today's check-in"; the hidden FAB left out. The "Advanced" expander read twice is Flutter's own node, which TalkBack can't focus. |
| U6-25 | Low | Touch targets | Filter and equipment chips and the notes drawer rows were under 48 dp. | **Fixed** — Padded to 48 dp. |
| U6-26 | Low | Places | Day entries said their kind twice and never named the seed. | **Fixed** — Named by the seed, with "no longer here" once it's deleted. |
| U6-27 | Low | Sync | One offline check-in showed "5 changes waiting". | **Fixed** — "Changes waiting", with no number. |
| U6-28 | Low | Onboarding | No language choice, and Back on a later page likely left the app. | **Fixed** — A language picker on the welcome page, and Back goes to the previous page. |
| U6-29 | Polish | Dark theme | Warm brown cards on a navy page. | **Fixed** — Card colours drawn from the page. |
| U6-30 | Polish | Segmented buttons | Selected segments had a green fill, an orange label and a green tick. | **Fixed** — One selected style, centred labels, full width. |
| U6-31 | Polish | Sheets | One sheet title was centred, the rest left. | **Fixed** — All at the start. |
| U6-32 | Polish | Notes | The empty state was off-centre and had its own button instead of a FAB. | **Fixed** — Centred, with the same FAB as the other tabs. |
| U6-33 | Polish | Tab bars | Tab bars looked different from tab to tab. | **Fixed** — One tab bar. |
| U6-34 | Polish | Insights | The range shown twice, "DA71.42 / day", and a caption starting with a slash. | **Fixed** — The range once, "Per day", and the average rounded to the currency by a core rule both apps use. |
| U6-35 | Polish | Granary | "Nothing logged" said twice, and two gradient buttons competing. | **Fixed** — Said once; the budget button is tonal. |
| U6-36 | Polish | Copy | "Vault", an odd gym line, the wrong Arabic word for check-ins, straight quotes, "1324 exercises", "I" and "you" mixed. | **Fixed** — Every string listed rewritten; counts formatted; curly quotes. |
| U6-37 | Polish | Exercises | The same dumbbell on every row, and raw lowercase chips. | **Fixed** — The cached thumbnail when there is one, and sentence-cased chips. |
| U6-38 | Polish | Reminders | A disabled switch looked half on. | **Fixed** — It shows off while reminders are off. |
| U6-39 | Polish | Sync mark | Sync state was shown by colour alone. | **Fixed** — A tick, an arrow, a slash or "!" for each state. |

## Web by hand

| ID | Severity | Where | Finding | Status |
| :-- | :-- | :-- | :-- | :-- |
| W6-01 | Medium | Public site | The site promised Harvest without an account, and `/app` met the visitor with a bare sign-in form. | **Fixed** — The site says the browser needs a free account and the Android app none; sign-in leads with "Create a free account". |
| W6-02 | Medium | Sync | Going offline was noticed only when a sync failed; Devices spun forever offline. | **Fixed** — The browser's online and offline events drive the mark and the sheet at once; offline, Sync now is disabled with a reason, and Devices says why it's empty. |
| W6-03 | Medium | Sync PIN | "What is already here stays", and then all the money vanished behind the PIN form. | **Fixed** — The confirmation says what stays, locked, and what is hidden until the PIN is entered again. |
| W6-04 | Medium | App-wide | User text took the interface's direction, so English titles broke in the Arabic app and the other way round. | **Fixed** — `dir="auto"` on about 55 places that show user text. |
| W6-05 | Medium | Notes | One direction for a whole rendered note: an Arabic heading turned every English paragraph right to left. | **Fixed** — Each block gets its own direction. |
| W6-06 | Medium | App bar, Settings | At 150% and 200% text on a phone, the app bar spilled and the page scrolled sideways. | **Fixed** — A More menu when the bar gets tight, and buttons that wrap. |
| W6-07 | Medium | Sync PIN | Entering an existing PIN showed the choosing copy and invited a switch to a passphrase. | **Fixed** — Entering shows only "I set a passphrase instead", and the card has a sane width. |
| W6-08 | Medium | Account sheet | With no PIN yet, the sheet said "Enter your sync PIN" and the dialog said "Choose". | **Fixed** — The sheet asks the server and says choose or enter. |
| W6-09 | Medium | Phone layout | The FAB covered the last card, which couldn't be scrolled clear. | **Fixed** — Nothing is left under the bar or the button. |
| W6-10 | Medium | Field at phone width | The web's Field didn't look like the phone's. | **Fixed** — The phone's header and rows at phone width, with a streak of 0 hidden. |
| W6-11 | Low | Titles | Every page was titled "Harvest". | **Fixed** — A title per page, and a note, seed, goal, program or album by its own name. |
| W6-12 | Low | Contrast | Muted labels at 4.44:1, and dark-mode primary text on cards at 3.5–4.1:1. | **Fixed** — Darker muted text, lighter primary and destructive text in dark mode, non-modal menus; 416 of 424 checked states are clean. One moderate axe "region" note remains while a menu is open, because the menu renders outside the page's landmarks. |
| W6-13 | Low | Sync PIN | The dialog was read twice, had two headings, and lost focus after a wrong PIN. | **Fixed** — One heading, the fields tied to the error, and focus kept in the field with the text selected. |
| W6-14 | Low | Change PIN | "Change PIN" asked only for the password and said Start over. | **Fixed** — "Next you choose the new PIN", and "Continue to a new PIN". |
| W6-15 | Low | Money, weight | DA 99,999,999,999 and 900 kg were saved without a word. | **Fixed** — A large amount asks first and a weight outside 20–400 kg is refused, by core rules the phone uses too. |
| W6-16 | Low | Accessibility | The locked Granary pointed at tab panels that weren't there; Notes had no `h1`; a scroller couldn't be reached by keyboard. | **Fixed** — The PIN form inside each panel, a hidden `h1`, and a focusable strip. |
| W6-17 | Low | Note title | No direction and no visible focus on the note title. | **Fixed** — `dir="auto"` and a focus underline. |
| W6-18 | Low | Search | Search missed list items, and its close button sat over the field on a phone. | **Fixed** — List items are searched and the placeholder says so; the button has room. |
| W6-19 | Low | Gym | Start a session with no program only toasted. | **Fixed** — With no program, New program is the floating action. |
| W6-20 | Low | Focus | Abandon ended a block with one tap. | **Fixed** — After a minute, it asks first. |
| W6-21 | Low | Page headers | Long titles were cut to one line with no way to read them. | **Fixed** — Up to three lines. |
| W6-22 | Low | 200% zoom | The bars and the FAB left about 200 px for content. | **Fixed** — On short windows the bottom bar drops its labels and the FAB shrinks. |
| W6-23 | Low | Web.md | The spec described a detail panel the app doesn't have. | **Fixed** — Web.md describes what the app does. |
| W6-24 | Low | Reset, register | A bad reset link and a taken email offered no way on. | **Fixed** — "Send a new link", and Sign in or Reset the password. |
| W6-25 | Low | Theme colour | The browser bar was always green. | **Fixed** — It follows light or dark and the chosen look. |
| W6-26 | Low | Field | The streak pill was read as a bare number. | **Fixed** — "Streak: N days". |
| W6-27 | Low | Devices | Sessions piled up and couldn't be told apart. | **Fixed** — When each signed in and was last seen, this device first, the newest three, and "Sign out everywhere else". |
| W6-28 | Polish | Granary | Three cards said nothing was logged. | **Fixed** — The budget card and one empty state. |
| W6-29 | Polish | Toasts | Toasts quoted long titles whole, and "Removed" said little. | **Fixed** — Names cut to about 40 characters, "Expense removed". |
| W6-30 | Polish | Rail | The rail's order differed from the phone's bar. | **Fixed** — The phone's order everywhere. |
| W6-31 | Polish | Seed heatmap | No fixed week, no month labels, today not at the end. | **Fixed** — A week grid with month labels and today in the last column. |
| W6-32 | Polish | Granary | Ledger rows had no category icon and no time. | **Fixed** — Both, like the phone. |
| W6-33 | Polish | Download | "Compare its SHA-256 with the one above", with nothing above. | **Fixed** — Shown only when there is a release. |
| W6-34 | Polish | Sync sheet | A button out of line, and an orphan "now". | **Fixed** — Aligned links, and "Last synced · now". |
| W6-35 | Polish | Settings | "Space" untranslated in Arabic. | **Fixed** — Translated. |
| W6-36 | Polish | Balances | The wallet shown twice; the moves search said "Search notes". | **Fixed** — Once, and "Search moves". |
| W6-37 | Polish | Goals | A target day years in the past passed without a word. | **Fixed** — A warning, not a block. |
| W6-38 | Polish | Focus | The countdown twice and "Focus" three times. | **Fixed** — The chip hidden on the timer, one label less. |
| W6-39 | Polish | Design.md | The style reference forbids the gradients and shadows both apps use. | **Fixed** — Design.md says Harvest uses soft gradients and shadows on purpose. |
| W6-40 | Polish | Contracts | "password12" passed although the hint said "not a common one". | **Fixed** — A common password with digits, symbols or basic leetspeak added is refused, by one rule the server and the web hint share. |

Also accepted: the calendar at 200% text keeps 42 px day cells, since seven columns can't be wider on a 390 px phone.

## Found by hand before the beta

Using the release build on the emulator against a server of this code,
with the web beside it, turned up three more that no test had caught,
because the tests run the pure-Dart crypto and never start the app
cold. IDs `H6-`.

| ID | Severity | Where | Finding | Status |
| :-- | :-- | :-- | :-- | :-- |
| H6-01 | High | Phone | Choosing or entering a sync PIN hung on "Making the key…" for good. The PIN proof is HKDF with an empty salt, and on Android the HMAC runs in the platform, which refuses an empty key. | **Fixed** — The empty salt is spelled as RFC 5869 defines it, 32 zero bytes: the same bytes, as the shared fixture and a web browser unlocking with the phone's PIN both show. Any unexpected failure now brings the sheet back to typing with a message. |
| H6-02 | High | Phone | Signing in again to the server already saved failed with "Something went wrong (ArgumentError)": the first request after a start left before the saved address was read, for the built-in default, which is empty. | **Fixed** — Every request waits until the saved address is read. Tests for the client and the provider. |
| H6-03 | Low | Phone | With the session ended underneath it, the PIN sheet stayed open and, after half a minute, said "That email and password do not match". | **Fixed** — The sheet says the phone is signed out, and closes once it is, if it is still on top. |

## Checked and fine

- No account reaches another's rows, files or sessions; a forged or
  unsigned token is refused; the refresh grace holds, and a real reuse
  ends the family.
- A malicious server can't get data re-sealed under a key it knows:
  every key includes the PIN or passphrase, and a device never adopts a
  key from the server.
- Start over needs the password, runs under the account lock and drops
  everything sealed; sign-in timing is equal for known and unknown
  addresses.
- The phone's database file is encrypted with no plaintext leftovers;
  backups are off; only the main activity is exported.
- Every server query is on an index; idle web pages do nothing; typing
  in a 4 KB note stays under a frame.
- Public pages at 1440 and 360, light and dark, English and Arabic: no
  overflow and no axe violations. Offline, the web opens from its store
  and syncs when the connection is back.

Related: [[Audit-Home]] · [[Audit-v3]] · [[Security-Audit]] · [[Checkpoint-11]]
