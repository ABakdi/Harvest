# Checkpoint 4 — Reading the numbers, and keeping my own hours

*Taken 2026-09-05, on the v0.9.6 tree.*

[[Checkpoint-3]] shipped eleven things and I installed the build and
lived with it. Four complaints came back, and they are not the same
kind of complaint.

Two are **things that look finished and are not**: a widget that moves
on its own and smears one task over the next, and an Insights page full
of charts that will not tell me a single number. Both are the same
mistake — a picture of the data instead of the data.

One is a **number that is on the screen twice and disagrees with
itself**: the flame says ten days, and the activity grid shows ten
squares of assorted greens that have nothing to do with the ten.

And one is a **new idea**, and the most interesting thing in this
checkpoint: the app has been quietly assuming everybody's day starts in
the morning.

## The four

| # | What was wrong | Where it landed |
| :- | :--- | :--- |
| C4-1 | The widget scrolled itself, and smeared | [[#C4-1 — Nothing moves unless I move it]] |
| C4-2 | Insights showed shapes, not amounts | [[#C4-2 — Numbers, ranges and the moves behind them]] |
| C4-3 | The activity grid did not show the streak | [[#C4-3 — Ten days, ten green squares]] |
| C4-5 | The day was assumed to start in the morning | [[#C4-5 — My hours, not the app's]] |

---

## C4-1 — Nothing moves unless I move it

### The complaint

*"In the widget the auto scrolling of tasks is broken, the current and
next get smashed into each other making it unreadable. There shouldn't
be any auto scrolling at all if it is possible to make it manual — the
user scrolls with their fingers, that's it."*

### What I had built, and why it was wrong

[[Checkpoint-3]]'s C3-11 ends with a flipper that turns its own pages,
and the reasoning there is sound as far as it goes: a widget cannot be
scrolled sideways, so if the cards are to move at all, something other
than a finger has to move them.

The conclusion was wrong anyway, and for a reason I should have seen on
the emulator instead of in a report. **A flipper draws the outgoing and
the incoming card at the same time.** For two hundred milliseconds
every four seconds, the strip is two titles overlapping. I looked at
mid-animation screenshots during C3-11 and read them as the animation
working; on a phone, in a pocket, glanced at, they are what the widget
mostly *is*.

And the premise was too narrow. I could not have sideways scrolling, so
I concluded I could not have scrolling. A `ListView` scrolls, is on the
allowlist, and takes a finger.

### What it is now

A **`ListView` of full-width cards**. Two fit; the rest are a flick
away. Nothing animates, nothing advances, nothing is drawn on top of
anything else. The direction is vertical because that is the only
direction a widget has ever offered — `RemoteViews` refuses to inflate
a `HorizontalScrollView`, and `ListView` and `GridView` are its only
scrolling collections.

The strip's height is fixed rather than weighted, which is a small
thing with a reason: the card around it is `wrap_content` so the widget
can still shrink when a section is switched off ([[Checkpoint-3]] again),
and a `layout_weight` inside a wrapping parent resolves to nothing at
all. The default placement went from three cells to three rows tall to
give the list somewhere to live.

Gone with it: the object animators, the position counter that only made
sense on a carousel, and the last of the machinery from four failed
attempts at moving sideways.

## C4-2 — Numbers, ranges and the moves behind them

### The complaint

*"The insight page graphs and plots should show numbers on the bars and
in parentheses in the percentage showing the exact amount of money.
Now it doesn't show me real numbers, just visual. Also I should be able
to see a custom range, after week and month. Also the insight page
should show me the moves of that range. And moves should be filterable
both in the balance page and insight page, by category and form of
transaction, and I can search in notes too."*

Four things, and they share a spine: the page had been showing me the
*shape* of my spending and making me guess at the substance.

### Numbers on the chart

Every bar now carries its amount above it, and every donut slice reads
`38% (DA4,500)` rather than `38%`.

The bars needed one judgement. Seven labels across a week fit; thirty-
one across a month are a smear. So a short range labels every bar, a
long one labels the peak — the number that is actually being looked
for — and **every bar answers for itself on a tap**, whatever the range.
Nothing is unreachable, and nothing is unreadable.

### One span instead of two

Week and month used to be two parallel sets of providers, which is why
there was no third option: adding one meant adding a third set.

`DayRange` is now a value — two Harvest Days and which kind it is — and
the charts, the totals, the average and the moves all read from that
one span. Week and month are constructors; **custom** is a date-range
picker, and the dates are spelled out under the segments whichever is
chosen, because a chart of an unlabelled range is a chart of nothing in
particular.

The average divides by **days elapsed, not days in the span**. A month
that is four days old is four days of spending.

### The moves that made the chart

The Insights page now ends with the movements the range actually
contains, in the Vault's own ledger rows. The chart says *what*; the
ledger says *which*, and they cannot disagree because they read the
same span.

That meant lifting `_Ledger` and `_TxnRow` out of the vault tab into a
shared `MovesLedger` / `MoveRow`. One list, one row, one set of words
for what each movement was.

### Narrowing it

`MoveFilter` is a value with three parts, and empty means everything —
a filter nobody set must never hide a row:

| Part | What it does |
| :--- | :--- |
| **Form** | Added or taken · transfer · expense · debt payment |
| **Category** | Any expense category, preset or custom. Only an expense carries one, so choosing a category narrows to expenses by construction rather than by accident |
| **Note** | Free text, matched against the note *and* the reference — so "Sam" finds the debt paid to Sam even though I never typed it |

They stack rather than compete. The bar is collapsed to a search field
and a toggle until it is wanted, and the toggle carries a count of what
is switched on, so a folded-away filter can never be silently hiding
rows. `Showing 4 of 37` sits under it, with a one-tap clear.

The same bar appears on the Vault's wallet and savings ledgers, and the
filter is held by the tab rather than the section: narrowing to "food"
and then switching pot should still be narrowed to food.

## C4-3 — Ten days, ten green squares

### The complaint

*"In the stats, the activity section should show the active streak days
in green — for example if I have a 10 day streak I should get 10 green
squares."*

### What was wrong

The grid was shading every day by how close it came to the Daily
Harvest Goal, which is a fine thing to show and *not the thing the
screen was being asked*. A ten-day streak looked like ten squares of
ten different greens, none of them meaning "streak", sitting under a
flame that says 10.

Two numbers, one visual language, and they disagreed.

### What it is now

The grid says two things and now says them differently:

- A day **in the current streak** is solid green. Ten days of streak,
  ten green squares — the number the flame is showing.
- A day that had activity but is not in the run keeps the faded
  gradient, capped well below solid so the two can never be confused.
- A quiet day is the same faint grey it always was.

A legend under the grid names all three, and the section subtitle says
it outright: *10 green squares are your streak.*

The streak's days come straight from the engine rather than being
guessed at from activity: it already stores `lastEarnedDay` and
`current`, and counting back from one by the other is the whole run —
**including days a freeze covered**, which are part of the streak
whether or not anything was logged on them. Deriving it from activity
instead would have quietly dropped exactly those days.

## C4-5 — My hours, not the app's

### The ask

*"I should be able to set up my sleeping time and waking up time
somewhere in the settings — to accommodate all kinds of people, and to
get rid of the excuse that I need to fix my sleep to do X. When the user
changes their sleeping and waking up time (always recommend 8h of sleep
and no less than 5), they get prompted in case some of their previously
set up goals and task reminders coincide with their sleeping time. If
they choose to auto adjust, the system shifts them to their waking
cycle using the logic: if a task happens X hours after waking up, when
the wake up time shifts, X remains the same — so the time of the task
changes to coincide with X after waking."*

### Why this is the good one

Every reminder in this app has been quietly assuming a shape of day.
The morning nudge defaults to 7 AM; the wind-down to 9:30 PM. For
someone who gets to bed at 5 those are not defaults, they are noise —
and the app's implicit answer has been *fix your sleep first*, which is
exactly the "I'll start on Monday" the whole thing exists to defeat.

So the app bends. **The daily cycle is a setting, and everything else
moves with it.**

### The night

Two times in Settings → Daily cycle, and a line under them that does
arithmetic out loud:

- **Eight hours is the target**, said plainly whenever the window is
  shorter.
- **Below five it warns**, in red, and does not refuse. A night shift is
  a fact, not a mistake for a dialog to correct — and an app whose rules
  forbid dark patterns ([[Business-Rules]] #7) does not get to lock a
  setting because it disapproves.

The window wraps midnight, and it does not have to: 3 AM to 11 AM is a
perfectly ordinary night and is measured as eight hours like any other.
The wake minute itself counts as morning — a reminder set for the moment
I get up is not one that wakes me.

### The shift

Changing either time finds every reminder the **new** night would
swallow — seeds and unsettled debts alike — and asks, by name:

> **Two reminders are now in your sleep**
> Move them with your new wake time? Each keeps the same distance from
> waking.
> Morning pages · 7:30 AM → 9:30 AM

The rule is exactly the one asked for, and it is one line: a reminder
keeps its offset from waking. Something I do two hours after getting up
stays two hours after getting up, whatever time that now is. Move the
wake time by two hours and every moved reminder moves by two hours,
wrapping around midnight rather than falling off the end of the day.

Only the clashing reminders move. Shifting a reminder that was not in
the way would be a surprise, and the ask is specifically about the ones
that *coincide with sleeping time*.

Nothing moves without a yes, and **Leave them** is a real answer.

## Decisions

- **The widget scrolls vertically or not at all.** Sideways is not on
  offer; a list that takes a finger beats a carousel that moves on its
  own and draws two cards at once.
- **`DayRange` is a value, not two code paths.** Week and month became
  constructors, and the custom range then cost nothing.
- **A long chart labels its peak and answers the rest on a tap.**
  Thirty-one labels is not more information, it is less.
- **`MoveFilter` empty means everything.** A filter is a way of asking
  a question, never a state the ledger can get stuck in — hence the
  count on the collapsed toggle.
- **The streak's days come from the streak, not from activity.** Freeze
  days are part of the run and would otherwise vanish from the grid.
- **The sleep floor warns, it does not block.** The app does not get to
  refuse a night shift.
- **Only clashing reminders shift.** Preserving the offset is the rule
  for what to do *with* them, not a licence to move everything.

## Done when

- [x] All four implemented
- [x] Analyzer clean, format clean on every touched file
- [x] Tests green — **260**, up from 232: 14 new on the daily cycle (the
      night, the wrap around midnight, the offset from waking, what a
      new night would swallow, and the shift itself) and 14 on the
      Insights span and the move filter
- [x] The release APK builds and installs
- [x] Docs updated: this page, and the [[Finances]], [[Gamification]],
      [[Notifications]] and [[Dashboard-and-Widgets]] specs
- [x] Driven by hand on the emulator — see below

The AVD fought this one. `screencap` returned a genuinely black
framebuffer and `SystemUI` held the notification shade focused whatever
it was sent; the emulator's own log named the cause —
*"Your GPU drivers may have a bug. Switching to software rendering."*
It took four restarts and a `-wipe-data` to clear, which is worth
recording only because I nearly shipped this checkpoint with the box
unticked and an honest paragraph instead of a pass.

## Verified on the emulator

Release build, fresh install, with a ten-day streak, a fortnight of
expenses and a handful of movements seeded into the database.

| # | What I did | What happened |
| :- | :--- | :--- |
| C4-3 | Opened Stats | *"10 green squares are your streak"* under the heading, and the grid ends in **exactly ten solid greens** — six in this week's column, four in last week's — over a legend reading Streak · Active · Quiet |
| C4-2 | Opened Insights on the week | `Aug 31 — Sep 6` spelled out; **DA980, DA2,500, DA640, DA320 written above their bars**; `Transport 64% (DA2,820)`, `Food 20% (DA900)`, `Shopping 16% (DA720)` beside the donut |
| C4-2 | Checked the average | `DA4,440` total, `DA740 / day` — divided by the **six days elapsed**, not the seven in the week |
| C4-2 | Switched to Custom and picked Aug 23 – Sep 5 | `DA8,930` over `DA637.85 / day` across fourteen days, and with more than ten bars only the peak is labelled — `DA2,950` — exactly as designed |
| C4-2 | Scrolled to the bottom of Insights | The range's own movements, grouped by day, in the Vault's ledger rows |
| C4-2 | Typed "Sam" into the search | **6 movements → 2**: the debt payment *to* Sam, matched on its reference, and *Coffee with Sam*, matched on its note |
| C4-2 | Opened the filter panel | Form chips (added or taken · transfer · expense · debt payment), every category chip, `2 of 6` and a **Clear**, with a `1` badge on the collapsed toggle |
| C4-5 | Settings → Daily cycle | *"The app bends to your hours, not the other way round"* — bedtime 11:00 PM, wake 7:00 AM, and *8 hours of sleep — that's the target* |
| C4-5 | Moved the wake time to 9 AM, with reminders at 7:30 AM and 6 PM | **One reminder is now in your sleep** · *Read Atomic Habits · 7:30 AM → 9:30 AM* · Leave them / Move them. The 6 PM one was not listed, because it does not fall in the new night |
| C4-5 | Tapped Move them | The database says `09:30` for that seed and `18:00` for the other — the offset from waking held, and nothing else was touched |
| C4-5 | Set a three-hour night | *"3 hours is less than anyone should run on. Eight is the target, five the floor."* in red, and the setting was accepted |
| C4-1 | Placed the widget and left it alone for nine seconds | **Zero pixels changed.** Nothing moves on its own any more |
| C4-1 | Swiped once inside the strip | *Spanish* gave way to *Read a book (300 pages)* — full-width cards, scrolled by a finger |

## Everything that changed

| Area | Change |
| :--- | :--- |
| Schema | **None.** All four are screens, settings and a widget layout. |
| `features/finances/domain` | `DayRange` (week / month / any two days, with elapsed-day arithmetic); `MoveFilter` (form, category, note search). |
| `features/finances/data` | `watchRange` on expenses and `watchTxnsBetween` on the vault — both ends included. |
| `features/finances/presentation` | Insights rebuilt on one span, with amounts on the bars, a tap tooltip, amounts beside the donut's percentages, a date-range picker, and the range's own ledger; `MoveFilterBar` and the extracted `MovesLedger` / `MoveRow`, used by Insights and by both vault pots. |
| `features/gamification` | `watchLastEarnedDay`, and `streakDaysProvider` — the run the flame is counting. |
| `features/stats` | The activity grid separates streak days from merely-active ones, with a legend and a subtitle that says the number. |
| `features/settings` | `DailyCycle` (pure: the night, whether a time falls in it, and the shift that keeps a reminder's distance from waking); `DailyCycleService` (read, write, find clashes, move them); `DailyCycleCard`. |
| `commitments` / `vault` repositories | `setRemindAt` and `setDebtRemindAt` — narrow writes, so moving a reminder does not rewrite a row. |
| Android | The widget's task strip is a `ListView` again; the flipper, its animators and the step controls are gone. |
| Strings | New keys in English and Arabic for the filter bar, the ranges, the legend and the daily cycle. |
