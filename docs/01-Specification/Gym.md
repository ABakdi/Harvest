# Gym

Phase 4 module ([[Phase-4-Health-and-Gym]]). The training half of
[[Health]]: a program I write, a session I run, and a record of what I
actually lifted.

## Why it belongs here

Every other seed in this app is checked with a tap, because "did I do
it?" is the only question worth asking of a habit. Training is the one
place where that is not enough. *Did I go* is table stakes; **what I
lifted, and whether it is more than last time** is the entire point,
and a tick cannot hold it.

So the gym gets its own machinery — and then hands the result back to
the field, where "I went" is still one check-in like everything else.

## What it is, and firmly is not

**Is:** a program of exercises with targets, a session screen fast
enough to use between sets with cold hands, and a history that answers
"what did I do last time, and what is my best?"

**Is not:** a coach. No plan generation, no AI form check, no calorie
counting, no macro tracking, no social feed, no video upload. It does
not tell me what to train. It remembers what I trained.

The bar: **could I have kept this in a paper notebook?** If yes, the
app should do it faster. If no — if it only exists to look like a
serious fitness product — it is out.

## Off by default

Like [[Notes]] and [[Gallery]], the gym is **not on** until I say so.
Onboarding asks once, Settings has the switch forever after. Someone
who came for a streak tracker should never walk past a barbell.

---

## The catalogue

1,324 exercises come from an open dataset — names, body part,
equipment, target and secondary muscles, step-by-step instructions, a
thumbnail and an animated demonstration ([[ADR-008-Exercise-Catalogue]]).

- **Read-only reference data.** It is not my data. It never syncs, it
  never exports, and the archive does not carry it — an export carries
  *which* exercise by id, not the exercise itself.
- **Searchable by name, body part, equipment and muscle**, because
  that is how I actually look for a substitute mid-session.
- **My own exercises** sit beside it. Anything the catalogue is missing
  I can add by name, and it behaves identically everywhere else.

## Programs

A **program** is what I follow: *nSuns 5/3/1*, *Push Pull Legs*,
*Upper/Lower*. It is a list of **days**, and a day is a list of
**exercise slots**, and a slot is a list of **target sets**.

| Thing | What it is |
| :--- | :--- |
| **Program** | A named routine, optionally cycling over N weeks |
| **Day** | One session's worth: *Week 1 · Day 4*, or just *Push* |
| **Slot** | One exercise in a day, in order, with its targets and rest |
| **Target set** | What I am *meant* to do: reps, and a weight or a % |
| **Bar** | What the bar itself weighs — per exercise, 20 kg unless changed |

A target set says one of three things:

- **A weight and reps** — `100 kg × 5`.
- **A percentage of a training max** — `75% × 5`, resolved to a weight
  when the session starts. This is what makes a percentage program like
  5/3/1 usable at all, and it is why a program carries a **training
  max per exercise** that I set and bump.

  Resolved weights are **rounded to the nearest 0.25 kg**. `75%` of a
  111 kg training max is `83.25`, not `83.25000000000001`, and not a
  number nobody can load.
- **An open set** — `1+`, `AMRAP`: as many as I can. The screenshot
  case, marked so it is obvious which set is the one that matters.

A day may carry **recommended accessories** — a note, not a
prescription: *"Back, Abs"*. It is text, and the app does not police it.

**Programs are mine to write.** No generator. Making one is a list I
fill in, duplicating a day is one tap, and reordering is a drag.

## Sessions

Starting opens the **session screen**, which is the only screen in
this app designed to be used one-handed, sweating, in a hurry. Which
day is up is the day after the last one I finished, wrapping round at
the end (Y11); the start sheet leads with it and lists the rest under
it for the day I mean to skip.

```
┌──────────────────────────────────────────┐
│  Rest   Plates            ▶ 00:09  Finish│
├──────────────────────────────────────────┤
│  nSuns 5/3/1                             │
│  Week 1 · Day 4                          │
│  Recommended: Back, Abs                  │
│  ✎ notes for this session                │
├──────────────────────────────────────────┤
│  1  Deadlift (Barbell)              ⏱    │
│                                          │
│  Set   Target        kg     Reps    ✓    │
│   1    75% × 5      [ 85 ] [  5 ]  ( )   │
│   2    85% × 3      [ 95 ] [  3 ]  ( )   │
│   P    95% × 1+     [105 ] [ 1+ ]  ( )   │
│   4    90% × 3      [100 ] [  3 ]  ( )   │
└──────────────────────────────────────────┘
```

**Every row is prefilled with the target**, so a set that went to plan
is one tap on the tick. A set that did not is two taps and a number.
That ratio is the whole design.

What a session can do while it is running:

- **Log a set** — weight and reps, ticked. The tick is what matters;
  the numbers are already there.
- **Add a set** the program did not ask for, or drop one.
- **Skip an exercise**, with the reason kept if I give one.
- **Replace an exercise on the fly** — the rack is taken, the machine
  is broken. The replacement is recorded as a replacement, so history
  knows the day was *meant* to be squats.
- **Rest timer.** Starts itself when a set is ticked, per-exercise
  duration from the program, and it counts down over the app and
  through the lock screen. Silence-able for one session without
  changing the program.
- **Plate calculator.** Given a target weight and a bar, what goes on
  each side. The bar is the exercise's own — **20 kg by default**,
  because that is right nearly always, and changeable because an EZ bar
  and a Smith machine are not. Two taps of arithmetic I should never do
  tired.
- **Notes** — one for the session, one per exercise.
- **Pause the clock.** A phone call or a queue for the rack is not
  training time; tapping the elapsed time stops it and tapping again
  starts it. Sets can still be ticked while paused.
- **Finish**, which writes everything — and asks first if un-skipped
  sets are still unticked, because Finish is the check-in (Y10) — or
  **discard**, which asks twice.

A session that is interrupted — the app is killed, the phone dies —
**resumes where it was**. A workout is thirty to ninety minutes of
data; losing it to a process kill is not acceptable, so every set is
written when it is ticked rather than at the end.

## Personal records

The reason for all of it.

A **PR** is tracked per exercise, and there are three worth keeping:

| PR | What it means |
| :--- | :--- |
| **Heaviest** | The most weight moved for at least one rep |
| **Best set** | The highest estimated 1RM from any single set |
| **Best volume** | The most weight × reps in one session |

Estimated 1RM uses **Epley** (`w × (1 + reps ÷ 30)`), and the app says
so rather than presenting it as a measurement. It is a comparison tool,
not a number to brag about.

When a set beats a record, the session says so **at the moment it is
ticked** — that is the feedback loop the whole feature exists to close.
Records are recomputed from the log, never stored as the only copy, so
deleting a bad entry corrects them.

Per exercise, history shows: what I did last time (always, on the
session screen), the three PRs, and a chart of estimated 1RM and volume
over time. The session screen also carries the record to beat under
*last time* — the heaviest set and the best estimated single — because
the number is wanted while loading the bar, not only after the set.

## The gym is a seed

A program binds to a **habit schedule** exactly like any other seed:
*Gym — 4 times a week*, or *Mon/Wed/Fri*.

- It appears on the field on the days it is due, with the day's name.
- **Finishing a session checks the habit in** — one check-in, +10 XP,
  the same Global Streak as everything else ([[Gamification]]). Going
  to the gym is one productive action, however heavy the day was.
- Starting a session and abandoning it checks nothing in. The tick
  belongs to Finish.
- It obeys every rule an ordinary seed obeys: the 3 AM day boundary,
  nothing due before it was planted, undo on the same day.
- **It can still be ticked by hand from the field**, and that is a
  decision, not an oversight ([[Audit-v2-Beta]] N-08): I train in gyms
  where the phone stays in the locker. A hand tick checks the habit in
  like any habit and logs no session, so it earns the day and moves
  the streak but leaves no sets, no records and no *Next* — the
  program's pointer follows finished sessions only. If that turns out
  to be a hole I fall through, the fix is a bare "went, no numbers"
  session behind the tick, not taking the tick away.

**A times-per-week gym habit works the way a flexible habit already
does** — four sessions a week, on whichever days I manage them, and it
stops asking once the fourth is done.

## The gym is an album

Training is the thing the [[Gallery]] was built for, so the two are
wired together rather than left to sit beside each other.

- Creating a gym habit **offers to create an album with it** — one
  suggestion, dismissible, not a requirement.
- The album is an ordinary album. It shows in the Gallery, it plays as
  a timelapse, it exports with the rest.
- Because a scheduled album is itself a seed, an album bound to a gym
  habit is **not** scheduled separately — the gym habit is the seed,
  and the album rides on it. Two cards on the field for one gym session
  would be an accounting error, not a feature.

**The picture prompt** is a preference with three settings:

| Setting | When |
| :--- | :--- |
| **After** (default) | On Finish — the session is done, the pump is real |
| **Before** | When the session starts |
| **Never** | No prompt; the album is still there to add to by hand |

The prompt is a card in the session flow, not a notification, and
skipping it costs nothing.

## Rules

| # | Rule |
| :-- | :--- |
| Y1 | The gym is off until switched on, and switching it off hides it without deleting a session. |
| Y2 | The catalogue is reference data: read-only, never synced, never exported. A log refers to an exercise by id. |
| Y3 | A set is written when it is ticked, not when the session ends. An interrupted workout resumes. |
| Y4 | Finishing a session checks the gym habit in — once, like any other seed. Starting one checks nothing in. |
| Y5 | Records are derived from the log and recomputed, never the only copy of a number. |
| Y6 | Estimated 1RM is labelled as an estimate wherever it appears, with the formula named. |
| Y7 | A replaced or skipped exercise is recorded as such. History must be able to say what the day was meant to be. |
| Y8 | Weights round to 0.25 kg. A number nobody can load onto a bar is a bug. |
| Y9 | The bar weight and the plate calculator belong to exercises that have a bar. A dumbbell asks no such question ([[Checkpoint-6]]). |
| Y10 | Finish asks before leaving un-skipped sets behind, because Finish is what checks the habit in ([[Checkpoint-6]]). |
| Y11 | A program's days go round: the day after the last one finished is up next, wrapping at the end, and any other day is one deliberate tap further ([[Checkpoint-6]]). |

Related: [[Health]] · [[Gallery]] · [[Gamification]] · [[Productivity-Engine]] · [[ADR-008-Exercise-Catalogue]]
