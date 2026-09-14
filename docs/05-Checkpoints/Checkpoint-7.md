# Checkpoint 7 — Finish where the thumb is

The ten things I wrote at the foot of [[Checkpoint-6]] under *what I'd
do next*, done in the order I wrote them. None of them is a bug. All of
them are the difference between a training log that works and one I
reach for without thinking — which is the only test that matters
before `v2.0.0` gets its number.

## 1. The session's bottom bar

**The complaint:** Finish, the most consequential button on the screen,
sat beside an overflow menu at the top, where a thumb between sets is
not.

The three things I touch mid-session — the rest, the clock and Finish
— now sit in one place at the bottom. The rest timer bar stacks above
it while resting and is gone when not. The clock is still the pause
button, and says *Paused* beside the time while it is. The app bar
keeps the title, the set count and the overflow — note, add an
exercise, discard — which are the things I touch between *sessions*,
not between sets.

## 2. A record is a moment

**The complaint:** a PR was a snackbar that faded under a sweaty thumb.

The tick borrows the Field's check-in burst: a dozen trophies rise
from the tick itself, in the accent, with the thud. The words stay for
six seconds, long enough to be read while racking the bar. The
announcement still names which record it was — heaviest ever, or the
best estimated single — and the estimate is still labelled as one
(Y6).

## 3. `1+`, not `P`

The open set's badge now says what the set asks. Nobody knew what `P`
meant until told.

## 4. Shorter empty states

Every empty state is a title and at most one short sentence, and the
sentence says what to tap. *Write down one morning and the line
starts. Two weeks of them and it has a shape* became *Tap Log it one
morning and the line starts.* Eleven bodies rewritten, in both
languages.

## 5. Programs first, catalogue last

**The complaint:** the gym screen opened on *1,324 exercises* — a
reference book ahead of the programs I use.

The running session, then the programs, then the last three sessions,
then the catalogue. A reference book does not go ahead of the
training.

## 6. The Health screen's button knows what morning it is

**The complaint:** the floating button said *Log a weight* over a
screen that is mostly sleep and steps.

It now says *Log last night* until the night is written down, then
*Log a weight*. Sleep is the one thing this morning needs from me; the
weight is whenever I happen to stand on the scale.

## 7. A gym seed is checked in by a session

**The complaint:** a gym seed could be ticked by hand from the field,
so the streak could move without the log knowing why.

I had left it on purpose — I train in gyms where the phone stays in
the locker — and wrote in [[Gym]] that if it turned out to be a hole
the fix was a bare session behind the tick, not taking the tick away.
It is that now. The card shows the program's name beside the schedule
and a dumbbell for its icon, and a tap asks which of two honest things
happened: **Start the session**, which leads into the start sheet, or
**Went, no numbers**, which writes a session with nothing in it and
finishes it on the spot. The second goes through the same door as the
first — [[Gym]] rule Y4 — so history has a row for the day, the habit
is checked in once, and *Next* still follows finished sessions only. A
second bare tick the same day pays nothing more, like any habit.

> **[[Gym]] rule Y12 is new.** A gym seed is checked in by a session
> and nothing else. The hand tick from the field is a bare session, so
> the streak and the log always agree.

## 8. Drag to reorder

The position column always existed; the gesture did not. Each exercise
in a program day has a drag handle on its right. The handle is the
only place a drag starts, so a swipe through the list still scrolls.

## 9. Records remembers where I was

**The complaint:** the Records tab always landed on the notes list.

The half I was last in — notes or the gallery — is remembered, and so
is the note I was last writing, so a cold start lands on the same
page. A link followed from elsewhere still wins. The same `PairedScreen`
rule serves Body and the farmer's tab; they just do not ask for it.

## 10. Settings is a place

**The complaint:** Settings was one long scroll, five sections deep,
and read like a config file.

It is a short list now — Harvest, Extras, Reminders, Focus timer,
Money, Privacy, My data, Appearance — each a page of its own with only
what it is about. The daily goal, the day's hours and sleep share the
first page because they are the same idea: the shape of my day. A
startup problem, if any, still sits at the foot of the list.

## Rules touched

| Spec | Change |
| :--- | :--- |
| [[Gym]] | Y12: a gym seed is checked in by a session and nothing else; the hand tick is a bare session. |
| [[Phase-4-Health-and-Gym]] | The drag handle and the hand tick leave the backlog. |

Tests: 566 → 573. Nothing in the schema moved.

Related: [[Checkpoint-6]] · [[Phase-4-Health-and-Gym]] · [[Gym]] · [[Health]]
