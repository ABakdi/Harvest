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
| **Goal item** | text, kind (`need`: a requirement, what I must have or know; `step`: a task, what I must do), done or not, position, optional note, optional link to the seed it was planted as, and for a subtask the task it belongs to (`parentUuid`) |
| **Seed → goal** | a commitment may carry the goal it serves (`commitments.goal_uuid`) |

**Requirements and tasks.** *"What I need to achieve it"* and *"what I
need to do"* are different lists in my head: running shoes and a
training plan are requirements — what it takes — while the 10 km in
October is a task. Both are ticked and both count toward progress, but
they are drawn as two sections, because reading them as one list loses
that difference. (In the data they are still `need` and `step`.)

**Subtasks.** A task is often too big to tick in one go: *"Run a 10 km
race"* is really *find a race*, *register*, *run it*. A task can hold
subtasks, one level deep — a subtask has no subtasks of its own, which
keeps a goal a checklist and not a project plan. Requirements can hold
subtasks too (*"a training plan"*: *pick one*, *print it*).
- A task with subtasks is **done when all its subtasks are**; its own
  tick is drawn from them. Ticking it ticks all of them, and un-ticking
  it un-ticks them — my hand, once, for the lot.
- Progress counts **subtasks in place of their parent**: a task with
  three subtasks weighs three, not one.
- A subtask can be planted as a seed like any item; its planted to-do
  ticks it (GL3), which may complete its parent.
- Deleting a task takes its subtasks with it, and undo brings them back.
- Subtasks reorder within their task; a subtask can be lifted to a task
  of its own, and a task without subtasks can be moved under another in
  the same section — *Move under…* — taking that item's kind.

## The board

The field gains a top tab row, **Today · Goals**. The Goals tab is a
board: one card per active goal, in my order, each showing:
- the title and the target day, with the days left when there is one;
- progress: a ring filled by ticked items over all items;
- the seeds it planted, as small chips (an archived one says so);
- the next unticked task — its first open subtask when it has them, and
  once every task is done the next open requirement — so the card
  answers *what now?*

Below the active goals, collapsed, are **Achieved** and **Dropped**.

Opening a goal shows the whole of it: the *why* at the top, then
**Requirements — what it takes**, then **Tasks** with their subtasks
indented beneath them, then **Seeds**. Every item can be ticked,
edited, dragged, removed with undo, **planted**, or given a subtask.

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
| GL2 | Progress is ticked items over all items, requirements and tasks alike, with a parent's subtasks counted in its place. A goal with no items shows no ring, only "add what it takes". |
| GL8 | Subtasks are one level deep. A parent is done exactly when all its subtasks are; ticking or un-ticking the parent does the same to all of them at once. Its stored tick follows: none while any live subtask is open, the latest subtask's once all are ticked, written in the same change as the subtask's. One rule in `packages/core` (`parentDoneAt`), pinned by the goals fixture both clients read. |
| GL3 | Only a planted **to-do** ticks its item, and undoing that check-in un-ticks it. Nothing else changes an item without my hand. |
| GL4 | Achieving is always my tap, and pays +50 XP once; reopening takes it back with a mirror row. |
| GL5 | Archiving, deleting or retiring a seed never changes a goal, and dropping or deleting a goal never changes a seed. They are linked, not owned. |
| GL6 | Goals and items are ordinary synced, exported, archived rows ([[Business-Rules]] #11): sheets `Goals` and `GoalItems` (with a `ParentUuid` column from schema v24), and the `GoalUuid` column on `Commitments`. |
| GL7 | Deleting a goal is soft, with undo, and its items go with it; deleting a task takes its subtasks, and undo brings them back. |

Related: [[Productivity-Engine]] · [[Gamification]] · [[Core-Entities]] · [[Phase-5-Goals-Places-and-Voice]]
