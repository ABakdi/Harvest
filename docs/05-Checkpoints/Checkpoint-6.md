# Checkpoint 6 — Steps that count, and a gym that knows what day it is

The first days on [[Phase-4-Health-and-Gym]]'s beta, on the phone
rather than the emulator. Ten complaints. One of them turned out to
be a feature that had never been wired at all, and the rest are the
gap between a training log that *works* and one I would keep a
paper notebook over.

## 1. One way to split a screen

**The complaint:** the paired screens looked wrong. Body, Records and
the farmer's tab each had a segmented switch at the *bottom*, sitting
on top of the real navigation bar like a second one; the floating
button fought it for the same corner; and the title above said
*Health* or *Stats* while the switch said *Body* and *Progress*. The
Granary, meanwhile, had proper tabs at the top. Two patterns for one
job.

Now there is one. Every split screen puts its tabs **under the
title**, the way the Granary always did, and the title names the tab
on the bottom bar — *Body*, *Records*, *Farmer* — so the two rows read
as one heading. The tab row itself is a little bolder: a rounded
underline the width of the label, the selected label in the accent.
The bottom switch is gone, and with it `FeatureSwitcher`.

Each half still owns its scaffold — the notes screen keeps its drawer,
the gallery keeps its trash button — and is handed the title and the
tab row to put in its own app bar. When only one half is switched on
there is nothing to switch, so the tabs go and the title goes back to
naming the half that is left. An open note shows its folder where the
tabs would be; the back arrow brings them back.

## 2. Steps were never counted

**The complaint:** the step counter did not work.

It could not have. Phase 4 shipped the arithmetic (`applyReading`, the
reboot case, the 3 AM boundary), the `step_days` table and the card —
and nothing that ever produced a reading. No sensor listener, no
channel, no permission in the manifest. The checklist said "behind a
platform interface" and the interface was never written. A card that
says *0* over a table nothing writes to is the most convincing kind of
broken.

The feed exists now, and it reads from the **phone's own step store**
first: Health Connect, which is where Samsung Health, Fit and the
Pixel's counter all write, so the number on the card is the number in
the phone's health app. It answers *how many steps between these two
instants*, so a Harvest Day is one question — 3 AM to 3 AM — and the
answer is written down as it is. Reboots, watches, other apps: already
solved by the store. For a phone with no Health Connect the raw
since-boot counter is the fallback, and the delta arithmetic from
Phase 4 finally has something to apply itself to.

Both are foreground reads: when the app comes back, when the Health
screen is looked at, and on a refresh button. No service watching a
sensor — steps are a passive number ([[Health]] H3) and passive things
do not get a battery budget. Nothing is sent anywhere; Health Connect
is an on-device store and the read is a local call ([[Business-Rules]]
#13 still holds).

The card now says which of three things a zero means: nothing counted
yet, *not allowed to look* (with a Connect button that asks), or
*nowhere to look* (with a button to install Health Connect where the
phone supports it). The permission is asked at that button, never at
launch (H1).

Two more things were on the list as done and were not: the daily step
goal had no way to be set, and the +5 XP for meeting it — like the +5
for a logged weight — was never paid. A flag on the card sets the goal;
both are paid now, once a day, through the same ledger as everything
else.

> **[[Health]] rule H2 is revised.** It said steps come from the
> phone's sensor, with Health Connect as a later option. The store is
> the better source on every phone that has one — it is what the phone
> itself trusts — so it is the first choice now, and the sensor is the
> fallback. The privacy promise does not move: no account, no network,
> no third party.

## 3. A bar weight beside a dumbbell

**The complaint:** every exercise in a program showed a bar weight.

Nothing looked at the equipment. The catalogue has exactly five kinds
of bar — barbell, EZ, Olympic, Smith machine, trap — and `usesBar`
now says so; my own exercises count if they say *barbell* anywhere.
The bar field and the plate calculator appear for those and not
otherwise. A dumbbell row no longer asks a question with no answer.

## 4. A rest I can type

**The complaint:** rest between sets was six chips and nothing else.

The chips stay, and a box beside them takes any number of seconds —
committed on the keyboard's done key, shown selected the way a chip
would be. Same control in the program and mid-session.

## 5. The clock pauses

A phone call, a queue for the rack: not training. Tapping the time in
the session's app bar stops the clock; tapping it again starts it.
The elapsed time is the start to now, less every pause that ended,
and a session finished while paused ends at the pause. Sets can still
be ticked while paused — the pause is about the time, not the lifting.

Schema **v14** adds `workout_sessions.paused_at` and
`paused_seconds`; the archive carries both.

## 6. The days go round

**The complaint:** finishing day 1 should put day 2 up next, then
day 3, then back to day 1 — unless I deliberately pick another.

Derived from the log, not stored: the last finished session's day,
then the one after it by position, wrapping at the end. A discarded
session does not count; a day picked out of turn moves the pointer
from there. The start sheet leads each program with **Up next** as a
one-tap card, and lists the other days under it, smaller, for the day
I want to skip. The program's tile on the gym screen says *Next: Day 2*
so I know before I tap.

## 7. Finishing with sets left is a question

**The complaint:** I finished a session with exercises undone and it
was simply checked in.

Finish is what checks the habit in ([[Gym]] Y4), so leaving sets
behind is a decision to make with the eyes open. If any un-skipped
exercise still has unticked sets, Finish asks — *3 of 12 sets are not
ticked; the session ends here and the gym habit is checked in as done
for today* — and only then does it. Skipped exercises are not
counted: those sets were never going to happen. A session with
nothing logged keeps its own, older question.

## 8. The record to beat, where the decision is made

**The complaint:** the session showed *last time* but not the PR.

Announcing a record after the set is half the loop; the other half is
knowing the number while loading the bar. Each exercise card now
carries **Best: 100 kg×5 · est. 116 kg** under *last time* — the
heaviest set and the best estimated single, the estimate labelled as
one (Y6). It comes from the same records query the tick compares
against.

## 9. Steps as ground covered

Nobody pictures 8,000 steps; everybody pictures six kilometres. The
card now says both — *8,000 · 6.0 km* — and the week's average with
it. It is stride × count and nothing cleverer: the phone does not know
how long my legs are, so the stride is a setting beside the goal (75 cm
unless told otherwise, roughly 0.415 × height), and the figure is what
it says it is. Kilometres beside kilograms, miles beside pounds — one
choice of units, made once.

## 10. The amount box takes a sum

A receipt is three things and a coffee, and adding it up on a phone
in a queue is exactly the kind of thing that turns a five-second log
into a skipped one. The amount box now takes `12+3.5*2`, shows what it
comes to under the field as it is typed, and Log logs the result.

No system keyboard has `× ÷ ( )` on its number layout, and the one
that does puts the digits three taps away — so the sheet keeps its
own. A calculator's keys in the app's own chips: digits, `.`, `00`,
the four operations, brackets, backspace (long-press clears) and
`C`. The amount field is read-only to the system, which is what
stops the phone's keyboard sliding up over it; the caret still shows
and still moves, so a wrong digit mid-sum is a tap away. Brackets
work; a comma inside a sum is a decimal point; an unfinished sum, a
division by zero or a total of nothing disables Log, the same way a
bad number always has.

## What I'd do next

The open question was *how to make it better*. Living with it for a
week, in the order I would take them:

1. **The session screen's app bar is the wrong place for Finish.** It
   is the most consequential button on the screen and it sits beside
   an overflow menu at the top, where a thumb between sets is not. A
   bottom bar — clock, pause, Finish — with the rest timer above it
   would put the three things I touch mid-session in one place.
2. **A record deserves more than a snackbar.** The tick is the
   feedback loop the feature exists for; a floating bar that fades in
   two seconds under a sweaty thumb is not much of a celebration. The
   Field already has a confetti moment for a check-in; the PR should
   borrow it.
3. **The open set is marked with a `P`.** Nobody knows what it means
   until told. A `1+` badge says it.
4. **Empty states are long.** *Write down one morning and a couple of
   weeks of them and…* is a paragraph where a line would do. Every
   empty state should be a title and at most one short sentence, and
   the sentence should say what to tap.
5. **The gym screen opens on the catalogue.** *1,324 exercises* is the
   first card under the running session — a reference book ahead of
   the programs I actually use. Programs first, catalogue last.
6. **The Health screen's floating button says "Log a weight"** over a
   screen that is mostly sleep and steps. It should be the one thing
   this morning needs: *Log last night* until the night is written,
   then the weight.
7. **A gym seed can still be ticked by hand from the field.** I left
   it on purpose in Phase 4 — I go to gyms without my phone — but it
   means a streak can move without a session. Either a hand tick
   should offer to log a bare session (*went, no numbers*), or the
   crop card should say the habit is the program's and send me there.
8. **Reordering exercises** still has no drag handle. The position
   column is there; the gesture is not.
9. **The Records tab lands on the notes list, always.** Where I was
   last — a note, an album — is the more useful place, and the tab
   controller now makes remembering it cheap.
10. **Settings is one long list.** Five sections deep, with the
    features switches, the daily cycle, sleep, reminders and pomodoro
    in a single scroll. Collapsible sections, or a page per section
    behind a list, would make the farmer's tab feel like a place
    rather than a config file.

## Rules touched

| Spec | Change |
| :--- | :--- |
| [[Health]] H2 | Steps come from Health Connect first, the sensor as fallback. Still no account, no network, no third party. |
| [[Gym]] | The bar and the plates belong to bar exercises only (Y9). Finish asks before leaving un-skipped sets behind (Y10). The days go round (Y11). |
| [[Local-Database]] | Schema v14: `workout_sessions.paused_at`, `paused_seconds`. |
| [[Finances]] | The amount box takes a sum and logs the result. |
| [[Health]] | Steps are shown as distance too, from a stride I set. |

Related: [[Checkpoint-5]] · [[Phase-4-Health-and-Gym]] · [[Health]] · [[Gym]]
