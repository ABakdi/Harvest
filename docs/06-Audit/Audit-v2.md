# Audit 3 — v2.0.0

*Read on 2026-09-19, on the v2.0.0 tree (b590f23, schema v14, 580 tests green, analyzer clean). Read-only: nothing was changed while reading. Every finding has an id, a severity, the file and line, why it matters here, and a fix.*

[[Audit-v2-Beta]] read the domain and data layers on the beta.2 tree
and was remediated the same day. Since then two checkpoints went in
([[Checkpoint-7]], [[Checkpoint-8]]), and the steps channel became a
plugin. That is only about two thousand lines. So this audit has four
parts, and only the first is about the new code:

1. **What changed since the second audit**: the 3 AM steps close,
   the expense that moves to another day, the gym seed ticked by hand,
   the `harvest_steps` plugin.
2. **The screens.** The presentation layer of notes, the gallery,
   health, the gym and settings has never been audited. The first
   UX audit was on the round-5 tree, before any of them existed.
3. **The specs against the code.** Four phases of "the spec says X"
   written in advance, checked against what shipped.
4. **The deferred list.** Everything audits 1 and 2 left open, and
   whether it is still open.

The short version. The rules the last audit wrote down still hold,
and so do its fixes. The importer is still the only place where a
file from outside decides anything, and it still checks the paths.
What I found this time is mostly in the **screens**. Three of them
lose what I typed:
- the note editor, when I switch notes;
- the exchange-rate card, which clears a rate I never touched;
- the finished gym session, whose picture prompt leads nowhere.

The steps close I added in [[Checkpoint-8]] is wrong in both
directions on a phone without Health Connect. Most of the time it is
blind, and when it can see, it counts twice. Health Connect phones
are unaffected, and mine is one. The specs have drifted a long way
from the code, mostly in [[Notifications]], [[Onboarding]] and the
architecture pages.

## Counts

| Section | High | Medium | Low | Info |
| :--- | :---: | :---: | :---: | :---: |
| Business logic (B3-01 … B3-10) | 1 | 5 | 4 | – |
| Screens (U3-01 … U3-20) | 2 | 12 | 6 | – |
| Security and platform (S3-01 … S3-09) | – | 1 | 7 | 1 |
| Code quality (Q3-01 … Q3-04) | – | 1 | 3 | – |
| Promised, not built (P3-01 … P3-09) | – | – | – | 9 |
| Spec drift (D3-01 … D3-16) | – | – | – | 16 |

Severity means the same as in [[Audit-v2-Beta]]:
- **High:** wrong numbers on screen, or data at risk, in realistic use.
- **Medium:** wrong in a case I will actually hit.
- **Low:** wrong in a corner case, or a debt worth paying before sync.

---

## A. Business logic

### B3-01 · High — The sensor's 3 AM close is blind, and when it sees, it counts twice

`lib/features/health/domain/steps_sync.dart:96-120`,
`lib/core/platform/day_reset.dart:73-89`

This only affects the sensor path. Health Connect answers per window
and is not affected. There are two problems, and they point in
opposite directions.

- **Blind.** Since Android 9, an app in the background receives no
  sensor events, and on-change sensors like `TYPE_STEP_COUNTER` are
  included. The WorkManager isolate registers its listener,
  `HarvestStepsPlugin.kt` waits out its three-second timeout, and
  `counter()` returns null. `_sensorAtDayEnd` then reports `synced`
  and writes nothing (line 102). So the day that ended never gets its
  evening steps, and the next open anchors the new day to the last
  reading of the evening before. The evening's steps land on the new
  day. The emulator check in [[Checkpoint-8]] only ever reached
  `needsPermission`, so this path has never actually been seen
  working.
- **Twice.** When the job does get a reading (API 26–27, or the app
  in the foreground when it runs), it adds `counter − lastCounter` to
  `ended` without asking two questions: what time it is, and whether
  the new day was already read. WorkManager's periodic work
  reschedules from the last run, so the job drifts later every day,
  and Doze defers it by hours. A worked case:
  - D's last reading is 1000.
  - At 7 AM on D+1, the app opens and anchors D+1 at 1000.
  - The counter reads 1200, so D+1 = 200.
  - The job runs at 9 AM, with the counter at 1500.
  - D gains 500, and D+1 still counts the same 500 on its next read.

  A run after a fall-back DST change is worse. The period lands the
  job at 2 AM, `HarvestDay.today().previous` names the day before the
  one that just ended, and a whole day's steps are filed a day early.

  The test that builds exactly this case, *does not re-anchor a day a
  pull already started* (`steps_sync_test.dart:187`), never asserts
  what the ended day's total became.

**Fix.**
- If `stepsOn(ended.next).lastCounter != null`, do not touch `ended`:
  only pay its goal.
- Only apply the reading when now is within a few hours after
  `ended.next.startsAt`.
- Accept in [[Health]] that on the sensor path, the evening's steps
  are written down on the next open. Or read the counter on the app's
  last pause before 3 AM, when the app is still in the foreground.
- Longer term: a one-off job re-aimed at the next 3 AM on every run,
  instead of a periodic one that drifts.

### B3-02 · Medium — A goal met the day before yesterday is never paid

`steps_sync.dart:63-68`, [[Health]] H9

H9 says a goal is paid by "whichever pull sees it first", but no pull
ever looks at days older than yesterday:
- `sync` pays today and yesterday;
- `closeDay` pays `ended`.

Suppose the 3 AM job is not allowed to read Health Connect in the
background (no background permission, so `needsPermission`), or it is
simply killed, and I don't open the app over a weekend. Then Monday's
open writes thirty days of totals and pays Monday and Sunday.
Saturday's ten thousand steps are on the chart and never in the
ledger.

**Fix.** After a Health Connect pull, pay every day in the window
that has no `steps:<day>` row, starting from the later of two dates:
the last paid day, or the day the goal was set. That keeps a new goal
from paying a month back.

### B3-03 · Medium — "Up next" goes back to day 1 after a bare session

`lib/features/gym/data/sessions_repository.dart:185-205`,
`lib/features/field/field_screen.dart:461`

`nextDay` finds the program's last finished session and looks up its
`dayUuid`. A bare session ("Went, no numbers", rule Y12) has the
program but no day, so the lookup fails and returns `days.first`. On
push/pull/legs, if I log push and then tick the seed by hand on pull
day, the gym offers push again instead of legs. Ticking legs by hand
happens to land on push, so the bug only shows mid-cycle.

**Fix.** Give the bare session the day that was up next
(`await nextDay(program)` before `startFreeform`), which is also
the truth. Test: Y11 after a Y12.

### B3-04 · Medium — Undoing a hand tick leaves the session behind

`field_screen.dart:364-384`, `check_in_service.dart:120`

Undo removes the check-in. The empty finished session stays in
history and still moves `nextDay`. If I tick, undo and tick again, I
get two empty sessions, each paid +10 at the time. Y12 promises that
"the streak and the log always agree".

**Fix.** When the seed is bound to a program, undo also soft-deletes
that day's finished sessions that have no sets.

### B3-05 · Medium — A moved expense leaves its wallet movement on the old day

`lib/features/finances/domain/finance_actions.dart:78-94`,
`lib/features/finances/data/vault_repository.dart:139-156`

There are two cases:
- `updateLinked` rewrites amount, currency, reference and note, but
  never `harvestDay`. Moving a receipt from 31 August to 2 September
  leaves the wallet's *expense · Food* in August in the Vault.
- Switching "from the wallet" on while editing last week's expense
  calls `move` with no `day:`, so the movement is dated today.

**Fix.** Pass the expense's day to both calls. Test: move an expense
with a wallet movement, then check the movement's day.

### B3-06 · Medium — The step windows freeze at 3 AM

`lib/features/health/presentation/health_providers.dart:26-27`,
`health_repository.dart:120`

`watchSteps(days:)` computes `HarvestDay.today()` once, when the
stream is subscribed, and the provider does not watch
`currentHarvestDayProvider`. The Body tab lives in the shell's
`IndexedStack`, so after a night the "7-day average" covers eight
days and "Last 30 days" covers thirty-one. Q-01, from the first
audit, fixed exactly this everywhere else.

**Fix.** `ref.watch(currentHarvestDayProvider)` in `recentSteps`,
passed into the query.

### B3-07 · Low — The expense sheet keeps the day it was opened on

`lib/features/finances/presentation/expense_sheet.dart:113`

`HarvestDay _day = HarvestDay.today()` is set when the sheet opens
and is always passed to `logExpense(day:)`. A sheet opened at 2:58
and saved at 3:02 files under yesterday. Before [[Checkpoint-8]],
the repository asked for the day at write time.

**Fix.** Keep `_day` null until the chip is used, and let the
repository decide otherwise.

### B3-08 · Low — The steps goal can be paid twice across isolates

`health_repository.dart:185-205`

`_payOnce` reads and then inserts, outside a transaction, and
`ledger.reason` has no unique index. The UI isolate and the 3 AM
job's isolate have separate connections. If a sync is running as
the job fires, both can pay `steps:<day>`. The same shape exists for
`expenses:<day>`.

**Fix.** A partial unique index on the reasons that must be paid
once, with `insertOrIgnore`. That needs one migration.

### B3-09 · Low — A gap in sensor readings lands on one day

`steps_sync.dart:153-161`

`lastCounterBefore` returns the last reading from any earlier day. If
nothing read the sensor for three days, every step since then lands
on the first day that does, and the chart shows one 30,000-step day
between two blanks. The same happens after a permission is revoked
and granted again. A reboot whose new count has already climbed past
the old anchor is not noticed as a reboot. None of this is new, but
B3-01 makes it the common case.

**Fix.** Store the boot time (`SystemClock.elapsedRealtime` against
wall clock) with each reading. A reading from another boot is then
a re-anchor, and a gap longer than a day adds nothing.

### B3-10 · Low — "Start the session" ignores the bound program

`field_screen.dart:455`

The hand-tick choice sheet's first option opens the generic start
sheet, not the program bound to the seed. Starting a different
program from there never checks this seed in.

**Fix.** Pass the bound program to `startSession` so its "Up next"
day is the one offered.

---

## B. The screens

### U3-01 · High — Closing a note throws, and can lose the last edit

`lib/features/notes/presentation/note_editor.dart:48-50`, `:70-78`

`dispose` uses `ref` twice:
- once through the lazy `_repository`;
- once directly, in `ref.read(writingNoteProvider.notifier)`.

`StatefulElement.unmount` clears the element's widget *before* it
calls `state.dispose()`. So `context.mounted` is already false, and
flutter_riverpod 3.4.2 throws *Using "ref" when a widget is about to
or has been unmounted*. Line 78 throws on every close, which means
three things:
- `super.dispose()` never runs;
- `writingNote` stays on;
- if the first debounced save of the session had not fired yet, the
  lazy repository is read for the first time in `dispose` and throws
  too, so the last half-second of typing is lost.

The comment above the save says this is exactly what the code is
there to prevent. It fires on every note switch and every
Notes → Gallery tab change.

**Fix.** Read the repository and the notifier in `initState`, keep
them in fields, and use only the fields in `dispose`. Test: pump an
editor, type, dispose within 500 ms, then check the body was saved.

### U3-02 · High — The rate card clears a rate I never touched

`lib/features/settings/presentation/rates_card.dart:39-41`, `:60-80`

`initState` fills the two fields from
`ref.read(rateSettingsProvider).value`. That provider is an
auto-disposed Drift stream that nothing else keeps alive, so on
first open it is still loading, and the fields start empty and are
never refilled.
- Tapping into a field and out again compares `''` with the stored
  rate, which has loaded by then.
- They differ, so `_saveManual('')` runs.
- That calls `repo.remove(key)` and shows *Rate cleared*.

Every DZD amount converted with that rate is then wrong until I
type it again.

**Fix.** Fill the controllers on the first data, with `listenManual`
and `fireImmediately`. Never save while the stored value is unknown.

### U3-03 · Medium — "Take a picture now?" after Finish does nothing

`lib/features/gym/presentation/session_screen.dart:245-281`

`_finish` pops the session route and then calls `_offerPicture` on
its own `context`. The dialog shows, because the route is still
animating out. By the time I tap *Yes*, the State is unmounted,
`!mounted` returns, and the capture sheet never opens. This is the
default "After" prompt in [[Gym]].

**Fix.** Ask before popping, or hand the album to the gym screen and
let it ask. Either way, the context that shows the sheet has to still
be alive.

### U3-04 · Medium — The timelapse flashes grey between frames

`lib/features/gallery/presentation/timelapse_screen.dart:97-101`,
`memory_view.dart:41-62`

This is likely rather than proven: I did not run it. Each frame gets
a `ValueKey(current.uuid)`, so a new `MemoryView` is built every
tick. That view makes its file future in `build`, calls `existsSync()`
and decodes a full-size image. At eight to twelve frames a second,
most frames are the placeholder. [[Gallery]] calls playback the
point of the feature.

**Fix.** Resolve the paths once, `precacheImage` the next few
frames, and use one `Image` with `gaplessPlayback` rather than a
keyed view per frame.

### U3-05 · Medium — Every picture is decoded at full size

`memory_view.dart:57`, used by `album_screen.dart:232`,
`compare_screen.dart:151` and `gallery_screen.dart:152`

`Image.file(file, fit: fit)` has no `cacheWidth`. A 1600 px picture
is about 7.7 MB decoded, whether it fills the screen or a 44 px
thumbnail. A three-column album grid goes past the 100 MB image
cache and re-decodes as it scrolls.

**Fix.** `cacheWidth` from the layout width × device pixel ratio.

### U3-06 · Medium — Exercise rows fetch media on every rebuild

`lib/features/gym/presentation/exercise_image.dart:58`

`future: ref.watch(exerciseMediaProvider).get(stem, kind)` is built
fresh on every build. In the picker, every search keystroke starts a
new fetch per visible row, and `get()` does not de-duplicate, so the
same file is downloaded and written concurrently.
`ExerciseMedia.cached()` exists for exactly this case, and nothing
calls it.

**Fix.** Lists use `cached()`. The detail screen fetches, with the
future memoised in state.

### U3-07 · Medium — The session screen rebuilds everything once a second

`session_screen.dart:52-55`, `:70`

`Timer.periodic(1 s, setState)` sits on the whole screen, so every
exercise card and set row rebuilds each second. On top of that, every
set tick rebuilds the whole session from `sessionProvider`.

**Fix.** Move the clock into its own small widget inside `_SessionBar`,
and give each exercise card a `select` on its own slice.

### U3-08 · Medium — The memory viewer shows the old note

`lib/features/gallery/presentation/memory_viewer.dart:46-57`,
`:161-169`

The viewer is given a snapshot list. After I save a note, the
caption does not change, and opening the note sheet again shows the
old text, so the edit looks lost even though it was saved.

**Fix.** Watch `albumMemoriesProvider(album.uuid)` inside the
viewer.

### U3-09 · Medium — Finishing a project can skip its archive

`field_screen.dart:137-141`, `:405`, `:545`

The `ValueKey` is on `_CropTile`, but `.animate()` wraps it in an
unkeyed `Animate`. Done items sort down after a check-in, so the
tapped tile's element is usually rebuilt. `_celebrateCompletion` then
reads the editor notifier after the completion dialog, from a dead
`ref`, which is the same `StateError` as U3-01. The project is never
archived. For the same reason the check-in burst is sometimes
silently skipped.

**Fix.** `.animate(key: ValueKey(...))`, and capture the notifier
before the first await.

### U3-10 · Medium — The notes tree indents on the wrong side in Arabic

`lib/features/notes/presentation/notes_sidebar.dart:284`, `:402`,
`:451`

`EdgeInsets.fromLTRB(md + depth * 14, …)` puts the nesting on the
right-hand, trailing edge in RTL, so the hierarchy reads backwards.

**Fix.** `EdgeInsetsDirectional.fromSTEB`.

### U3-11 · Medium — Deleting a folder: no sheet rule, no confirm, no undo

`notes_sidebar.dart:86-95`, `:345`

The folder options use a raw `showModalBottomSheet` around a
non-scrolling column, the only sheet in the app that does. Delete
trashes every note in the folder, with no confirm and a snackbar
with no Undo.

**Fix.** `showHarvestSheet`, and an Undo that restores the notes.

### U3-12 · Medium — The steps card overflows at 360 dp

`lib/features/health/presentation/health_screen.dart:165-241`

This is computed, not run. After the badge, the average column and
the settings button, about 110 px are left for
`Row(Text('12,345', headlineMedium), Text('9.3 km'))`, which needs
about 140 px and is not `Flexible`. It overflows at text scale 1.0.

**Fix.** `Flexible` + `FittedBox`, or a `Wrap`. Add a golden at 360 dp.

### U3-13 · Medium — The 30-day average is labelled "7-day average" in Arabic

`lib/features/health/presentation/steps_history.dart:87`

`l10n.stepsWeekAverage.replaceFirst('7-day', '')` edits a translated
string in code. The Arabic, «متوسط ٧ أيام», contains no "7-day", so a
thirty-day mean is labelled a seven-day one. In English the label
starts with a space. The average also includes today, which is not
over yet and pulls it down.

**Fix.** A `stepsDailyAverage` key. Leave today out.

### U3-14 · Medium — Set rows can be seeded in the wrong unit

`lib/features/gym/presentation/set_row.dart:49-80`,
`session_screen.dart:71`

This is unverified: it is a race I did not reproduce. The row's
controllers are filled once, from `widget.unit`. While the unit
stream loads, the session screen passes `kg`. When the screen is
reached from the field, the gym screen was never built, so the unit
may not have loaded yet, and `didUpdateWidget` ignores a unit change.
An lb user then sees kg numbers under an lb header, and a tick logs
them as lb.

**Fix.** Do not build rows until the unit has a value, or re-seed
when it changes.

### U3-15 · Low — A double tap on Start can create two sessions

`lib/features/gym/presentation/session_start.dart:305-353`

This is plausible, not reproduced. There are several awaits before
the sheet closes, no busy flag, and `start()` does not check for a
running session.

**Fix.** A busy flag, and `runningOnce()` checked inside the
repository's `start`.

### U3-16 · Low — Icon buttons with nothing to say

The following have no tooltip or semantics, so a screen reader hears
"button":
- `sleep_card.dart:220` (delete)
- `sleep_settings_card.dart:150` (clear)
- `sleep_sheet.dart:129` (the five stars, heard as "button" five times)
- `target_set_sheet.dart:262` (remove)
- `album_sheet.dart:278`, `:282` (− / +)
- `timelapse_screen.dart:140` (play/pause)
- the memory grid tiles, `album_screen.dart:225`

### U3-17 · Low — Targets under 48 dp

- The set tick is 44 dp wide (`set_row.dart:236-238`), on the
  one-handed, sweating screen.
- The clock/pause chip is about 36 dp tall (`session_screen.dart:351`).
- The compare thumbnails are 44 dp (`compare_screen.dart:141`).
- The compact folder "more" button (`notes_sidebar.dart:321`).

### U3-18 · Low — Units, numbers and the open-set badge

- **Hard-coded unit text:**
  - `Text('kg')` / `Text('lb')` (`weight_sheet.dart:109-110`)
  - `suffixText: 'cm'` (`health_screen.dart:348`)
  - `WeightUnit.suffix`
- **Two badges for one open set:** `'P'` in the program sheet
  (`target_set_sheet.dart:253`) and `1+` in the session
  (`set_row.dart:200`). [[Checkpoint-7]] changed only one of them.
- **A 24-hour clock:** `clockLabel` in the sleep sheet is always
  24 h, while sleep settings use the locale's `TimeOfDay.format`.
- **Unformatted numbers:** loads and weights use `toStringAsFixed`
  rather than `NumberFormat` (`weight_text.dart:16-21`, five places in
  `health_screen.dart`).

### U3-19 · Low — Raw doubles in lb fields, and a weight re-rounded by a note

- `target_set_sheet.dart:294` and `training_max_sheet.dart:117` put
  `unit.from(g).toString()` in the field, which gives
  `220.46226218487757` (rule Y8).
- `weight_sheet.dart:75-77`:
  - editing only the note re-saves the weight rounded to 0.1;
  - `_save` has no `try`, so a failure leaves the button spinning.

### U3-20 · Low — `ref` after an await, and left/right in a directional app

- **`ref` after an await, with no mount check:**
  - `daily_cycle_card.dart:44-51`: its `!context.mounted` branch
    calls `ref.read`, which is exactly what throws.
  - `sleep_settings_card.dart:183-193`
  - `notes_sidebar.dart:91`
- **Asymmetric `fromLTRB` or `Positioned(left:)`:**
  - `rest_timer.dart:102`
  - `session_screen.dart:327`
  - `gallery_screen.dart:207`
  - `notes_sidebar.dart:119`
  - `timelapse_screen.dart:102-103`

  The timelapse speed row (label and four chips in a `Row`) probably
  overflows at 360 dp.
- **An empty-state flash:** while a note loads, the Notes screen
  shows the "No notes" empty state for a frame
  (`notes_screen.dart:284`).

**Checked and fine.** The English and Arabic ARB files have identical
key sets. Every controller, focus node, tab controller, animation
controller and timer in these features is disposed. Every other sheet
goes through `showHarvestSheet`. The Arabic compare labels follow the
flipped row correctly.

---

## C. Security and platform

**Verified and unchanged from [[Audit-v2-Beta]]:**
- **The importer:** `GalleryStorage.isSafeRelative` still decides
  every stored path (`import_service.dart:344`), and it rejects `..`,
  absolute paths, backslashes, drive colons and non-normalised
  paths. The settings allow-list is applied on import.
- **The widget:** it hides money while the lock is armed.
- **Media:** only images under 20 MB are written.
- **The manifest:**
  - backup is off in every domain;
  - there is no cleartext traffic;
  - the only exported components are `MainActivity` and the guarded
    permission-usage alias;
  - every permission is used, and `READ_HEALTH_DATA_IN_BACKGROUND` is
    what the 3 AM job needs.
- **The `harvest_steps` plugin:**
  - every reply path clears the pending result before replying, so
    there are no double replies;
  - its request codes (4101, 4102) collide with no other plugin's;
  - with no activity it answers `noActivity` instead of hanging;
  - R8 needs no extra rules for it or for Health Connect.
- **The repo:** no keystore, no `key.properties`, and the Kotlin
  daemon's stray file is gone.

### S3-01 · Medium — The archive's size limits trust the archive

`lib/features/import/domain/archive_reader.dart:113-130`

`ArchiveLimits` checks `entry.size`, which is the uncompressed size
*the zip's own directory declares*. Then `entry.content` inflates it.
In archive 3.6.1 the native `inflateBuffer` path has no cap at all,
and the Dart path uses the declared size only as a starting buffer.
A crafted zip that declares 1 KB per entry and inflates to gigabytes
passes every check and takes the app down during import. The S2-02
fix is right against an honest large archive, and does nothing
against a dishonest one. It still needs me to pick the file.

**Fix.** Count the inflated bytes as they arrive, and stop at
`limit + 1`. At the very least, check `content.length` against the
per-entry limit and the running total after each entry. Also check
`picked.size` before `readAsBytes` (`archive_picker.dart:31`).

### S3-02 · Low — Health Connect's "why?" link opens the home screen

`android/app/src/main/AndroidManifest.xml:81-96`

The rationale intent filter and the permission-usage alias are
declared correctly, but nothing handles them: tapping *Why does
Harvest need this?* in Health Connect opens the field. The platform
expects a page that explains the permission and links a privacy
policy. Play will require it (along with a declaration for the
background permission) the day the app goes there. Sideloaded, it is
only rude.

**Fix.** `MainActivity` routes those two actions to a short page
built from [[Health]] H2.

### S3-03 · Low — A failed Health Connect read is an uncaught error

`lib/features/health/data/steps_source.dart:134-149`,
`health_providers.dart:139-141`

`readTotals` answers `error("read", …)` for anything other than a
`SecurityException`, for example a rate limit, a remote exception, or
Health Connect mid-update. `ChannelStepsSource` catches nothing, and
the pull runs `unawaited`, so the `PlatformException` becomes an
uncaught async error and the card keeps stale data. Separately,
`"unavailable"` from a read is mapped to `StepsDenied`, and the card
asks for a permission it already has.

**Fix.** Catch `PlatformException` in `totals` and `counter` and map
it to an outcome. Map `"unavailable"` explicitly.

### S3-04 · Low — Thirty Health Connect calls per pull

`HarvestStepsPlugin.kt:268-279`

It makes one `aggregate` IPC per window, and it pulls on every
resume, every Health screen visit and at 3 AM. Health Connect
rate-limits reads, and more tightly in the background.

**Fix.** One `aggregateGroupByPeriod` over local 03:00 → 03:00 with
`Period.ofDays(1)`. That also gets DST days right for free.

### S3-05 · Low — The export writes the app's bookkeeping

`lib/features/export/data/export_repository.dart:44`, `:253-255`,
`settings_repository.dart:18-22`

The comment says `records.*` is "bookkeeping, never exported". The
export writes every `kv_settings` row anyway: `security.appLock`,
notification-id lists, `pomodoro.active`, `streak.lastJudgedDay`,
`records.note`. The importer filters these out correctly, so nothing
comes back in. It is just noise in a file I might hand someone.

**Fix.** Filter the export with `isImportableSetting`.

### S3-06 · Low — An imported stride is not checked

`health_providers.dart:101`

`health.strideCm` comes in through the `health.` prefix, and the
reader only runs `int.tryParse`. A stride of `0`, `-40` or `99999`
gives nonsense distances.

**Fix.** Clamp on read (30–150 cm).

### S3-07 · Low — The widget still stores money while locked

`lib/features/widget/domain/widget_service.dart:153-169`

It is not shown, but it is still written: `spent` and `wallet` land
in `HomeWidgetPreferences.xml` in plaintext while the lock is armed.

**Fix.** Write empty strings when locked. The rest of the exposure
is S2-05, which stays under S-04.

### S3-08 · Low — Release signing falls back to the debug key

`android/app/build.gradle.kts:58-63`

With no `key.properties`, a release build is signed with the debug
key and prints only a warning. That is exactly how the first four
releases went out.

**Fix.** Fail the release build instead of warning.

### S3-09 · Info — The plugin's loose ends

`HarvestStepsPlugin.kt:70`, `:95-98`, `:115-120`

- The coroutine scope is never cancelled on detach from the engine.
- A pending permission result is not failed on a true (non-config)
  detach.

Neither is reachable with the app's single, uncached engine. They are
worth two lines each before anything else embeds the plugin.

---

## D. Code quality

### Q3-01 · Medium — The outbox is not "every write" yet

[[Local-Database]], [[Sync-Strategy]] and [[ADR-005-Local-First-Sync]]
all promise that every local write appends to the outbox. These
writers never call `logChange`:
- the **ledger**, from every service that pays XP or coins, which
  [[Sync-Strategy]] says syncs;
- `step_days`;
- `pomodoro_sessions`;
- `kv_settings`;
- everything the importer writes.

The outbox is also never pruned, although ADR-005 says it is capped.
Q2-03 closed the gym. This is the rest, and it is cheaper now than
in Phase 6.

**Fix.**
- `logChange` in the ledger writes (one helper, since every service
  inserts the same shape) and in the other three tables.
- The importer logs what it wrote.
- A prune of acknowledged rows, or a cap, once there is anything to
  acknowledge. Until then, say so in the ADR.

### Q3-02 · Low — `expense_categories` is not in the archive

`lib/features/export/domain/harvest_workbook.dart:51-83`

Business rule #11 says no table may be missing from the export. Custom
categories (their names and icons) have no sheet, and the importer
never writes them. A restored phone shows the expenses under keys
it has no category for. B-02 was this same shape, in the same file.

**Fix.** A `Categories` sheet and an importer descriptor, merged by
key. `_Table` makes it one entry.

### Q3-03 · Low — Where the tests are thin, again

580 tests, and none that would have caught:
- U3-01 (dispose with a pending save);
- U3-02 (open, focus, blur, rate unchanged);
- B3-01 (the ended day's total after a pull beat the job);
- B3-02 (a goal older than yesterday);
- B3-03 (Y11 after Y12);
- B3-05 (the movement's day after a move).

The screens have almost no widget tests: notes, gallery, health and
the gym are tested through their repositories only.

### Q3-04 · Low — Remaining debts from audit 1

These are all still open, and still cosmetic:
- **Q-39:** `pomodoro_service` imports settings/data; `check_in_service`
  and `streak_service` import each other; `core/platform` has ten
  imports from features.
- **F-25:** four copies of the currency `SegmentedButton`.
- **F-26:** `StatTileRow` used only by Stats.
- **F-29:** three copies of the pot hero in `vault_tab.dart`.
- **F-36:** `vault_tab.dart` is 960 lines; `_BudgetSheet` still lives
  in `granary_screen.dart`.

---

## E. Promised, not built

These are places where a spec describes a behaviour the screens do
not have. None of them is a bug. Each one needs a decision: build it,
or strike it from the spec.

| # | Spec | What it promises | What exists |
| :-- | :--- | :--- | :--- |
| P3-01 | [[Gym]] | The rest timer runs "over the app and through the lock screen" | An in-app `Timer` (`rest_timer.dart:33-47`) |
| P3-02 | [[Gym]] | Discarding a session asks twice | It asks once (`session_screen.dart:287`) |
| P3-03 | [[Gym]] | Drop a set | `removeSet` exists (`sessions_repository.dart:486`); no screen calls it |
| P3-04 | [[Gym]] | Skip, "with the reason kept" | The toggle never asks for a reason |
| P3-05 | [[Gym]] | Exercise history shows the three PRs and a 1RM/volume chart | Heaviest and estimated only; best volume is computed (`session.dart:190`) and never shown |
| P3-06 | [[Notes]] | An unwritten `[[link]]` is shown differently | All links look the same; `outgoingLinks` is unused |
| P3-07 | [[Gallery]] | The album card shows the album's own streak | Only the schedule (`album_crop_tile.dart:37`) |
| P3-08 | [[Gym]] / [[Gallery]] | A gym-bound album has no schedule of its own ("an accounting error") | `album_sheet.dart` lets me give it one: two cards for one session |
| P3-09 | [[Dashboard-and-Widgets]] | A sleep-debt gauge on the field header | Budget only (`field_screen.dart:172-233`) |

---

## F. Spec drift

Each row below is a place where the doc says one thing and v2.0.0
does another. Every row was checked against the code.

| # | Where | Says | Is |
| :-- | :--- | :--- | :--- |
| D3-01 | [[Business-Rules]] #8, [[Local-Database]] "the one hard delete", [[ADR-005-Local-First-Sync]] | Nothing else hard-deletes; deletes are soft everywhere | Notes (empty trash, links), gallery, program days/slots/sets, session sets, seed notes all hard-delete. Mostly on purpose; the rule should say which |
| D3-02 | [[Local-Database]] | Purge covers commitments, finances, vault; a `budgets` table; `settings`; outbox `tableName` | Notes purge only through *empty trash*; the budget is a setting (`finance.monthlyBudgetMinor`); `kv_settings`; `target_table` |
| D3-03 | [[Business-Rules]] #13 | The outbound calls are "an export I tap" and exercise media | Exercise media and the exchange-rate fetch (`api.frankfurter.dev`); an export is not a network call |
| D3-04 | [[Business-Rules]] 3 AM diagram, [[Notifications-and-Background]] | Generate four quests, recompute budget; `BGTaskScheduler` on iOS; `android_alarm_manager_plus` | Reconcile, close steps, plan, refresh widget; nothing in `ios/`; the package is not a dependency |
| D3-05 | [[Business-Rules]] #9 | Each ritual is suppressed once its reason is gone | Morning and evening plan always fire; `reevaluate` cancels only streak-risk and expenses |
| D3-06 | [[Notifications]] | Prime-time learning; morning suppressed if the app was opened; evening = bedtime −45; every time adjustable; every reminder alarm-grade | None of the first; evening is a fixed 21:30 default; the 11 PM check has no setting; streak-risk is `alarm: false` |
| D3-07 | [[Onboarding]] | Fix Sleep / Save Money templates, a language-and-theme step, a first check-in demo | Welcome · Templates (read, fit, language, meditate, journal) · Goal · Reminders · Extras (notes, gallery, health, gym) |
| D3-08 | [[Finances]] | "Multi-currency is out of scope for V1" (line 86, against its own line 27); budget quests | Three currencies; quests parked |
| D3-09 | [[Localization]] | Numerals follow the locale | Money is always Western digits (`money.dart:23`), as [[Finances]] says |
| D3-10 | [[Health]] | Weight windows 30 / 90 / all; money rule cited as #3 | 30 / 90 / 365; #3 is sleep debt |
| D3-11 | [[Dashboard-and-Widgets]] | A segmented switch at the bottom of paired screens; "(Phase 3+)", "(Phase 4+)" | Top tabs (`PairedScreen`, Notes N6) |
| D3-12 | [[Core-Entities]] | "Six entities"; steps summed from the sensor | Vault entities missing; Health Connect first (H2) |
| D3-13 | [[Architecture-Overview]] | `health/ # Phase 3`, `screentime/ # Phase 4`, a `GamificationService`, the quest generator | Eight feature folders missing from the tree; no `screentime/`; `StreakService`; quests parked |
| D3-14 | Sync is "Phase 5" | [[Sync-Strategy]], [[ADR-002-Local-Database]], [[ADR-005-Local-First-Sync]], [[ADR-006-Export-Format]], [[Architecture-Overview]], README | Phase 6 since screen time moved ahead; [[Sync-Strategy]] still calls the export one `.xlsx` |
| D3-15 | Old phase numbers and parked quests | [[Screen-Time]] "Phase 4 module", [[Pomodoro]], [[Notifications]], [[Productivity-Engine]], [[Phase-7-Screen-Time]] ("screen-time quests"), [[Home]] ("coins, quests"), [[Product-Requirements]] ("next comes notes") | Screen time is Phase 5; quests are parked; v1.1 and v2.0 shipped |
| D3-16 | README | Project layout without `body`, `farmer`, `gallery`, `gym`, `health`, `import`, `notes`, `records`; `drift_schemas` "v1 … v9"; Phase 4 row unticked | Eight more features; v14; shipped |

**Written nowhere:** the coin amounts. Milestones pay
`{7: 50, 30: 200, 100: 1000}`, and a freeze costs 100
(`streak_service.dart:18-22`). They appear only in the first UX
audit. They belong in [[Gamification]].

**Checked and matching:** every XP amount, 1,000 XP a rank, the 2×
over-log cap, the 3 AM boundary, fourteen calendar nights of sleep
debt, the 75 cm stride, the 30-minute wind-down, 0.25 kg rounding,
the 20 kg bar, Epley, Y12, two freezes at most, and the notification
id ranges. The schema is v14 in code and docs, with a snapshot and a
generated migration test for every version. No wiki-link in the vault
is broken.

---

## The deferred list

| Item | From | State on v2.0.0 |
| :--- | :--- | :--- |
| S-04 SQLCipher | Audit 1 | Open. No cipher dependency, no key |
| S2-05 plaintext beside the database | Audit 2 | Open, under S-04; S3-07 narrows it |
| S2-06 media integrity | Audit 2 | Open. Pinned commit, size and type checked, no hash |
| Q-13 deep history | Audit 1 | Partly. Idle spans are one pass; busy spans are still a per-day loop |
| Q-44 SQL aggregates | Audit 1 | Open. Totals, logged-on, done-this-week and daily activity sum rows in Dart |
| Q-39, F-25, F-26, F-29, F-36 | Audit 1 | Open; see Q3-04 |
| B-10 morning ritual leans on the 3 AM job | Audit 2 | Accepted in rule #9 |
| B-11 the cap of four | Audit 2 | Answered by rule #9 |
| N-08 hand-ticked gym seed | Audit 2 | Closed by Y12 in [[Checkpoint-7]], with B3-03 and B3-04 as its loose ends |
| N-09 steps XP never taken back | Audit 2 | Closed as a decision |
| S2-09 path to `StepsChannel.kt` | Audit 2 | Stale: now `packages/harvest_steps/.../HarvestStepsPlugin.kt`; the comment at `steps_source.dart:97` says the old name too |

---

## Remediation, in the order I would take it

1. **What loses what I typed**: U3-01, U3-02, U3-03, U3-09, U3-20
   (`ref` after unmount). Each is one pattern: take what `dispose`
   and the post-await code need *before* the widget can go away. Each
   lands with a widget test.
2. **Steps**: B3-01, B3-02, B3-06, B3-08, S3-03, S3-04. Guard the
   close, pay the whole window, un-freeze the windows, make the
   payment once for real, catch read errors, and use one grouped
   read.
3. **The gym and the money seams**: B3-03, B3-04, B3-05, B3-07,
   B3-10, U3-14, U3-15.
4. **The importer and the archive**: S3-01, Q3-02, S3-05, S3-06.
5. **Pictures and performance**: U3-04, U3-05, U3-06, U3-07, U3-08.
6. **Arabic, layout, accessibility**: U3-10 … U3-13, U3-16 … U3-19.
7. **The docs**: D3-01 … D3-16, the coin amounts, and a line on each
   of P3-01 … P3-09 saying *built* or *struck*.
8. **Before Phase 6**: Q3-01 (the outbox), S3-08 (fail unsigned
   releases), S3-02 (the rationale page).

Related: [[Audit-Home]] · [[Audit-v2-Beta]] · [[Checkpoint-7]] · [[Checkpoint-8]]

## Status — waves 1 and 2 remediated 2026-09-19

| Wave | Findings | What landed |
| :--- | :--- | :--- |
| 1 · what loses what I typed | U3-01 · U3-02 · U3-03 · U3-09 · U3-20 | **The note editor** takes its repository and the writing flag in `initState`, so `dispose` no longer touches `ref`. The pending save is written, and the flag is put down after the frame. **The rate card** fills on the first data and saves nothing before it. **The gym picture prompt** is asked from the navigator's context, which outlives the session route. **The field** keys the `Animate` wrapper and takes the editor before the completion dialog. **The daily-cycle card, the sleep override and the folder sheet** take what they need before their first await. Widget tests: `note_editor_test.dart` and `rates_card_test.dart`, both failing against the old code. |
| 2 · steps | B3-01 · B3-02 · B3-06 · B3-08 · S3-03 · S3-04 · S3-09 | **The sensor close** only writes to the ended day inside a three-hour window after 3 AM, and only if nothing has read the new day yet. Outside that, the ended day keeps what it had, so a late job, a DST shift or a morning open cannot count the same steps twice. **A pull** pays every unpaid day since the last one the ledger paid. **The step windows** move with `currentHarvestDayProvider`. **`_payOnce`** reads and writes in one transaction. **A failed Health Connect read** is a `failed` outcome that keeps the card as it was, and "unavailable" is no longer mistaken for a refusal. **The plugin** reads the thirty days in one `aggregateGroupByPeriod` (per-window reads remain as the fallback) and cancels its scope on detach. 586 tests. |

The job itself is still a periodic WorkManager task, and it still
drifts. With the window guard, drift can no longer corrupt a day: at
worst the close is skipped, and the evening's steps are written down
on the next open.

## Status — Q3-01, Q3-02 and S3-05, 2026-09-19

Taken on the way into [[Phase-5-Goals-Places-and-Voice]], because sync
reads the outbox and the archive had to carry the new tables anyway.

| Finding | What landed |
| :--- | :--- |
| Q3-01 · the outbox | Every ledger row goes through `HarvestDatabase.insertLedger`, which logs it. Step days, focus sessions (their blocks and endings too), preference settings, streaks and every row the importer writes now log a change. The outbox keeps its newest 50,000 rows (`capOutbox`), which is safe because a device's first sync sends a full snapshot. |
| Q3-02 · categories | A `Categories` sheet, exported and imported by key. |
| S3-05 · the settings sheet | Exports only what an import would accept. The allow-list moved to `core/db/portable_settings.dart` and is shared by the importer, the export and sync. |

Still open: the rest of waves 3–8. The report's order stands.

## Status — waves 3 to 6 remediated 2026-09-20

| Wave | Findings | What landed |
| :--- | :--- | :--- |
| 3 · the gym and the money seams | B3-03 · B3-04 · B3-05 · B3-07 · B3-10 · U3-14 · U3-15 | A bare session on the day up next moves *Up next* on; undoing a hand tick takes back only the session it created, and only while it is empty; a moved expense takes its wallet movement with it; a second **Start** resumes the session already running instead of beginning another. Tests: `audit3_wave3_test.dart`. |
| 4 · the importer and the archive | S3-01 · S3-06 | An archive is weighed as it opens — the file before it is read, then each entry's inflated size and the total — and a stride is clamped to a leg's length (30–150 cm) wherever it is set. |
| 5 · pictures and performance | U3-04 · U3-05 · U3-06 · U3-07 · U3-08 | **A picture is decoded at the size it is drawn**, from the layout rather than the caller, so a grid of thumbnails no longer walks past the image cache. **An exercise picture** resolves its file once per stem and kind instead of on every build, and the pickers no longer fetch. **The album viewer** watches its album, so a deletion inside it is seen. **The session clock** is its own widget with the only timer on the screen; ticking it no longer rebuilds every exercise card and set row. **The timelapse** resolves the album's files once, decodes three frames ahead and draws them through one gapless image, instead of building a view per frame that resolved, checked and decoded from scratch. |
| 6 · Arabic, layout, accessibility | U3-10 … U3-13 · U3-16 … U3-19 · U3-20 (the rest) | **The sidebar and the session bar** pad by start and end, and so do the rest timer and the album footer. **Deleting a folder** asks first and offers to undo, restoring the exact notes it trashed. **The steps card** wraps its count and distance rather than overflowing a 360 dp phone by 232 px, and its average says it is a daily one and leaves today out. **Units** come from the strings — kg, lb, cm, and their Arabic — and every number beside them goes through one formatter that groups thousands and drops the zero the scale never showed. **Fields** get a rounded number they can be parsed back from; a note added to an old weight no longer re-rounds it, and a save that fails says so. **The open set** is called 1+ in the program as it is in the session, and the sleep sheet follows the phone's clock. **Icon buttons** say what they do, memory tiles read as a photo or a video with their day, and the set tick, the clock chip, the compare thumbnails and the folder menu are 48 dp. |

Tests: 836 on the phone, with `weight_text_test.dart` and
`steps_card_test.dart` added against the old behaviour.

Still open: wave 7 (the docs) and wave 8 (S3-08, S3-02; Q3-01 is
already done).
