# Audit 5 — v3: security, quality and gaps

*2026-09-27, on `dev` after v3.0.0. Two reads of the whole tree, side by
side: one for security (the server, the web, the phone, the crypto and
the deployment), one for bugs, code quality and the gaps between the
phone, the web and the specs. Then I fixed what they found, and used both
apps by hand before the beta ([[Checkpoint-10]]).*

## How it was run

- **Security**: every route, token, limit and header of the server read
  against [[Sync-API]] and [[Accounts]]; the crypto of both clients
  against the shared fixtures; the Android manifest; `deploy/`. Live
  probes only against a throwaway local server. The first
  [[Security-Audit]] was re-checked: its fixes held, and S-04 was still
  open.
- **Quality and gaps**: the previous audits first, then the code slice by
  slice — the Field and goals, the Granary, the body, the records, sync
  and the server, and i18n, accessibility and performance across both —
  the phone against the web and both against the specs.
- IDs: `S5-` security, `Q5-` bugs, quality and performance, `G5-` gaps
  between the phone, the web and the specs.

**Where it ended:** 105 findings — 103 fixed, 1 mitigated, 1 documented.

## Security

| ID | Severity | Where | Finding | Status |
| :-- | :-- | :-- | :-- | :-- |
| S5-01 | Medium | Phone, contracts | Where the phone sends its assist key and prompts (`assist.provider`, `assist.baseUrl`) and loads its map (`places.styleUrl`) synced in the plain tier: anyone who can write the account could redirect them. | **Fixed** — Endpoint settings and the assist model no longer sync, export or import; an incoming one is ignored; the stored assist key is bound to the address it was saved for. |
| S5-02 | Medium | Server | No quota on records, and a pull of 1,000 large sealed rows could hold gigabytes in memory and take the server down. | **Fixed** — Pull pages by bytes through a cursor (8 MB); row and text size caps; 256 MB of rows per account; per-account request limits on sync and files. |
| S5-03 | Medium | Server | `DELETE /v1/me` checked the password with no rate limit: unlimited guessing with a stolen token, and an argon2 cost per guess. | **Fixed** — Five wrong passwords per account per 15 minutes; at most four password hashes at once across the server. |
| S5-04 | Medium | Crypto | A 4–6 digit PIN falls to one GPU in about a minute from a copy of the database or a backup alone. | **Fixed** — A per-account key share sealed under a key that lives only in the server's environment enters the key on both clients, so a copy of the database or a backup alone opens no PIN; too-simple PINs are refused; start over with the password when a PIN is lost, which is also how it is changed. |
| S5-05 | Low | Server | Sign-up answered 409 for an address that already has an account. | **Mitigated** — Sign-up keeps its immediate session and gets its own limit (5 an hour per address); Accounts.md names it as the one exception to AC3. |
| S5-06 | Low | Server | The sign-in limit was per address only, with no limit per account. | **Fixed** — A per-email limit of 20 failures an hour, kept in the database, checked before any hash. |
| S5-07 | Low | Server | Large JSON bodies were parsed before authentication. | **Fixed** — Bodies parsed per route after authentication with small limits; strict auth bodies; nginx body sizes per location. |
| S5-08 | Low | Server | The file quota could be overrun by parallel uploads, and no file could ever be deleted. | **Fixed** — Space reserved atomically; `DELETE /v1/files/<sha256>`. |
| S5-09 | Low | Crypto | A wrong PIN was detected only against rows the device already had; one row sealed under a wrong key stopped the private tier on every phone for good. | **Fixed** — A PIN is checked against a key check stored on the account; choose or enter is the server's answer; a row that won't open is counted as locked and never costs the key. |
| S5-10 | Low | Crypto | A sealed row's clock was not bound to its ciphertext, so the server could roll a private row back. | **Fixed** — Envelope v2 binds the row's clocks in the additional data, and the opened row's own clocks must match. |
| S5-11 | Low | Server | A pushed clock had no upper bound; a year-9999 stamp froze the row. | **Fixed** — Clocks more than 24 hours ahead or past 2200 are refused. |
| S5-12 | Low | Deploy | MongoDB 4.4 is out of support (needed on CPUs without AVX), and the database had no authentication. | **Fixed** — The database runs with authentication and a least-privilege user on an internal network; deploy.sh moves an existing database over. 4.4 stays only where the CPU needs it, as a stopgap. |
| S5-13 | Low | Server | Mail went out over opportunistic STARTTLS: a network attacker could strip it and read reset links. | **Fixed** — STARTTLS required, TLS 1.2 at least, with an explicit setting for a local relay. |
| S5-14 | Low | Dependencies | nodemailer and maplibre-gl had published advisories. | **Fixed** — nodemailer 10 on the server, maplibre-gl 6 on the web; `pnpm audit --prod` finds nothing. |
| S5-15 | Low | Web | A session ended from another device left the browser's data and key in place. | **Fixed** — A session the server says is gone wipes the browser's store before sign-in; network trouble still opens offline. |
| S5-16 | Low | Phone | List links opened with any URI scheme on the phone. | **Fixed** — The phone opens only http and https links, like the web. |
| S5-17 | Low | Deploy | `deploy.sh` wrote a fixed path in `/tmp` as root. | **Fixed** — `mktemp`. |
| S5-18 | Info | Crypto | What the server can see of the private tier: table names, clocks, sizes, and files named by the hash of their content. | **Documented** — What the server sees is written down in Sync-API.md; file names by content hash stay, as the way devices find a file they share. |
| S5-19 | Info | Server | The server's assist key had only a per-account daily cap. | **Fixed** — A global daily ceiling for the server assist. |
| S5-20 | Info | Several | Smaller points: duplicate headers on `/v1`, nginx version shown, cookie prefix, addresses in mail error logs, link tokens in access logs. | **Fixed** — Headers once, no version, `__Secure-` cookie, no addresses in mail error logs, no access log on link paths. |
| S-04 | Open since audit 1 | Phone | The phone's database is not encrypted at rest (SQLCipher). | **Fixed** — The database file is encrypted with SQLCipher under a random key kept in the Android Keystore; an existing file is converted in place on first start, verified table by table, and kept as it was if anything fails. |

## High

| ID | Severity | Where | Finding | Status |
| :-- | :-- | :-- | :-- | :-- |
| Q5-01 | High | Phone, web | A second sync key could be chosen on a fresh browser, after which the private tier stopped syncing on every device. | **Fixed** — See S5-09. |
| Q5-02 | High | Core, phone | A check-in on the web hid missed days from the phone's 3 AM judging, so the streak never broke. | **Fixed** — A missed day spends a stored freeze or restarts the run, in the live update both apps share; a missed due day restarts a habit. |
| Q5-03 | High | Phone | The Granary and the budget stopped moving at 3 AM; on the 1st of the month the budget read last month and said "over". | **Fixed** — The Granary's day, month, week, budget and repeat card follow the live Harvest Day. |
| Q5-04 | High | Phone | Two notes with one title made every note linking to that title unsaveable, and the typing was lost without a word. | **Fixed** — A title resolves exact-case first, then case-insensitively, and never throws on duplicates; a failed save says so. |
| Q5-05 | High | Phone | Pictures restored from an archive never reached sync. | **Fixed** — Restored pictures go into the outbox, and the next file pass asks the server about already-named files too. |
| Q5-06 | High | Phone, web | One file over 64 MB made the whole archive refuse to import, and on the phone a big clip blocked file sync. | **Fixed** — Both clients skip an oversized file instead of refusing the archive, and count it; the phone's file sync skips files over the limit and catches errors per file. |

## Medium

| ID | Severity | Where | Finding | Status |
| :-- | :-- | :-- | :-- | :-- |
| Q5-07 | Medium | Phone, web | Rows with no clock of their own could lose an offline edit to an older copy. | **Fixed** — A pull never overwrites a row with a newer edit waiting in the outbox. |
| Q5-08 | Medium | Phone | The phone applied a pulled purge without comparing clocks. | **Fixed** — A pulled purge compares clocks first. |
| Q5-09 | Medium | Phone, web | A purged row could come back from an older copy. | **Fixed** — A pending delete counts as a tombstone during a merge; deletes are stamped when they were made. |
| Q5-10 | Medium | Phone, web, server | A device with a skewed clock could stay different from the others for good. | **Fixed** — Stamps never go behind a clock already seen; on `stale` the server's copy is taken; the server refuses clocks far ahead. |
| Q5-11 | Medium | Web | Rows an older installed web app could not read were skipped for good. | **Fixed** — Rows this version can't read are parked and tried again when the app updates. |
| Q5-12 | Medium | Web | The web's count of locked rows never reached zero. | **Fixed** — The locked entry goes whenever the row was opened. |
| Q5-13 | Medium | Server | A lost refresh answer signed out every device of that session. | **Fixed** — The same refresh token within 30 seconds gets the same successor. |
| Q5-14 | Medium | Server | Same as S5-03. | **Fixed** — See S5-03. |
| Q5-15 | Medium | Server | Any refresh failure, a 5xx included, cleared the refresh cookie. | **Fixed** — The cookie is cleared only on 401. |
| Q5-16 | Medium | Phone | Undoing an expense removal could charge the wallet a second time. | **Fixed** — An expense and its wallet movement are removed under one timestamp; Undo brings the movement back only if it matches. |
| Q5-17 | Medium | Phone, web | Undoing a payment removal skipped the overpay and overdraw checks. | **Fixed** — Undo re-checks the debt, the overpay and the wallet on both apps, and says why it was refused. |
| Q5-18 | Medium | Phone | The wallet could only be kept above zero by the sheet, not by the repository. | **Fixed** — The repository refuses a withdrawal, transfer or debt payment the wallet can't cover. |
| Q5-19 | Medium | Core, phone | The gym's Finish dialog miscounted the sets left when an exercise was skipped. | **Fixed** — Only ticks on exercises still in the plan count; shared rule and fixture cases. |
| Q5-20 | Medium | Phone | Two nights logged for one morning (one per device) broke the sleep sheet. | **Fixed** — The newest night wins; duplicates are collapsed with their XP reversed; a failed save no longer sticks the sheet. |
| Q5-21 | Medium | Phone | On a clock-change morning the sleep sheet was an hour off. | **Fixed** — The sleep sheet works in wall-clock minutes. |
| Q5-22 | Medium | Phone | Emptying the notes trash did not sync. | **Fixed** — Emptying the trash queues a delete per note. |
| Q5-23 | Medium | All | Purged pictures and attachments never freed their storage. | **Fixed** — A purge releases the local file; the server frees a file only when no row names it and it is past a 30-day grace, by a daily sweep or a guarded DELETE. |
| Q5-24 | Medium | Phone | A control character in any text made a phone archive unreadable on the web. | **Fixed** — Characters XML can't hold are stripped from every cell; shared rule and fixture. |
| Q5-25 | Medium | Phone | An Arabic note exported as PDF had no glyphs. | **Fixed** — The note PDF embeds the app's own fonts (Nunito, IBM Plex Sans Arabic), sets each paragraph's direction and localises the title. |
| Q5-26 | Medium | Phone | A picture not downloaded yet said "Couldn't load" and never updated. | **Fixed** — Downloading…, fetched on its own, redrawn when it lands; timelapse and Share say the same. |
| Q5-27 | Medium | Phone | Signed-in devices showed a raw UTC timestamp. | **Fixed** — Local time and "Web" / "Phone" labels. |
| Q5-28 | Medium | Phone | A project finished from the focus timer was never archived. | **Fixed** — The focus timer finishes a project the way the Field does, archive included. |
| Q5-29 | Medium | Core, phone | Streak milestone coins could be earned again by undo and redo. | **Fixed** — A milestone pays once per run, checked against the ledger; the phone's streak update is inside the check-in transaction. |
| Q5-30 | Medium | Web | The public site loaded 578 kB of script before anything else, and every app screen sat in one chunk. | **Fixed** — The public site's first script went from 588 kB to 204 kB; languages load on demand; heavy screens load when opened. |
| Q5-31 | Medium | Web | The Field re-read whole tables on every change. | **Fixed** — The Field reads the week through the day index; lifetime totals are cached. |
| Q5-32 | Medium | Web | Places, the gym and the gallery read without bounds. | **Fixed** — Days from the index, bounds by a reduce, gym reads by index, gallery tiles fetched near the screen through a pool of five. |
| G5-01 | Medium | Phone, web, spec | Planned purchases counted the Wishlist on the phone and not on the web. | **Fixed** — One rule in core, without the Wishlist; the Lists.md example corrected. |
| G5-02 | Medium | Phone, web | A debt could never be edited or deleted. | **Fixed** — A debt can be edited (never below what was paid) and deleted with Undo, on both apps; Finances.md updated. |
| G5-03 | Medium | Phone, web | Insights counted expenses logged ahead. | **Fixed** — Insights count up to today on both apps. |
| G5-04 | Medium | Phone, web | Changing the default currency changed what the budget meant. | **Fixed** — Changing the default currency converts the budget, by one shared rule. |
| G5-05 | Medium | Phone, web | The target weight could not be set anywhere. | **Fixed** — A target row on the weight card of both apps. |
| G5-06 | Medium | Phone | The phone could not clear the budget, and refused typed sums in money sheets. | **Fixed** — The phone's budget sheet clears; money sheets take sums; the save is guarded. |
| G5-07 | Medium | Web | A list item whose seed was archived never offered to finish. | **Fixed** — An archived seed counts as done. |
| G5-08 | Medium | Web | Undoing a subtask could nest it two levels deep. | **Fixed** — Undo lifts a subtask whose parent became one; an item two levels down reads as top-level. |
| G5-09 | Medium | Web | Following an unwritten link created the note without asking, twice on a double click. | **Fixed** — Asks first, one note per click, at the top of the vault like the phone. |
| G5-10 | Medium | Phone, web | Gym history dropped what the day was meant to be. | **Fixed** — Instead of, the skip reason and the note, on both apps. |
| G5-11 | Medium | Phone, web | The phone's and the web's heatmaps counted different things. | **Fixed** — One day-activity rule, window and shade in core, used by both heatmaps. |
| G5-12 | Medium | Web | The web calendar disagreed with the phone's. | **Fixed** — One calendar rule in core, used by both calendars. |
| G5-13 | Medium | Spec, core | Rounding to a quarter unit produced loads the plates cannot make. | **Fixed** — A resolved percentage rounds to what the plates can load (0.5 kg, 5 lb); Gym.md updated. |

## Low

| ID | Severity | Where | Finding | Status |
| :-- | :-- | :-- | :-- | :-- |
| Q5-33 | Low | Phone | Arabic counts from 11 to 99 took the wrong form. | **Fixed** — Every Arabic plural on the phone has its forms for 3–10, 11–99 and 100 up; a test fails on any that doesn't. |
| Q5-34 | Low | Web | Every N days had no Arabic plural forms. | **Fixed** — All six Arabic forms. |
| Q5-35 | Low | Web | Three Arabic strings showed Eastern Arabic digits. | **Fixed** — Western digits in the three strings; a test fails on any Eastern Arabic digit in either app's strings. |
| Q5-36 | Low | Shared | Typed-digit normalisation was written three times and disagreed. | **Fixed** — One digit normaliser in core with a fixture, used by amounts and the PIN on both apps. |
| Q5-37 | Low | Web | Keyboard shortcuts did nothing with an Arabic keyboard layout. | **Fixed** — Shortcuts read the key's position, so an Arabic layout works. |
| Q5-38 | Low | Phone | The repeat card had no guard against a double tap. | **Fixed** — Busy guard and a visible failure on the repeat card. |
| Q5-39 | Low | Phone, web | Finishing or starting a gym session had no guard against a double tap. | **Fixed** — Finish and start run once on both apps; a second Finish pays nothing; the PR toast shows once. |
| Q5-40 | Low | Phone | A focus block could be paid twice if the app died between two writes. | **Fixed** — A block's XP and the saved timer are one transaction; a running timer is returned instead of a second one. |
| Q5-41 | Low | Phone | A failed add left the list item sheet stuck; plant-then-link was two writes. | **Fixed** — The list item sheet recovers from a failure; planting and linking are one transaction. |
| Q5-42 | Low | Phone | Switching the weight unit without changing the number saved the old unit. | **Fixed** — The stored weight is kept only when both number and unit are unchanged. |
| Q5-43 | Low | Phone, web | Undoing a planted parent's check-in unticked subtasks ticked by hand. | **Fixed** — A check-in ticks with its own moment, and undo clears only those ticks, on both apps. |
| Q5-44 | Low | Phone, web | A parent's done state was not settled again after sync or import. | **Fixed** — Parents are settled again after a sync and after an import, on both apps; the export writes the tick the subtasks draw. |
| Q5-45 | Low | Phone, web | A bought item moved into the Wishlist stayed bought. | **Fixed** — Moving into the Wishlist clears the bought mark, on both apps. |
| Q5-46 | Low | Phone, web | Set badges skipped numbers after a set was dropped. | **Fixed** — Sets are numbered by their place in the list on both apps. |
| Q5-47 | Low | Phone, web | Last 14 days of steps skipped empty days. | **Fixed** — Always the 14 days up to today, zero for an empty one, on both apps. |
| Q5-48 | Low | Web | An exercise's history returned fewer outings than asked. | **Fixed** — Filter, then slice. |
| Q5-49 | Low | Web | An expense form opened before 3 AM and saved after filed under the wrong day; removing a payment had no confirmation. | **Fixed** — The day is read when Log is pressed and held to ±365 days; removing asks first; failures are caught and shown. |
| Q5-50 | Low | Web | A custom insights range had no bound. | **Fixed** — The range is held to the phone's bounds. |
| Q5-51 | Low | Web | Two quick Enters added a list item twice. | **Fixed** — One add at a time. |
| Q5-52 | Low | Web | Search could push notes off the list, and its input had no label. | **Fixed** — Each kind gets its share of the results; the index can't go below zero; the input is labelled. |
| Q5-53 | Low | Web | Export PDF missed the last moment of typing. | **Fixed** — The export waits for the pending save, and says so if it fails. |
| Q5-54 | Low | Phone | Refused rows were retried forever and kept the circle amber. | **Fixed** — Refused rows leave the outbox, are counted and flagged, and go again when they change. |
| Q5-55 | Low | Phone | A phone joining an account was asked to choose a PIN. | **Fixed** — See S5-09. |
| Q5-56 | Low | Server | Deleting an account did not wait for a push in flight. | **Fixed** — Deleting an account takes the account's lock. |
| Q5-57 | Low | Server | CORS left out the file upload's method and headers. | **Fixed** — CORS allows the upload's method and headers. |
| Q5-58 | Low | Phone, core | The geotag filler could leave a tag pending, and a stay across 3 AM was found on neither day. | **Fixed** — No event dropped while filling; a stay across 3 AM shows on both days, by a shared rule. |
| Q5-59 | Low | Phone, web | Exported file names could collide or be invalid on some systems. | **Fixed** — Safe names, case-insensitive collisions, cells cut without splitting a character; one rule in core. |
| Q5-60 | Low | Phone, web | Text over 100,000 characters was cut without a warning. | **Fixed** — A warning at the limit, on both apps. |
| Q5-61 | Low | Phone | The phone's export left out pictures only the server held, without a count. | **Fixed** — The export says how many pictures were not downloaded to this phone yet. |
| Q5-62 | Low | Phone | A few buttons had no label, and some tap targets were under 48 dp. | **Fixed** — Labels on the onboarding buttons; 48 dp map buttons and compact buttons. |
| Q5-63 | Low | Web | One physical `right-` utility left in an RTL layout. | **Fixed** — `end-3`. |
| Q5-64 | Low | Phone | 44 strings no screen used. | **Fixed** — The 44 unused strings are gone. |
| Q5-65 | Low | Web | A repository built and never used. | **Fixed** — Removed. |
| Q5-66 | Low | Core, phone | `12.345+0` was accepted where `12.345` was refused. | **Fixed** — A number with more than two decimals is refused inside a sum too; fixture cases. |
| Q5-67 | Low | Phone, web | An expense logged ahead paid its XP today. | **Fixed** — A day still in the future pays no XP, on both apps. |
| G5-14 | Low | Web | Planting from a list or a goal and achieving a goal did less than on the phone. | **Fixed** — Book prefill, habit by default from a goal, and the achievement burst with its +50. |
| G5-15 | Low | Docs | Local-Database.md stopped at schema v23. | **Fixed** — v24 in the history, and the current version stated. |
| G5-16 | Low | Docs | Sync-API.md was behind the code. | **Fixed** — The added columns, custom exercises only, and when the phone really syncs. |
| G5-17 | Low | Docs | Onboarding, Core-Entities, Gamification, the weekly report and the README were behind the code. | **Fixed** — Onboarding, Core-Entities, Gamification, the weekly report as built, and the README. |

## Checked and fine

- No account can reach another's rows, files or sessions; tokens are
  pinned to EdDSA with issuer and audience; refresh tokens rotate and a
  reuse ends the family; reset and verify links are 256-bit, hashed at
  rest, single use and short-lived; passwords are argon2id with the
  OWASP parameters.
- Every body goes through zod, strictly; Mongo operators are refused;
  CORS and the refresh cookie are what they should be; the CSP and HSTS
  are sent on both deployment paths; the service worker caches no API
  answer; the web's key cannot be extracted.
- Tests and analysers were clean before and after; no TODO or FIXME
  anywhere; en and ar have the same keys on both apps; RTL has no
  physical sides left; money, goals, share links, gym loads and sleep
  debt go through shared rules the Dart tests read too.

Related: [[Audit-Home]] · [[Security-Audit]] · [[Audit-v3-Beta]] · [[Checkpoint-10]]
