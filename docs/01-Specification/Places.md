# Places

Phase 5 module ([[Phase-5-Goals-Places-and-Voice]]). Where I went,
and what I did there. It has two parts:
- **a trail**: my movements, recorded in the background while tracking
  is on;
- **geotags**: the place where I was when I did something, attached to
  every action in the app, whether an expense, a picture, a note, a
  check-in or a set.

A map shows both, one day at a time.

## Why it belongs here

Harvest already knows *what* I did every day. It does not know
*where*, and where is half of what makes a day memorable: the
café where that expense happened, the trail where the picture was
taken, the city I was in for the week the streak survived. Travel is
also the one time the rest of the app is least use: the routine breaks
and the field goes quiet, yet those are the days worth looking back on.

A map of a day, with its actions pinned where they happened, turns the
log into a diary.

## What it is, and firmly is not

**Is:** a private record of my own movement, drawn on a free map
([[ADR-010-Maps]]), with my own actions pinned on it, browsable by
day.

**Is not:** location sharing, check-ins at venues, "places near you",
or anything that sends where I am to anyone. No feature of Places
talks to another person, and none may.

## Off by default, and asked for twice

Places is a feature switch like [[Notes]] and the [[Gym]], **off**
until I turn it on. Turning it on asks for location permission in two
steps, as Android requires:
1. **While using the app**: enough for geotags on everything I do with
   the app open.
2. **All the time**: needed for the trail, which records with the app
   closed. It is asked separately, after a sentence that says exactly
   that, and refusing it leaves geotags working and the trail off.

## The trail

While tracking is on, a **foreground service** records my position:
- **The notification is always there**: *"Harvest is recording your
  trail"*, with a tap that opens Places. It is permanent because
  Android requires it, and because a silent tracker is exactly what
  this app must never be.
- **Sampling:** a point when I have moved 50 m and at least 60 seconds
  have passed. The balanced power mode is the default, and high
  accuracy is a setting. Standing still records nothing.
- **Pause** is in the Places screen's menu, beside the trail switch:
  "pause for 1 hour" and "pause until tomorrow". A pause stops the
  service; it does not merely drop points.
- **After a reboot**, tracking resumes by itself if it was on.
- **Battery.** Balanced mode with a distance filter is what makes this
  affordable. The Places screen shows today's point count, so a
  runaway is visible.

Each point is a row: time, Harvest Day, latitude, longitude, accuracy,
and speed if known. Points are **never edited**. A whole day's trail
can be deleted from the day view, with undo.

## Geotags

**Every action the app records gets the place it happened**, when
Places is on:
- check-ins, seed notes and seeds planted;
- expenses, money movements, debts and payments;
- memories (pictures), notes and voice notes;
- sleep nights, weights and gym sessions;
- goals and goal items.

It happens in one place: the database's own change log. Every insert
that `logChange` records for an *action table* also writes a
**pending geotag**. A single filler then resolves pending geotags in
this order:
1. **The last trail point**, if it is under two minutes old and under
   100 m accurate. This costs nothing and is what happens while
   tracking.
2. Otherwise, **one fresh fix**, with a 10-second timeout.
3. Otherwise, **unavailable**. The action is kept without a place.
   An action is never delayed or refused for want of a location.

A geotag is its own row (`target_table`, `target_uuid`, time,
coordinates, accuracy, state), never a column added to thirty
tables. That way a table I add later is geotagged by being on one list.

## The map

**Records** gains a third tab: **Notes · Gallery · Places** (the tab
row as in [[Notes]] N6).

- **Day view** (the default): a date strip across the top, the map, and
  a sheet with the day's timeline. The trail is drawn as one line in
  the theme's primary colour. Each geotagged action is a pin coloured
  by its feature, and its timeline row carries the feature's icon: a
  coin for an expense, a camera for a memory, a leaf for a check-in, a
  dumbbell for a session, a pen for a note. Tapping a pin marks it;
  tapping a timeline row flies the map to its pin and opens the action
  where it has a screen of its own (a note, a seed, a goal).
- **Stays**: stretches of ten minutes or more within 100 m of one spot.
  They are drawn as circles and listed in the timeline as
  *"08:10–17:45 · 9 h 35 min"*. I can name a stay ("Home", "Office",
  "Gym"). The name is kept as a **saved place** with a radius, and
  every later stay inside that radius takes the name.
- **Range view**: a week or a month with the trails together. This is
  the travel view; any span of days and clustered pins come later.
- **Filters** (later): pins by feature, so the day's expenses can be
  shown on their own.

Tiles need a connection. Without one, the map is blank but the
timeline and stays still list everything, because they are local.

## Privacy

- Location is the most sensitive data in the app. It is in the
  **private tier** with finances ([[Sync-Strategy]]): end-to-end
  encrypted when synced, and never readable by the server.
- **Export** carries the `LocationPoints`, `Geotags` and
  `SavedPlaces` sheets ([[Business-Rules]] #11). The archive screen says
  so beside the switch that leaves them out of a given export.
- **The map tiles** are fetched from OpenFreeMap. They learn which
  area of the map I am looking at, never the trail ([[ADR-010-Maps]]).
- **Turning Places off** stops the service at once and stops
  geotagging. It deletes nothing. *Delete all location history* is a
  separate button, confirmed, and not undoable.

## Rules

| # | Rule |
| :-- | :--- |
| PL1 | Places is off by default. The trail needs "all the time" permission and a visible foreground notification, and without them it does not run. |
| PL2 | Every insert into an action table gets a geotag when Places is on. The list of action tables is one constant, and a new feature joins by being added to it. |
| PL3 | A missing location never blocks, delays or fails an action. The geotag is marked unavailable and the action stands. |
| PL4 | Points are append-only. A day's trail can be deleted whole; a point can never be moved. |
| PL5 | Stays are derived from points, never stored, except the names I give them, which are saved places. |
| PL6 | Location data is private-tier: end-to-end encrypted in sync, exported only with my say-so per export, and never sent anywhere else. |
| PL7 | No location is ever shared with another person, sent to a geocoder in the background, or used to suggest anything. |

Related: [[ADR-010-Maps]] · [[Gallery]] · [[Finances]] · [[Sync-Strategy]] · [[Phase-5-Goals-Places-and-Voice]]
