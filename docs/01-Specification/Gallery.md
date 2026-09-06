# Gallery

Phase 3 module ([[Phase-3-Notes-and-Gallery]]). Albums of photos and
video, taken on purpose, over time.

## Why it belongs here

Everything else in this app measures a day and then throws the day
away: a check-in becomes a number, a number becomes a streak. Some
things do not survive that. Whether the gym is working, whether the
skin routine is doing anything, what a year of this actually looked
like — none of it is a number, and all of it is obvious in two photos
side by side.

So: **one picture a day, kept in order, playable as a run.** The
streak psychology the app already has, pointed at something a
spreadsheet cannot hold.

## Off by default

Like [[Notes]], the gallery is **not on** until I say so — asked once
in [[Onboarding]], switchable in Settings forever after. It asks for
the camera and for photo access, and it asks **when I turn it on**,
never at first launch.

Turning it off hides the tab, stops the prompts, and leaves every file
exactly where it is.

## The shape

| Thing | What it is |
| :--- | :--- |
| **Album** | A named run of memories — *Gym*, *Face*, *The flat* — with an optional schedule |
| **Memory** | One photo or video, its day, and a note |
| **Note** | Free text on any memory: what changed, what I weighed, what I was trying |

A memory's file lives in the app's own storage, not in the system
gallery. That is deliberate: a diet progress album is not something to
scatter through a camera roll that gets shared, backed up and scrolled
past by other people.

## An album is a seed

This is the part that matters, and it is why the gallery is not just a
photo folder.

**An album with a schedule appears on the field as a task.** It is due
like a habit is due, it is checked in by adding a photo rather than by
tapping a circle, and it feeds the Global Streak and the XP ledger the
same way every other check-in does ([[Gamification]]).

- The card shows the album, its schedule, and its own streak.
- Tapping it opens the camera rather than a quantity sheet.
- It obeys the same rules as any other seed: one check-in per Harvest
  Day counts, the day boundary is 3 AM, undo works the same day.
- Its reminder is an ordinary seed reminder — the same alarm-grade
  nudge, the same snooze, the same daily cycle shift ([[Notifications]]).

So the daily selfie is not a separate nagging system bolted on the
side. It is a habit whose evidence happens to be an image.

## Looking back

- **The album view** is a grid, newest first, with the day on each.
- **Play** runs the album as a timelapse — one frame per memory, in
  order, at a speed I pick. This is the whole point of the feature and
  it should be one tap from the album.
- **Compare** puts any two memories side by side: first and latest by
  default, or two I choose.
- **Search** reads the notes, so "the week I started creatine" is
  findable without scrolling a year of thumbnails.
- **Share** sends one picture out through the system sheet. It is the
  only door out of the app's own storage, and it opens by hand.

## Storage, honestly

Photos are large and this app has been careful about what it keeps.

- Images are **downscaled on import** to a sensible long edge and
  re-encoded; the original is not kept. A daily selfie for five years
  should cost megabytes, not gigabytes.
- Video is kept as imported, with a duration cap, because re-encoding
  video on a phone is a battery fire.
- The album view shows **how much space it is using**, and says so
  before I start rather than after.
- Deleting a memory puts it in the **trash**, and emptying the trash
  deletes the file. The promise that a photo asked to be gone is gone
  still holds — it just takes two deliberate steps, because a photo
  deleted by a fat thumb was gone for good too ([[Checkpoint-5]]).

## Rules

| # | Rule |
| :-- | :--- |
| G1 | Off until switched on; permissions are asked at that moment, never at first launch. |
| G2 | Files live in the app's own storage, not the system gallery. Nothing here is written where other apps browse. |
| G3 | A scheduled album is a seed: it is due, it is checked in by adding a memory, and it feeds the streak like anything else. |
| G4 | Images are downscaled on import. Storage is shown, not discovered. |
| G5 | Deleting moves a memory to the trash; emptying the trash deletes the file, for good. |
| G6 | The export carries every file at full stored quality, in album folders ([[ADR-007-Archive-Format]]). |

Related: [[Notes]] · [[Gamification]] · [[Productivity-Engine]] · [[ADR-007-Archive-Format]]
