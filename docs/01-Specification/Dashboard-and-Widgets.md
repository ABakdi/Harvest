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

A **bar, not a tile** — four cells wide, one header row, resizable both
ways. It wears the app's own surface rather than the brand gradient: a
card a step above the wallpaper with a hairline edge, the same 22 dp
corner, green as an accent rather than a wash, and a dark variant that
follows the system. Tapping the card opens the app.

The card wraps its content, so switching a section off makes the widget
**smaller**, not emptier.

| Section | Shows | Switchable |
| :--- | :--- | :---: |
| **Streak** | The streak, and today's progress under it | never — it is the app |
| **Money** | Today's spend and the wallet balance, in the default currency | ✓ |
| **Today's field** | What is still due, one full-width card at a time, cycling sideways through all of it | ✓ |
| **Quick actions** | Log an expense · plant a seed — each opens the app on that sheet | ✓ |

The field is one card at a time rather than a list because a widget is
wider than it is tall, and a card that wide is legible at arm's length.
It turns its own pages because nothing else can: `RemoteViews` has no
horizontally-scrolling container, its two collections go up and down, a
`HorizontalScrollView` is refused at inflation, and a chevron wired to
a broadcast never reaches the flipper ([[Checkpoint-3]]).

The switches live in Settings → My data. Everything is computed **from
the database** with the same `isDueOn` rule the field uses, so it is
right when no screen exists — refreshed at startup, after every
check-in and seed edit, on resume, and by the 3 AM job. The service
writes every number whatever the switches say; the widget decides what
to show, so turning a section on is a redraw rather than a recompute.

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
