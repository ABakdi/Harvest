# Dashboard, Widgets & Reports

## The Field (home screen)

The main screen is **today's field**: every commitment due today as a crop card, ordered by urgency, with the Global Streak flame and XP bar always visible up top.

- A card shows what the seed asks of me, its **note**, **today's note** if I wrote one, and a live countdown to its **reminder** and its **deadline** ([[Checkpoint-3]]).
- Tap a card → check-in ([[Productivity-Engine]]).
- Long-press (or the overflow button) → focus timer, notes, history, edit, vacation mode, archive, delete.
- Pillar gauges appear as their phases ship: budget 🟢🟡🔴, sleep debt, screen time.
- A **Tomorrow** card at the foot of the field shows what's due tomorrow (habits, planned to-dos) and opens the plan ritual — an explicit door, not a hidden pull gesture.

## Stats

Lifetime XP and rank progress, the activity heat-map, project burn-up
and per-habit streaks. Tapping a habit opens **that seed's own screen**
— its streak, its eight-week run strip, and the timeline of every day
it was watered or written about ([[Productivity-Engine#Seed history]]).

## Archive

Every seed I have retired, newest first, with the note that says why it
was put away and the date. Restore puts one back on the field; delete
removes it for good ([[Business-Rules]] #8). Tapping one opens its
history — an archive whose contents cannot be read is a bin.

## Weekly Harvest Report (Sundays)

A shareable summary card:
- Total XP this week; best & worst day
- Streak status and closest calls
- Avg sleep vs. target (Phase 3+)
- Most-used app category (Phase 4+)
- Biggest spending category (Phase 2+)

## Home-screen widget ✅ ([[Checkpoint-3]])

Shipped early, out of [[Phase-5-Sync-and-Social]]: nothing about a
widget needs a sync server.

- **Compact:** the streak as a big number, today's field as `3/5 today`,
  and the farmer rank, on the brand gradient. Tapping opens the app.
- It is computed **from the database** with the same `isDueOn` rule the
  field uses, so it is right when no screen exists — refreshed at
  startup, after every check-in and seed edit, on resume, and by the
  3 AM job.

Still to come: the medium **"Vitality"** widget — four mini-gauges
(tasks X/Y, sleep hrs, screen X/cap, spent X/limit) — once the pillars
behind them ship.

## The loading screen ([[Checkpoint-3]])

An olive tree growing on the brand gradient: trunk, branches, leaves,
blossom, and the blossom becoming fruit. About 1.7 seconds, drawn by a
painter with no assets, and it never causes the wait — the screen leaves
when the tree has grown *and* startup has landed, and with reduce-motion
on the tree is simply there.

## Web dashboard (later, with [[Phase-5-Sync-and-Social]])

"The Field" as a bird's-eye grid, with keyboard-shortcut quick-log for desk time.
