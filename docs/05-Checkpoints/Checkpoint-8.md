# Checkpoint 8 — The day closes on its own

Four things from the first day on beta.3 on the phone. One was a
tab row that had gone missing, one was two cards touching, and two
were the app not doing something it plainly should: writing the
day's steps down when the day ends, and letting a receipt be
logged on the day it belongs to.

## 1. The Records tabs had vanished

**The complaint:** with Notes and the Gallery both on, the Records
tab showed only notes, and the tab switcher was nowhere.

It was there — under the note. Notes opens on the note I was last
writing, and an open note replaced the tab row with its folder, so
the only way to the Gallery was to close the note first, which
nobody told anyone. The tabs now stay whether a note is open or
not, and the folder sits under the title where the session screen
puts its set count. Notes on its own, with no pair, still shows the
folder where the tabs would be.

## 2. Two cards touching

The sleep card and the steps card sat flush. The sleep card had no
bottom margin; the steps card was drawn straight under it. A gap,
the same one every other card on the screen keeps.

## 3. The day's steps are written down at 3 AM

**The complaint:** the count should be logged automatically when the
day ends, kept, and shown with the rest of the body's numbers.

Steps were only ever read while the app was on screen. On a phone
with Health Connect that mostly worked out — the store keeps the
history, and the next pull rewrote yesterday — but the day was
never *closed*: a goal met on an evening walk with the app shut was
never paid, and on the sensor path the evening's steps landed on the
next morning.

The 3 AM day-reset job now pulls steps for the day that just ended,
after it judges the streaks. On Health Connect that is the ordinary
month-long read, a day later; on the sensor it closes yesterday at
the current reading and anchors today there, so the morning's first
pull measures from 3 AM and not from the last time the app was
open. The goal of the day that ended is paid by the job, and — in
case the job did not run — by any later pull, once.

That needed the steps channel to become a **plugin**
(`packages/harvest_steps`). A method channel registered from the
activity does not exist in the background engine the job runs in;
a plugin is registered with every engine. Health Connect wants its
own permission to be read with the app off screen, so on phones
whose Health Connect offers it the Connect button asks for reading
in the background alongside reading steps. A phone without it still
counts whenever the app is opened.

And the record is on the Health screen now, under **Your steps**
beside the readings and the nights: the last thirty days as a total
and a distance, the average and the best day, and a bar a day for a
fortnight with the goal drawn across them.

> **[[Health]] H2 is revised** again: reads happen on open, on the
> Health screen, and once at 3 AM from the day-reset job. Still no
> service, still no network.

## 4. An expense on the day it belongs to

**The complaint:** a forgotten receipt could only be logged as
today's.

The expense sheet has a **Logged on** chip, today unless I say
otherwise, taking any day a year either side — back for the receipt
found in a pocket, forward for the bill I know is coming. The day's
+10 XP follows the day the expense lands on, as it does for a log
and a removal: moving an expense off a day gives that day's XP back
if it was the last one, and pays the new day if it had none.

## Rules touched

| Spec | Change |
| :--- | :--- |
| [[Health]] H2 | Steps are read on open, on the Health screen, and at 3 AM by the day-reset job. H9: the day that ended gets its goal paid by whichever pull sees it first. |
| [[Finances]] | An expense is logged on a chosen Harvest Day; the day's XP follows the day. |
| [[Notes]] | The Records tabs stay while a note is open; the folder moves under the title. |

Tests: 573 → 580. Nothing in the schema moved.

Related: [[Checkpoint-7]] · [[Health]] · [[Finances]] · [[Notes]]
