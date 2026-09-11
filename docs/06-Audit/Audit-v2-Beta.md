# Audit 2 — the v2 beta

*Read on 2026-09-11, on the [[Checkpoint-6]] tree (schema v14, 534 tests green, analyzer clean). Read-only: nothing was changed while reading. Every finding has an id, a severity, the file and line, why it matters here, and a fix.*

The first audit ([[Audit-Home]]) was done on the round-5 tree, before
notes, the gallery, the archive, the body and the gym existed. Half
the app is newer than that report. This one reads the whole domain
and data layer again — about twenty thousand lines — with four
questions rather than three: is the business logic right, where is it
*unspecified* (the spec says nothing and the code decided), is the
code the quality I want to keep building on, and is it secure.

The short version. The core rules hold — the 3 AM day, the over-log
cap, atomic check-ins, the ledger, the archive that never deletes —
and the code is consistently clean, small and commented with its
reasons. What I found is at the seams: three features that count as
"activity" for one purpose and not another, an importer that trusts
the file it is given a little too much, a streak that only ever goes
up, and a handful of rules the specs never wrote down and the code
guessed at. Nothing here corrupts data in normal use. One thing could
if someone handed me a crafted archive.

## Counts

| Section | High | Medium | Low | Info |
| :--- | :---: | :---: | :---: | :---: |
| Business logic (B-01 … B-11) | 2 | 4 | 5 | – |
| Underspecified (N-01 … N-10) | – | – | – | 10 |
| Code quality (Q2-01 … Q2-10) | – | 2 | 8 | – |
| Security (S2-01 … S2-09) | 1 | 3 | 3 | 2 |

Severity means: **High** — wrong numbers on screen or data at risk in
a realistic use; **Medium** — wrong in a case I will actually hit;
**Low** — wrong in a corner, or a debt worth paying before sync.

---

## A. Business logic

### B-01 · High — An album's streak never breaks

`lib/features/gamification/domain/streak_service.dart:287-296`,
`:398-421`

`reconcile` judges `_habits()` — commitments of type habit — and
nothing else. A scheduled album has its own streak row (written by
`onAlbumMemory`, line 133) and its own schedule, and rule G3 says it
*is* a seed. But no line of `reconcile` ever looks at an album: a
memory a day for ten days, then a month of nothing, and the album
still shows a ten-day streak. It only ever goes up, and only ever
comes down by a same-day delete.

**Fix.** Judge scheduled albums beside habits: for each album with a
schedule and `deletedAt == null`, on each closed day, `isDueOn` with
`doneDaysInWeekOnce`, `countOn(album, day) == 0` → break. The
idle fast path (`_breakEverythingIdle`) needs the same loop. Test:
an album due daily, one memory, reconcile two days later, streak 0.

### B-02 · High — Streaks are lost on a new phone

`lib/features/import/domain/import_service.dart:68-694`,
`lib/features/export/data/export_repository.dart:238-248`

The archive carries a `Streaks` sheet. The importer does not read
it — there is no `SheetNames.streaks` block among the twenty-six —
and nothing rebuilds streaks from the check-ins it does import.
Worse, the `Settings` sheet *is* imported wholesale, so
`streak.lastJudgedDay` arrives from the old phone and `reconcile`
believes every past day is already judged. Result: install on a new
phone, import, and the global streak reads 0 with a best of 0, for
good. The XP comes back (the ledger is imported); the number the app
is built around does not.

**Fix.** Either import the `Streaks` sheet (merge by `scope`, newer
`UpdatedAt` wins — the columns are already there), or drop the
streak rows and rebuild them from check-ins and memories after an
import. The second is more honest with rule 8 and would also fix
B-01 retroactively. Test: export, wipe, import, streak equal.

### B-03 · Medium — A quiet weekend breaks a three-times-a-week habit

`lib/features/gamification/domain/streak_service.dart:329-347` vs
`:405-413`

Two judges disagree. `_judgeHabit` judges a `TimesPerWeekSchedule`
only when its week closes on Sunday, as it should. But
`_breakEverythingIdle` — the fast path for a span with no check-ins
at all — asks `schedule.isDueOn(d)` with `doneDaysThisWeek` left at
zero, and a flexible schedule answers *true* on every day. So a
Friday-to-Sunday trip with nothing logged breaks a "3× a week" streak
on the Friday, though Monday to Thursday had already met the quota.

**Fix.** In the idle path, skip `TimesPerWeekSchedule` unless the
idle span contains a Sunday whose week (`_doneDaysInWeek`) fell
short — the same test the slow path applies.

### B-04 · Medium — "Active" means three different things

`lib/features/gamification/domain/streak_service.dart:313-324`
(`_anyCheckInBetween`),
`lib/features/planner/domain/notification_planner.dart:526-569`
(`_lastActiveDay`, `_activeOn`),
`lib/features/gamification/domain/streak_service.dart:79-109`
(`productiveActions`)

- The Daily Harvest Goal counts check-ins **and** scheduled-album
  memories (`albumActions`).
- The reconcile fast path counts **check-ins only** when deciding
  whether a span was idle — a run of days where the only thing I did
  was feed a scheduled album goes down the idle path (and, with
  B-03, breaks flexible habits).
- The comeback ladder counts check-ins **and expenses**, and nothing
  else: a picture in a scheduled album, a night written down, a
  finished gym session that went through a check-in — the last one
  counts, the first two do not. Someone who logs sleep every morning
  and nothing else gets told they have been away for a week.

**Fix.** One query, `lastActivityDay()`, that looks at every table
whose rows the app itself treats as "I did something" — check-ins,
memories in scheduled albums, expenses, sleep nights, weights,
finished sessions — and one definition in [[Notifications]] and
[[Gamification]] that says so (see N-04).

### B-05 · Medium — A deletion can never win an import

`lib/features/import/domain/import_service.dart:108-130` (check-ins),
`:131-153` (seed notes), `:154-178` (expenses), `:179-206` (money)

These four tables have an `updated_at` column, and every soft delete
writes it. The importer stamps them with `loggedAt` instead, which a
delete never touches. So an archive taken *after* an expense was
deleted, imported onto a phone that still has the expense live,
compares equal stamps, says "unchanged", and leaves it live. The
merge rule — newer wins — is right; the column is wrong.

**Fix.** Stamp with `UpdatedAt` wherever the sheet has one (the
export already writes it for expenses and money; add it to the
check-in and seed-note sheets). Test: delete, export, restore the
row locally, import, row deleted.

### B-06 · Medium — XP that is never taken back

`lib/features/finances/data/finances_repository.dart:198-216`,
`lib/features/health/data/sleep_repository.dart:88-100`

The first expense of a day pays +10 (`expenses:<day>`); deleting it
— even the only one — leaves the +10. A night written down pays
+15; removing the night leaves it. A check-in that is undone
reverses its XP with a mirror row (`check_in_service.dart:139-156`),
and a memory does the same. The ledger's promise is that balances
are sums of true events; two of the events can be un-happened
without a mirror row.

**Fix.** On `remove`, when no other expense remains on that day,
write `-expenseLogXp` with reason `expenses-undo:<day>`; the same
for sleep. Restore pays it back.

### B-07 · Low — Two nights can land on one morning

`lib/features/health/data/sleep_repository.dart:70-73`

`existing` is read *before* the transaction opens. Two writes for the
same morning that overlap — a double tap on Save, a snackbar retry —
both see nothing there, both insert, and from then on `on(day)`'s
`getSingleOrNull` throws on two rows, which is the sleep card gone
for that morning.

**Fix.** Read inside the transaction, or make `(harvest_day)` unique
among undeleted rows. A partial unique index is one migration.

### B-08 · Low — A hand-edited setting stops the day being judged

`lib/features/gamification/domain/streak_service.dart:273-275`

`jsonDecode(valueJson) as String?` is an unguarded cast on the one
setting that gates every streak verdict. The `Settings` sheet is
imported as raw text; a person who opened the workbook and saved it
loses the quotes around `2026-09-01`, `jsonDecode` throws, `reconcile`
throws, `bootstrap` records *reconcile: FormatException* on every
start, and no day is ever judged again until the row is fixed.
`SettingsRepository._asText` already does this tolerantly; this
read bypasses it.

**Fix.** Read through `SettingsRepository.getString`, or catch and
fall back to `yesterday.previous` the way a missing row does.

### B-09 · Low — Sleep debt looks back fourteen *logged* nights

`lib/features/health/domain/sleep.dart:73-76`

`sublist(length - window)` takes the fourteen most recent rows,
however far apart they are. Someone who logs a night a week is
carrying two months of debt into "the last fourteen nights", and the
spec's promise that a bad spring is not held against the summer only
holds for someone who logs every day. [[Business-Rules]] #3 says
"looks back fourteen nights" without saying which.

**Fix.** Decide (see N-06). I think calendar nights is the honest
reading: filter `day >= today - 13`, then the floor-at-zero walk.

### B-10 · Low — The morning ritual depends on the 3 AM job

`lib/features/planner/domain/notification_planner.dart:118-145`,
`:251-272`

`planToday` schedules only today's rituals. The 07:00 morning
reminder for *tomorrow* exists only if something replans between
3 AM and 7 AM — the WorkManager job, or an app open. WorkManager is
periodic and inexact, and OEM battery managers kill it; the doc calls
the job "an optimization" and lazy reconcile covers the streak, but
the morning ritual is the one thing that has to fire *before* the
app is opened.

**Fix.** Schedule the next two mornings (ids `morning`, `morning+1`),
and cancel-and-replan both on every plan.

### B-11 · Low — Nothing enforces "max 4 a day"

`lib/features/planner/domain/notification_planner.dart` (whole
class), [[Business-Rules]] #9

Four rituals, up to a thousand seed reminders, album reminders, debt
reminders, the sleep pair and snoozes are all scheduled independently;
no counter exists. The rule is aspirational. Either enforce it
(rank, then drop the quietest past four) or rewrite the rule to what
the code does: *rituals are capped at four; a time you set on a
seed always fires.*

---

## B. Underspecified

Places where the spec is silent and the code chose. None is a bug;
each is a decision I should make on paper before sync makes it
permanent.

| # | Where the spec is silent | What the code does today | What I would write |
| :-- | :--- | :--- | :--- |
| N-01 | **Correcting a debt payment.** [[Finances]] describes payments, never their undo. `debt_payments.deleted_at` exists; no method or screen sets it (`vault_repository.dart` has `payDebt` only). | A mistyped payment is permanent; the debt settles wrongly. | Same-day undo with the wallet movement reversed, like an expense. |
| N-02 | **Coins.** [[Gamification]] says coins come from check-ins, milestones and rank-ups, and buy freezes, themes and skins. | Only streak milestones pay (`streak_service.dart:192-194`); freezes are the only purchase. | Say what is in and what is parked, the way quests were parked. |
| N-03 | **Who an archive is from.** [[ADR-007-Archive-Format]] says it comes back; nothing says whether an archive is trusted. | Fully trusted (see S2-01, S2-02, S2-09). | "An archive is data, never instructions": paths regenerated, settings whitelisted, sizes bounded. |
| N-04 | **What "logging" means** for the comeback ladder and the idle fast path (B-04). | Three definitions. | One list of tables, in [[Notifications]]. |
| N-05 | **When a flexible habit breaks**, and **when a week starts.** [[Productivity-Engine]] says a times-per-week habit "stops asking" once met; not when it fails. `HarvestDay.weekStart` is Monday. | Judged on Sunday; Monday weeks everywhere, Arabic included. | Sunday close, Monday start, written down — and a note that this is not locale-dependent on purpose. |
| N-06 | **The sleep-debt window** (B-09). | Fourteen logged nights. | Fourteen calendar nights. |
| N-07 | **Reminder urgency.** [[Notifications]] still describes gentle-to-urgent escalation; since round 5 every reminder is alarm-grade, full-screen, on the alarm stream (`notifications.dart:320-343`). | Everything is urgent. | Rewrite the spec to the round-5 decision, or give per-seed reminders `alarm: false` and keep the alarm for rituals. |
| N-08 | **A gym seed ticked by hand** ([[Phase-4-Health-and-Gym]] backlog). | Allowed; the streak moves without a session. | Offer a bare session on a hand tick, or send the tick to the program. |
| N-09 | **Steps that go down.** Health Connect revises a day when a watch syncs late; the app overwrites, which is right — but the +5 already paid stays if the revised total drops under the goal. | Paid once, never taken back. | Pay at day close, not on every pull; or accept and say so. |
| N-10 | **Moving a weight to another day** (`health_repository.dart:68-90`). The +5 is keyed to the day it was logged on. | `updateWeight` changes the day; the ledger row stays on the old one. | Re-key the ledger row, or forbid changing the day. |

---

## C. Code quality

The general picture is good: feature-first layout held through six
new features, every platform edge is an interface with a fake, no raw
SQL, no user text in logs, `very_good_analysis` clean, 534 tests.
What follows is where the seams show.

### Q2-01 · Medium — `HarvestDay.parse` in six row mappers

`finances_repository.dart:302`, `vault_repository.dart:84,289`,
`sessions_repository.dart:135`, `health_repository.dart:219,225`

`parse` throws; `commitments_repository.dart:380` uses `tryParse` and
skips the row with a log line, which was audit-1 fix Q-05. One bad
day key — an archive cell somebody typed — and the whole stream that
maps the table errors, which is the Granary blank rather than one
row missing. Same treatment as commitments.

### Q2-02 · Medium — The gym rebuilds its history on every tick

`sessions_repository.dart:86-95` (`watchFinished`), `:112-160`
(`_hydrate`), `nextDay`

`watchFinished(limit: 50)` re-hydrates fifty sessions — every
exercise, every set, four queries deep — on *every* write to any of
the three session tables, and a set tick is such a write. The gym
screen is behind the session screen during a workout, so this is
fifty hydrations per tick for nothing on screen. The pattern (Q-44
in audit 1, deferred) was fine at the field's scale; here it is
per-tick. Hydrate lazily, or watch only the sessions table for the
list and hydrate on open.

### Q2-03 · Low — Gym writes skip the outbox and the transaction

`sessions_repository.dart:439-531` (`removeSet`, `skipExercise`,
`replaceExercise`, `setExerciseRest`, `setExerciseNote`, `pause`,
`resume`), `programs_repository.dart:257-432` (days, slots, sets)

[[Local-Database]] promises "every local write also appends to the
outbox". Programs and sessions append for the parent row only; a
skipped exercise, a replaced one, a set removed, a day renamed — none
leave a trace for [[Sync-Strategy]] to replay. Cheap to add now,
expensive to backfill in Phase 6.

### Q2-04 · Low — `ImportService._run` is one 620-line method

`import_service.dart:68-694`

Twenty-six near-identical blocks. B-02 happened because a block was
missing and nothing could notice. A list of table descriptors —
sheet name, local stamps, stamp column, key column, insert — and one
loop would make the omission a type error, and the file a fifth the
length.

### Q2-05 · Low — `like('$folder/%')` with a user-typed folder

`notes_repository.dart:220,242`

`%` and `_` are wildcards. Renaming or trashing a folder called
`100%` or `q_a` matches more than its own subtree. Escape them, or
filter with `startsWith` in Dart on the (small) list.

### Q2-06 · Low — Two copies of `_paidByDebt`, twelve of `_outbox`

`notification_planner.dart:591-601` ≡ `vault_repository.dart:296-306`;
`_outbox` in every repository.

Harmless duplication, but the planner reaching into `debt_payments`
directly is the layering leak Q-39 named. An `Outbox` helper on the
database class and a `paidByDebt` on the vault repository the
planner calls would end both.

### Q2-07 · Low — A date cell imports as "now"

`archive_reader.dart:136`

`DateTimeCellValue() => value.toString()` stringifies the wrapper,
not its date. Any timestamp column a spreadsheet converted to a real
date comes back unparseable and falls to `DateTime.now()` — a
created-at of today on a two-year-old seed. Read `.value` out of the
cell.

### Q2-08 · Low — Media fetched with no size bound

`exercise_media.dart:89-95`

`writeAsBytes(response.bodyBytes)` with no cap. `RatesService` caps
its body at 64 KB; an animation is a few MB. Cap at, say, 20 MB and
check the content type is an image.

### Q2-09 · Low — The three paired screens are one screen three times

`body_screen.dart`, `records_screen.dart`, `farmer_screen.dart`
([[Checkpoint-6]])

Same `TabController`, same switch, same "tabs only when both halves
are on". A `PairedScreen(halves: …)` would hold the rule once. I
wrote it three times this week; it is on me.

### Q2-10 · Low — Where the tests are thin

534 tests, but one file each for gallery, security, widget and
import, and the rules in this report's B section are exactly the
ones without a test: reconcile with a scheduled album, an import
that carries a deletion, the comeback ladder's idea of activity, an
importer handed a hostile path. Every fix above should land with the
test that would have caught it.

---

## D. Security

Verified and unchanged from audit 1: `allowBackup=false` with
exclusion rules for everything; no cleartext traffic and no
`http://` anywhere; the two outbound calls are HTTPS to keyless
endpoints and carry nothing; no raw SQL; no user text in logs;
release builds signed with the upload key, shrunk and obfuscated;
every exported component is `MainActivity` or a stock AndroidX one.
[[Checkpoint-6]]'s additions — the Health Connect read permission,
the rationale intent filter and the permission-usage alias — are
scoped to `READ_STEPS` and nothing else, and the alias is guarded by
`START_VIEW_PERMISSION_USAGE` as the platform requires.

### S2-01 · High — Path traversal in the archive importer

`import_service.dart:783-789`, `gallery_storage.dart:61-65`

The importer writes each picture to the path in the sheet's
`StoredPath` cell: `_storage.write(bytes, row['StoredPath'])`, which
is `File(p.join(root, relative))`. Nothing checks that `relative`
stays under the gallery directory. `../../app_flutter/harvest.sqlite`
walks out; an absolute path makes `p.join` discard the root
entirely. A crafted zip — "here is my Harvest archive, try importing
it" — overwrites the database, or any file the app can write, and
the preview reports it as *1 file, new*. It needs a person to pick
the file, so this is not remote; it is still the one place in the
app where a file from outside decides where bytes go.

**Fix.** Ignore `StoredPath` and regenerate the destination with
`GalleryStorage.pathFor(albumUuid, day, extension, uuid)` — the row
already carries everything that needs. If keeping the stored path
for the no-op re-import, accept it only when
`p.isRelative && p.normalize(path)` does not start with `..` and
contains no absolute segment. Test both shapes.

### S2-02 · Medium — The archive is decoded whole, in memory

`archive_reader.dart:69-89`, `archive_picker.dart:29-31`

`readAsBytes` on the picked file, `ZipDecoder().decodeBytes` on all of
it, then a `Uint8List` copy of every entry. A zip that expands to a
few gigabytes — deliberately, or a two-year gallery — takes the app
down with an out-of-memory. Self-inflicted only, but the archive is
the feature that has to work on the day I most need it.

**Fix.** Refuse archives above a stated size, and entries above one,
before decoding; stream entries rather than copying all of them.

### S2-03 · Medium — The widget is outside the lock

`widget_service.dart:150-157`, `WidgetKeys.defaults`

The app lock's promise ([[Business-Rules]] #10, [[Checkpoint-2]]) is
the whole app behind the phone's own credential. The home-screen
widget shows today's spend and the wallet balance on the home
screen, lock or no lock, and its money section is on by default.
Somebody who armed the lock to keep their finances off a shared
kitchen table has them on the launcher.

**Fix.** When `security.appLock` is on, hide the money section (or
flip its default) and say so beside the lock switch.

### S2-04 · Medium — Settings are imported wholesale

`import_service.dart:669-688`

Every `Settings` row in an archive lands in `kv_settings`: the app
lock flag, every scheduled notification-id list, `pomodoro.active`,
`streak.lastJudgedDay` (B-02). An archive can arm the lock on the
phone that imports it, or resurrect a running pomodoro from another
phone. Benign today; it is the same trust problem as S2-01 in a
smaller coat.

**Fix.** Whitelist the keys an archive may set — the user's
preferences — and skip the app's own bookkeeping.

### S2-05 · Low — Plaintext beside the database

`HomeWidgetPreferences.xml` (shared prefs, written by
`widget_service.dart`), the notification plugin's own store

Task titles, the spend and wallet strings, and every scheduled
reminder's payload (a debt's person and amount, `notification_planner.dart:350-358`)
sit in shared preferences in plaintext. This is the same exposure as
the database itself — someone with the file reads it — and belongs
under S-04 (encryption at rest, still deferred). Noting it so S-04's
scope is honest: the database is not the only file.

### S2-06 · Low — Media integrity

`exercise_media.dart:65-68, 89-95`

Fetched from a commit-pinned path over HTTPS, with no hash. A
compromised upstream account serves whatever it likes to the image
decoder. The pin and the decoder's own hardening are the mitigation;
a per-file hash in the trimmed catalogue would close it.

### S2-07 · Low — Zip entry names are used as map keys only

`archive_reader.dart:79-88`

Entry names never touch the filesystem (only `StoredPath` does,
S2-01), so `../` in an entry name is inert. Verified; recorded so
the next person does not re-check it.

### S2-08 · Info — Permission surface

`AndroidManifest.xml`

`INTERNET` (rates, media), `POST_NOTIFICATIONS`, exact-alarm pair,
`USE_FULL_SCREEN_INTENT`, `VIBRATE`, `WAKE_LOCK`,
`RECEIVE_BOOT_COMPLETED`, `USE_BIOMETRIC`, `WRITE_EXTERNAL_STORAGE`
capped at API 28, and now `health.READ_STEPS` and
`ACTIVITY_RECOGNITION`. Each is used; none is broader than its
feature. The camera and the document picker need no permission by
design.

### S2-09 · Info — The native steps channel

`android/.../StepsChannel.kt`

One permission request at a time (`busy` otherwise), Health Connect
reads on the activity's lifecycle scope, denial reported as a value
rather than an exception, the sensor listener unregistered on first
event or a three-second timeout. No data leaves the process.

---

## Status — remediated 2026-09-11

Six waves, in the order below, each landing with the analyzer clean,
the suite green and the test that would have caught the finding.
534 tests before, 566 after.

| Wave | Findings | What landed |
| :--- | :--- | :--- |
| 1 · the importer's trust | S2-01 · S2-02 · S2-04 | `GalleryStorage.isSafeRelative` decides whether a `StoredPath` is honoured; anything else is regenerated with `pathFor`. `ArchiveLimits` refuse a file, an entry or a total that is too large, from the zip's directory before anything is inflated. `importableSettingPrefixes` is the allow-list; the app's bookkeeping never comes from outside. |
| 2 · the importer's memory | B-02 · B-05 · Q2-04 · Q2-07 | The importer is a list of `_Table` descriptors and one loop. The `Streaks` sheet is in the list. `UpdatedAt` is the stamp wherever a table has one, and the check-in, seed-note, expense, money, weight and session sheets now carry it. A date cell reads as its date. |
| 3 · one idea of activity | B-01 · B-03 · B-04 · B-08 | `ActivityLog` is the definition; the streak engine's idle fast path and the comeback ladder both ask it. `reconcile` judges scheduled albums beside habits, in both paths. A flexible habit is judged on Sunday only, idle or not. The last-judged setting reads tolerantly. |
| 4 · the ledger and the launcher | S2-03 · B-06 · B-07 | The widget shows no money while the lock is armed, the switch says so, and the lock switch redraws the launcher. Removing the day's last expense, or a night, writes the mirror row; restoring pays again, once. The sleep write reads inside its transaction. |
| 5 · the rules | N-01 … N-10 | Written into [[Finances]], [[Gamification]], [[Notifications]], [[Productivity-Engine]], [[Health]], [[Gym]], [[Business-Rules]] #3 and #9, and [[ADR-007-Archive-Format]] rules 7–8. N-01 also got its code: a payment is removed by long-press with an undo, its wallet movement follows and a settled debt reopens. N-06 also got its code: the debt window is fourteen calendar nights ending today. |
| 6 · the debts | Q2-01 · Q2-02 · Q2-03 · Q2-05 · Q2-06 · Q2-08 | Every row mapper falls back to the day the row was logged on rather than throwing. Sessions hydrate in three queries however many there are. Every gym write — days, slots, sets, maxes, exercises, ticks, pauses — appends to the outbox. Folders match in Dart, not with `LIKE`. The planner asks the vault how much is paid. Media is written only when it is an image under 20 MB. |

**And the cosmetic two, the same evening.** Q2-09: `PairedScreen`
holds the paired-tab rule once and Body, Records and the farmer's tab
are each a list of halves and a builder. Q2-06's second half: the
database has one `logChange`, and the twelve private helpers delegate
to it. B-09's decision is made (calendar nights) and coded.
B-10 (the morning ritual leaning on the 3 AM job) and B-11 (the cap)
are answered by the rewritten rule #9 rather than by code: the
rituals are the cap, and the morning one is replanned on every
resume — a phone that sleeps through 3 AM *and* is not opened before
7 AM misses one morning reminder, which I can live with until the
comeback ladder proves otherwise. N-08 (the hand-ticked gym seed) and
N-09 (steps XP never taken back) are decisions, written down, not
gaps.

**One rule changed while fixing.** B-06 reversed a decision the sleep
tests had pinned — *"deleting a row is a correction, not a
clawback"* — because with a new uuid per re-log it let log-delete-log
farm fifteen XP a round. The ledger now takes back what a deleted
night or a day's last expense paid, with a mirror row, exactly as an
undone check-in always has.

## Remediation, in the order I took it

1. **S2-01, S2-02, S2-04** — the importer. Regenerate paths, bound
   sizes, whitelist settings. One afternoon, three tests.
2. **B-02, B-05, Q2-04, Q2-07** — the importer again: the Streaks
   sheet, `UpdatedAt` stamps, the descriptor loop that makes the
   first two impossible to forget, the date cell.
3. **B-01, B-03, B-04** — one definition of activity, albums judged,
   flexible habits judged only on Sunday. These change what the
   streak says, so they ship with a migration note and the tests.
4. **S2-03, B-06, B-07, B-08** — the widget behind the lock, XP
   mirrored on delete, the sleep race, the tolerant read.
5. **N-01 … N-10** — write the missing rules into the specs; most are
   a sentence each.
6. **Q2-01, Q2-02, Q2-03** — tolerant mappers, the gym's per-tick
   hydration, the outbox — before Phase 6 needs them.

Related: [[Audit-Home]] · [[Security-Audit]] · [[Code-Quality-Audit]] · [[Checkpoint-6]]
