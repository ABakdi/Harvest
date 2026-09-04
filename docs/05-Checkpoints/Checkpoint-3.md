# Checkpoint 3 — Living with it

*Taken 2026-09-04, on the v0.9.5 tree.*

[[Checkpoint-2]] closed the two holes I could see from the outside: a
lock on the front door and a way to get my data out. This one comes
from the other direction entirely — a fortnight of actually using the
app, writing down every moment it annoyed me, and then reading the list
back.

Eleven things. They sort into three piles.

**The app forgets what I told it.** I write a note on a seed and the
card never mentions it again. I set a reminder and the card shows
nothing. I want to jot down the page I stopped on and there is exactly
one note field, which I would have to overwrite every single day.

**The app will not let me undo a mistake.** I cannot delete an expense
from the sheet I logged it in. I cannot delete a seed at all. I can
archive one, but archiving is a one-way door with no room behind it.

**The app is smaller than it should be.** A recurring habit has a
streak I can only see as a number. A new habit invents a history it
never had. The icon is a sprout in the middle of a lot of green, the
loading screen is a white flash, there is no widget, and if I stop
opening the app it says nothing at all — which for a streak app is the
one unforgivable bug.

## The eleven

| # | What was wrong | Where it landed |
| :- | :--- | :--- |
| C3-1 | Notes and reminders never reached the card | [[#C3-1 — What the card knows]] |
| C3-2 | A new recurring seed appeared in the calendar's past | [[#C3-2 — Nothing is due before it was planted]] |
| C3-3 | An expense could not be deleted from its own sheet | [[#C3-3 — Deleting an expense]] |
| C3-4 | Archiving was a one-way door with nothing behind it | [[#C3-4 — The archive, and why]] |
| C3-5 | A seed planted by mistake could not be removed | [[#C3-5 — Delete, and what it costs]] |
| C3-6 | A recurring seed's history was a number and nothing else | [[#C3-6 — A seed's own screen]] |
| C3-7 | One note per seed, forever | [[#C3-7 — A fresh note every day]] |
| C3-8 | Stop using the app and it goes quiet | [[#C3-8 — The comeback ladder]] |
| C3-9 | A small sprout floating in a lot of green | [[#C3-9 — An olive branch]] |
| C3-10 | The loading screen was a white flash | [[#C3-10 — A tree that grows]] |
| C3-11 | No home-screen widget | [[#C3-11 — The widget]] |

---

## C3-1 — What the card knows

### The ask

A seed's note should be on its card. If it has a *remind me at*, that
should be on the card too — and ticking down, not sitting there as a
time I have to subtract from the clock in my head.

### What it was

[[Productivity-Engine|The advanced options]] have carried a note since
checkpoint 1, and the card ignored it — except for to-dos, where the
note was used as a *substitute* for the subtitle, so writing a note
hid the planned day. The reminder time never reached the UI at all: it
went into the database, the planner read it, and the card said nothing.

### What it is now

`CropCard` grew three slots: the seed's standing note, today's note
(C3-7), and a chip row under the subtitle. The note lines are quiet and
capped at two lines — the card is a reminder of the note, not the note.
The to-do subtitle went back to saying what day it is planned for.

`ReminderCountdown` is the new chip, built the same way
`DeadlineCountdown` was: minutes and hours while the reminder is a way
off, `M:SS` in the last five minutes, "now" as it lands. It ticks once
a minute and switches to once a second only in that last stretch, so a
field full of cards is not a field full of per-second timers. Once the
seed is checked in the chip stops counting and goes grey with the plain
time on it — nothing is going to ring, and the card should not pretend
otherwise.

The formatter is pure and its unit suffixes are injected, so it is
unit-tested and it localizes.

## C3-2 — Nothing is due before it was planted

### The bug

Add a daily habit today, open the calendar, and there it is on the 1st,
the 2nd, the 3rd — every day of the month, including the ones that had
already happened. A history the seed never had.

### The cause

`isDueOn` in `commitments/domain/due.dart` is the one rule the field,
the calendar and the reminder planner all share ([[Audit-Home|audit]]
Q-17). It asked the schedule and nothing else. A schedule describes a
rhythm — "every Thursday" — and a rhythm has no beginning, so run it
over March and it will happily tell you the habit was due in March.

### The fix

A seed now has a **start day**: the Harvest Day it was planted,
derived from `createdAt`, so it costs no column and no migration and is
correct for every row already in the database. `isDueOn` refuses any
day before it, whatever the schedule says.

The same reasoning applied one level down. `StreakService._wasActiveOn`
decides which days a habit may be judged on, and it excused pauses and
archiving but not the days before the habit existed. It does now: a day
that ended before the seed was planted is not the seed's day. Nothing
observable changed there — a brand-new habit has a streak of zero and
the break path is guarded on `current > 0` — but the rule now reads the
same in both places, which is the point of having one rule.

Six cases in `start_day_test.dart` pin it, including the one that
started this: a weekly habit is not due on matching weekdays in the
past.

## C3-3 — Deleting an expense

Swipe-to-remove on the day's list has been there since round 4, and it
works. It was not what I reached for. I tap the row, the sheet opens,
I see the wrong amount, and there is no way out of the sheet except
saving it or cancelling it.

The sheet now carries a delete button beside its title, in the error
colour, only when it is editing something. It confirms first — with the
amount in the question so I can see what I am about to remove — then
closes, deletes, and offers Undo, exactly as the swipe does. Deleting
refunds the wallet movement the expense made, because `FinanceActions`
already owned that (audit F-02) and the sheet just calls it.

`HarvestSheet` grew a `trailing` slot for this. A destructive action
belongs by the title, as far as possible from the big confirm button at
the foot of the form.

## C3-4 — The archive, and why

The [[Audit-Home|audit]] already flagged this: "Barn wording is now
Archive everywhere, but there is still no screen listing archived
seeds. That is a feature, not a fix — noted for the backlog." It came
straight off the backlog.

Two parts.

**Archiving asks why.** The confirm dialog is now a sheet with a note
field. `commitments.archive_note` (schema v9) holds it. Six months from
now, a shelf of titles and dates tells me nothing; *"finished it, on to
the next one"* tells me everything, and it is the one thing the title
cannot say.

**There is a screen.** `/field/archive`, reachable from the field's app
bar, listing archived seeds newest first with the note, the date, and
two ways out: **Restore**, which puts the seed back on the field and
clears the note, and **Delete**, which is C3-5. Tapping the card opens
the seed's history (C3-6), because an archived seed's history is
exactly what an archive is for.

## C3-5 — Delete, and what it costs

### The ask

If I add something by mistake I should be able to remove it. Properly —
not archived, not hidden. And I should be asked first.

### The rule this breaks

[[Business-Rules]] #8 says history is append-only: *deleting a
commitment never deletes its check-in history; stats and streak math
stay truthful.* That rule is right, and it is why the ordinary way to
retire a seed is Archive, which keeps every row.

But it was written about **retiring** a seed, and a mis-typed one is a
different thing. A soft delete would be the worst of both: the row
keeps skewing stats for thirty days and then the purge removes it
anyway, so the same data is lost — just later, and less predictably.

So rule #8 gains one exception, written into the rule rather than left
as a hole: **a deliberate, confirmed delete removes the seed, its
check-ins, its notes and its streak.** The confirm dialog says so in as
many words and offers Archive as the alternative. There is no Undo, and
the dialog does not pretend there is.

Focus sessions are the one thing kept: `pomodoro_sessions` are detached
from the seed rather than deleted, because the time I spent is mine
whatever it was spent on.

## C3-6 — A seed's own screen

A recurring seed had a current streak and a best streak, both as
numbers on the stats screen, and that was the whole story. I wanted to
tap a habit and see the run behind it.

`/field/seed/:uuid` is that screen:

- the streak, the best, the days logged and the units or check-ins,
- an eight-week strip with a filled square for every day I showed up
  and an outline on today,
- and the timeline: every day the seed was watered *or* written about,
  newest first, with what I logged and what I wrote.

It is reachable from a crop's options, from a habit row in Stats, and
from an archived card.

One detail worth stating. The streak the screen shows is the stored one
when the engine has judged this seed, and otherwise the honest run of
consecutive days computed from the history itself. Projects and to-dos
have no streak row; the run is still true for them, and a screen that
showed a zero would be lying about a month of work.

## C3-7 — A fresh note every day

### The ask

If I am reading a book I want to note the page I stopped on, and next
time I want to see yesterday's note and carry on. Each day should get a
fresh note, not overwrite the last one.

### The shape

Schema v9 adds `seed_notes`: one row per seed per Harvest Day, with a
body, an outbox row like everything else, and a 500-character cap that
trims rather than refuses.

The sheet is the whole feature. It opens on today — blank, unless I
already wrote something today — with **the last note I wrote quoted
above it**, dated. That quote is the reason to open the sheet at all:
*Last time · Sep 3 — stopped on page 143*. Write today's, save, and
tomorrow the quote says 178.

Today's note also shows on the card (C3-1), on its own line with its
own icon, so the field itself can tell me where I left off. The whole
sequence is in the seed's timeline (C3-6), and every note is in the
export (rule #11).

It is deliberately *not* the same field as the seed's standing note.
That one says what the seed is; this one says where I am in it.

## C3-8 — The comeback ladder

### The ask

If someone installs the app and stops using it, the app should say
something. A rotation of messages: missed a day, missed a week, and so
on — so it does not just get forgotten.

### Why it matters more than it sounds

Every other reminder in this app fires because I asked it to. This is
the only one that fires because I *stopped* asking, and it is the one
case a streak app cannot afford to get wrong: an app that goes quiet
the moment you stop opening it has given up on the single thing it
does.

### The rungs

Six, escalating in tone from warm to plain, one message each — the
ladder *is* the rotation:

| Rung | Fires | Voice |
| :--- | :--- | :--- |
| 1 day | the morning after one missed day | *"Your field is waiting 🌱"* |
| 3 days | | *"Three days without water"* |
| 1 week | | *"A week away 🌾"* |
| 2 weeks | | *"Two weeks quiet"* |
| 1 month | | *"A month of fallow ground"* |
| 2 months | then every 30 days | *"Still here whenever you are"* |

A rung fires the morning **after** its run of missed days is complete,
so the one-day nudge lands two days after the last check-in: the day in
between was the one I missed, and the day before that I was still here.

Past the last rung the ladder does not stop — it settles into a monthly
heartbeat. Someone who put the phone down in March should still hear
from their field in June. Without that, every rung would be in the past
and the app would be silent forever, which is precisely the failure the
feature exists to prevent.

### The rules it has to obey

- **Anything counts as showing up.** A check-in or a logged expense
  resets the whole ladder. It is re-planned after every check-in, every
  expense, every app open and every 3 AM reset.
- **Never more than four a day** ([[Business-Rules]] #9). A comeback
  nudge speaks at the morning hour and says more than the morning
  ritual would, so on a day it fires it **replaces** the morning
  ritual rather than stacking on top of it.
- **It is a ritual, so the master switch governs it.** Turn reminders
  off and the ladder is silent — unlike a seed's own reminder, which is
  a time I asked for and always fires.
- **Not an alarm.** No full-screen intent, no alarm stream, no snooze
  actions. "We miss you" does not get to wake anybody up.
- **No shame** ([[Notifications]]). Every message says the history is
  safe and one check-in starts the next streak. None of them counts the
  days I lost.

An app installed and never opened at all still gets the ladder: with no
check-ins on record it counts from the day the first seed was planted.

## C3-9 — An olive branch

The old icon was a white sprout, small, in the middle of a green
gradient. Two problems: it was generic, and inside Android's adaptive
mask it took up about two thirds of the space it could have.

The new one is an olive branch — a stem, five leaves, three olives —
white on the same green. It is generated from an SVG whose geometry is
computed rather than drawn by hand, which mattered more than it sounds:
in a single-colour silhouette every white shape merges with every
other, so the olives have to hang far enough off the stem, and far
enough from each other, to stay three distinct olives at 48 dp. Getting
that right took spacing arithmetic, not taste.

It is fitted to the adaptive icon's safe circle automatically — the
generator grows the branch until it just touches the radius — so it is
as large as it can be without a leaf tip being cropped by a round mask.
The legacy and iOS icon is fitted to the square instead, so it is
larger again.

The SVG sources live in `assets/icon/` beside the PNGs they produce.

## C3-10 — A tree that grows

There was no loading screen. The Android launch window was white, and
the startup reconciliation sat behind a blank `Scaffold`.

Now: an **olive tree growing** on the brand gradient — trunk, then
branches, then leaves, then blossom, then the blossom becomes fruit.
About 1.7 seconds, drawn by a `CustomPainter`, no assets and no
animation library.

The tree is generated once from a fixed seed, so it is the same tree
every launch; only the progress moves. Two details earned their code:
each fork is pulled back toward vertical before it is spread, which is
what stops the third generation growing sideways and turning the tree
into a shrub; and the whole tree is scaled about its base to fit
whatever box it is painted in, so a random wobble can never push the
canopy off-screen.

The Android launch window is now the first green of that gradient in
both light and dark, so the app opens into its own colour instead of
flashing white first.

**It does not cause the wait.** The splash leaves when the tree has
finished *and* startup has landed. Startup is local and normally wins,
so what is usually being waited on is the animation — which is a
deliberate 1.7 seconds and not a wedged platform channel. The rule from
the audit still holds: the first frame is never gated on a platform
call. With the system's reduce-motion setting on, the tree is simply
there and the screen leaves immediately.

The splash wears the **brand** gradient, not the theme preset's. The
five presets recolour the app; they do not recolour Harvest. The icon,
the splash and the widget all wear the one green so the app looks like
itself before any of its settings have been read — `HarvestBrand` in
`core/ui/tokens.dart` is where that green lives now.

## C3-11 — The widget

Home-screen widgets were [[Phase-5-Sync-and-Social|Phase 5]], M5.3,
behind a sync server I have not written. Nothing about a widget needs
sync, so it came forward.

A compact widget: the streak as a big number, today's field as
`3/5 today`, the farmer rank underneath, on the brand gradient. Tapping
anywhere opens the app.

`WidgetService` computes what it shows **from the database**, using the
same `isDueOn` rule the field uses, because it has to be right when no
screen exists — at the 3 AM reset, or right after a check-in that
closed the app. It is refreshed at startup, after every check-in and
every seed edit, on resume, and by the 3 AM job.

`HomeWidgetGateway` is the platform edge, an interface with a fake in
`test/support` like every other one here — so what the widget says is
asserted in unit tests without a launcher.

---

## Decisions

- **The start day is derived, not stored.** `createdAt` already says
  when a seed was planted. A column would have needed a migration to
  backfill and a second source of truth to keep in step.
- **`seed_notes` is a table, not a JSON blob on the commitment.** It is
  a history, and every history in this app is rows: it queries by day,
  it exports as a sheet, and it merges by union when sync arrives.
- **Hard delete over soft delete, for seeds only.** A soft delete would
  keep a mistake in the stats for thirty days and then lose it anyway.
  See [[Business-Rules]] #8 and its one exception.
- **The comeback ladder replaces the morning ritual rather than adding
  to it.** Four notifications a day is a rule, not a target.
- **`home_widget` over a hand-written `AppWidgetProvider` channel.**
  Unlike the export's one-file MediaStore call, the widget needs a
  shared-preferences bridge readable from a broadcast receiver in
  another process — that is a real amount of Android to own, and the
  plugin already owns it correctly.
- **The splash is code, not Lottie.** One painter, no asset pipeline,
  and it respects reduce-motion for free.
- **Schema v9, not v10-and-a-second-migration.** One version carries
  both `commitments.archive_note` and `seed_notes`.

## What the code corrected

**The due rule was two rules.** Fixing the calendar meant fixing
`isDueOn`, and that immediately broke four tests — in the vacation-mode
and streak suites, not the calendar's. They were creating habits *now*
and then judging days in the past, which the new rule correctly
refuses. The tests were making an assumption the app never should
have: that a seed has always existed. `CommitmentsRepository.create`
grew an optional `createdAt` for them, in the same spirit as
`setPaused`'s `at` — the only two places where a test needs to say
*when*.

**The ladder can run out.** The first version scheduled every rung
whose day was still ahead. Written that way, an app installed in
January and opened in September schedules **nothing** — every rung is
in the past — which is the exact user the feature was for. The test
that caught it is the one called *an app installed and never used still
speaks up*. The monthly heartbeat is the fix.

**White shapes merge.** Three olives drawn at a sensible size on a
sensible stem became one white blob, twice, before it was obvious that
in a silhouette the *gaps* are the drawing. The spacing is arithmetic
now, not judgement, and the generator reports its own reach so I can
see it fits before I look at it.

## Done when

- [x] All eleven implemented
- [x] Analyzer clean, format clean on every touched file
- [x] Tests green — **225**, up from 180: 45 new cases across the start
      day (6), day notes (6), archive and delete (6), the comeback
      ladder (13), the reminder countdown (8) and the widget (7), plus
      a v8 → v9 migration path
- [x] Schema v9 dumped, generated and migration-tested from every
      earlier version
- [x] The export carries the new table and the new column (rule #11)
- [x] English and Arabic strings for all of it — 62 new keys in each
- [x] The APK builds, and the widget survives the manifest merge: the
      receiver, `harvest_widget_info.xml`, the layout and the gradient
      drawable are all in the packaged APK
- [x] Docs updated: this page, and the specs and rules the changes
      touched
- [x] Driven by hand on the emulator, all eleven — see below

One build warning, worth recording rather than burying: `home_widget`
and `workmanager_android` both apply the Kotlin Gradle Plugin, which a
future Flutter will refuse. It is a plugin-side migration, not
something this app can fix, and it does not affect this build.

## Verified on the emulator

Release build, fresh install, driven by hand from onboarding.

| # | What I did | What happened |
| :- | :--- | :--- |
| C3-9 | Looked at the launcher | The olive branch, filling the circular mask — stem, leaves and three separate olives, all legible at icon size |
| C3-10 | Cold start | Green window, then the tree growing on the gradient with *Harvest · Cultivate your day* under it, then the field |
| C3-1 | Planted a habit with a note and a 6 PM reminder | The card shows `🗒 Chapter 4 onwards` and `⏰ rings in 8h 50m`, counting down |
| C3-1 | Checked it in | The chip went grey and silent — a bell-with-slash and the plain `6:00 PM`. Nothing is going to ring, and the card stopped pretending |
| C3-2 | Opened the calendar | Aug 31, Sep 1–3 carry **no badge**; every day from today forward carries 2. Selecting Sep 2 says "Nothing planted for this day" |
| C3-7 | Notes → wrote "Stopped on page 61" | The sheet opened on *Note for Sep 4*, blank, with the explainer. The card grew a second note line under the first |
| C3-6 | Options → History | Streak 1 day on the gradient hero, best/days/check-ins, the eight-week strip with today outlined, and `Fri, Sep 4 · Checked in · Stopped on page 61` |
| C3-4 | Archived a project with "Reading the other one first" | The Archive screen shows it with the note and *Archived Sep 4*, and Restore / Delete |
| C3-5 | Deleted it from the archive | The dialog said what it costs and offered Archive instead; after confirming, "Removed", the archive empty, and the row **gone from `commitments`** — checked in the database, not just the screen |
| C3-3 | Logged DA450, tapped the row | The sheet is titled **Edit expense** and carries a red bin. It confirmed with the amount in the question, removed it, and offered Undo |
| C3-8 | Read the scheduled alarms off the device | The whole ladder, at the morning hour: `4100` Sep 6, `4101` Sep 8, `4102` Sep 12, `4103` Sep 19, `4104` Oct 5, `4105` Nov 4 — one, three, seven, fourteen, thirty and sixty days after the last check-in, plus one |
| C3-11 | Added the widget from the launcher's picker | `0 day streak · 1/2 today · Sprout` on the brand gradient — real numbers from the real database. Tapping it opened the app |
| C3-11 | Checked a seed in inside the app, went home | The placed widget had already gone from `1/2 today` to `2/2 today`. The refresh path works with the widget on screen and the app in the background |
| — | Exported the workbook and read the file | 12 sheets: `SeedNotes` is there with the note and its `Seed` lookup, and `Seeds` carries `ArchiveNote`. Rule #11 holds |
| — | Read `pragma user_version` on the device | **9**, with `seed_notes` created and `commitments.archive_note` present |

Three things the device corrected on the way through, all fixed and
rebuilt:

- The seed detail's hero card rendered its text in the page's navy
  instead of the card's white. `HeroCard` re-keys the text theme for
  its children, but `Theme.of(context)` inside the child closure
  resolves against the *page's* context, above that. A `Builder` fixes
  it, and the same trap is waiting for anyone who writes the next
  hero card.
- The splash tree was stranded at the foot of a tall box: the painter
  scales to `min(width, height)` and anchors at the bottom, so in
  portrait it left a third of the screen empty above it. It sits in a
  square `AspectRatio` now.
- Three leaves a twig merged into white stars. Two, spaced along the
  twig, read as leaves — the same lesson the icon's olives taught, one
  screen later.

## Everything that changed

| Area | Change |
| :--- | :--- |
| Dependencies | `home_widget ^0.9.4` added. Nothing removed. |
| Schema | **v9**: `commitments.archive_note`, and the `seed_notes` table (one note per seed per Harvest Day). |
| `core/domain` | `Commitment.startDay` and `archiveNote`; `isDueOn` gates on the start day. |
| `core/ui` | `HarvestBrand` (the one green, for icon, splash and widget); `ReminderCountdown`; `GrowingOliveTree`; `confirm()`; `CropCard` gained note, day-note and chip slots; `HarvestSheet` gained `trailing`. |
| `features/commitments` | `SeedNotesRepository` + `SeedNote`; `archive(note:)`, `restore`, `hardDelete`, `watchArchived`, `watchOne`, `watchHistory`; `seed_providers.dart`; the archive screen, the archive sheet, the seed detail screen, the day-note sheet; crop options rebuilt. |
| `features/planner` | `comeback.dart` (the ladder, pure); the planner schedules and cancels it, and suppresses the morning ritual on a rung day. |
| `features/widget` | New feature: `HomeWidgetGateway` + `HomeWidgetBridge`, `WidgetService`, the settings card. |
| `features/export` | `SeedNotes` sheet; `ArchiveNote` column on `Seeds`. |
| `app/` | `SplashScreen` above the router; the widget refreshed at startup and on resume. |
| Android | `HarvestWidgetProvider.kt`, the widget layout, its background drawable and its provider info; the receiver in the manifest; the launch window is brand green in both modes; regenerated launcher icons at every density. |
| `assets/icon/` | The olive branch, PNGs and the SVG sources that produce them. |
| Strings | 62 new keys in English and Arabic. |
| Tests | 180 → 225, plus `FakeHomeWidgetGateway` in `test/support`. |
