# Goals

Phase 5 module ([[Phase-5-Goals-Places-and-Voice]]). A board on the
field for the things a streak cannot hold: *run a half marathon*,
*save for the car*, *learn Arabic calligraphy*. It holds what each one
takes, and the seeds I plant to get there.

## Why it belongs here

Every seed on the field answers *did I do it today?* None of them
answers *why am I doing it?* A habit of running three times a week is
a means, and the half marathon in March is the end. Until now the end
lived in my head, and the means drifted away from it: I'd keep the
streak going and forget what it was for.

A goal is the end, written down, with a list under it that I keep
editing as I learn what it actually takes. From that list come the
to-dos and habits that do appear on the field. The board is where I
plan, and the field is still where I act.

## What it is, and firmly is not

**Is:** a title, a *why*, an optional target date, and a living
checklist of what it takes. Items can be ticked, reworded, reordered,
added and removed as I get closer. Any item can be **planted** as a
to-do or a habit, and then stays linked to it.

**Is not:** OKRs. There are no key results with percentages to fill
in, no quarterly cadence, no scores. A goal has no streak and pays no
XP for being looked at. It is a note with a checklist and some wires
to the field, and it should feel like that.

## The shape

| Thing | What it is |
| :--- | :--- |
| **Goal** | title, *why* (free text), optional target day, status (`active` · `achieved` · `dropped`), position on the board |
| **Goal item** | text, kind (`need`: what I must have or know; `step`: what I must do), done or not, position, optional note, optional link to the seed it was planted as |
| **Seed → goal** | a commitment may carry the goal it serves (`commitments.goal_uuid`) |

**Needs and steps.** *"What I need to achieve it"* and *"what I need to
do"* are different lists in my head: running shoes and a training plan
are needs, while the 10 km in October is a step. Both are ticked and
both count toward progress, but they are drawn as two sections, because
reading them as one list loses that difference.

## The board

The field gains a top tab row, **Today · Goals**. The Goals tab is a
board: one card per active goal, in my order, each showing:
- the title and the target day, with the days left when there is one;
- progress: a ring filled by ticked items over all items;
- the seeds it planted, as small chips (an archived one says so);
- the next unticked step, so the card answers *what now?*

Below the active goals, collapsed, are **Achieved** and **Dropped**.

Opening a goal shows the whole of it: the *why* at the top, then
**What it takes** (the needs), then **Steps**, then **Seeds**. Every
item can be ticked, edited, dragged, removed with undo, or
**planted**.

## Planting from a goal

*Plant* on an item opens the ordinary seed editor, prefilled:
- the item's text as the title;
- a to-do for a step, a habit when I pick one;
- the goal set as the seed's goal.

When the seed is saved, the item and the seed are linked.

- **A planted to-do ticks its item** when it is checked in, and
  un-ticks it when that check-in is undone. That is the only automatic
  tick. A habit never ticks an item, because a habit is never *done*.
  Its item shows the habit's streak instead.
- **A seed can also be linked to a goal from the seed editor**, without
  an item: *"Serves: Half marathon"*. It then shows on the goal's card
  under Seeds.
- **Archiving or deleting a seed never touches the goal.** The item
  keeps its text, its tick and its link, and shows the seed as archived
  or gone.

## Achieving

When every item is ticked, the card offers **Mark achieved**. It never
does it by itself: a list can be complete while the goal still isn't.
Achieving a goal:
- pays **+50 XP**, once (`goal:<uuid>`);
- plays the harvest burst;
- moves the card to Achieved.

Its seeds keep running. Reopening an achieved goal takes the 50 back
with a mirror row, as an undone check-in does.

**Dropping** a goal is not a failure and costs nothing. The card moves
to Dropped, with an optional note on why, the way an archived seed
keeps its note. Its seeds keep running. A dropped goal can be picked
up again.

## Rules

| # | Rule |
| :-- | :--- |
| GL1 | A goal has no streak, no schedule and no reminder. It is judged by nothing; only its seeds are. |
| GL2 | Progress is ticked items over all items, needs and steps alike. A goal with no items shows no ring, only "add what it takes". |
| GL3 | Only a planted **to-do** ticks its item, and undoing that check-in un-ticks it. Nothing else changes an item without my hand. |
| GL4 | Achieving is always my tap, and pays +50 XP once; reopening takes it back with a mirror row. |
| GL5 | Archiving, deleting or retiring a seed never changes a goal, and dropping or deleting a goal never changes a seed. They are linked, not owned. |
| GL6 | Goals and items are ordinary synced, exported, archived rows ([[Business-Rules]] #11): sheets `Goals` and `GoalItems`, and the `GoalUuid` column on `Commitments`. |
| GL7 | Deleting a goal is soft, with undo, and its items go with it. |

Related: [[Productivity-Engine]] · [[Gamification]] · [[Core-Entities]] · [[Phase-5-Goals-Places-and-Voice]]
