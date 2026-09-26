# Checkpoint 9 — The browser does what the phone does

The last stretch of [[Phase-6-Sync-Accounts-and-Web]], on top of
`v3.0.0-beta.1`. Three things: the Wishlist and the places work I had
half-finished, the web brought up to everything the phone writes,
and a deployment I can actually run. On the way, a read of the new
code turned up a set of bugs on the phone that had nothing to do
with the web.

## 1. The Wishlist, finished

The Granary's fourth tab ([[Wishlist]]) was specified and half built
when I stopped: the web had no words on it at all, and three things
were wrong underneath.

- A reorder on the phone never reached the other device: it wrote
  the new order without moving the row's clock, so the server took
  it for an old copy and kept its own.
- A moved item kept the place it had in the list it left, and landed
  in the middle of the other one. It now joins the bottom (W4).
- A wish item that arrived bought — by sync or an import — had a
  *Bought* fold of its own, which W7 says the wishlist does not
  have. It stays in the open list, with no check.

## 2. Places: a note, a chip and a satellite

A saved place takes a note (schema v20), every geotagged action has
a small chip saying where it happened ([[Places]] PL8), and the map
has a satellite base (PL9, [[ADR-010-Maps]]).

What was wrong with it before it shipped:
- the note was not in the export, and the contract refused a place
  without one — so every place saved on beta.1 would have vanished
  from the browser on its next pull. A column added after beta.1 now
  reads as empty when it is missing;
- switching the map back to streets wiped the trail and the pins,
  and saved places had no names over the satellite, which has no
  font of its own;
- the chip said *no location recorded* while it was still looking;
- on the phone, opening the map from a chip tripped an assertion,
  and the red dot of a saved place could not be tapped.

## 3. The web writes what the phone writes

Until now the browser read most of Harvest and wrote about a third
of it. The rule from here is simple: anything the phone writes that
does not need the phone itself, the browser writes too ([[Web]]).
What stays on the phone is the hardware: the alarms and reminders,
the steps, the trail, the widget and the lock. Settings lists them
under *On the phone* instead of leaving them out without a word.

What arrived, by screen:
- **Field** — a seed's own page, its daily notes, the focus timer,
  tomorrow's plan, a freeze bought with coins, the weekly report,
  and the albums due today.
- **Granary** — money moved in and out of the wallet and the pots,
  debts and their payments, the budget, categories, sums typed into
  an amount, the repeat card, and an Insights tab.
- **Body** — nights and weights written, the program editor, and a
  whole session run from a laptop, rest timer and records included.
- **Records** — pictures and recordings uploaded, albums, the
  timelapse, folders, tables, recordings, read aloud, print.
- **Places** — the week and the month, a stay named, a place edited
  or forgotten, the history deleted.
- **Settings and data** — every setting the phone syncs, the first
  run, and the archive: a zip from the browser imports on the phone
  and the other way round.

Where both sides must agree on arithmetic, the rule lives once in
`packages/core` with a fixture both are tested against: sums typed
into an amount, and the gym's records, labels and plates.

## 4. What reading the phone again turned up

Porting a screen means reading it closely, and some of the phone was
wrong.
- **Tomorrow's plan** listed a times-a-week habit whose week was
  already done. The comment said it would not; the code never asked.
- **Correcting last night** replaced its sleep target with today's,
  which rewrites history ([[Business-Rules]] #3), and dropped a note
  written from the browser.
- **An accessories line** on a gym day was in no export at all (#11).
- **Picking a bar weight** cleared the slot's rest, and renaming a
  day cleared its accessories.
- **A paused session** never told the other device it was paused.
- **A picture's name** could fail to reach the other devices: the
  row learned it without moving its clock.
- **A focus block on a gym seed** checked the seed in directly,
  skipping the session question (Y12).

## 5. Deploying it

`deploy/` runs the whole thing: MongoDB, the server, and Caddy
serving the site with its own certificate ([[Deployment]]). The
site's Content-Security-Policy names the only hosts it may reach —
the map tiles and the rates I ask for — which is [[Business-Rules]]
#13 enforced by the browser rather than by my good intentions.

Running it for real found what the tests could not: the policy
blocked the one inline script every page loads, a deep link could be
cached under the shell's old version, and a missing script would
have been answered with the home page and cached for a year. Two
browsers on one account, through that server, now converge on the
same field, the same wishlist and the same notes.

## 6. A second read of the new web

Code written quickly gets read slowly, so the whole of the new web was
read again against the phone, a screen at a time. What that found, and
what changed:

- **Money.** A category made from inside the expense sheet also logged
  the expense; a removed movement could take a pot below zero; the
  *from the wallet* switch could stay on after the wallet stopped
  covering the amount — on the phone too; an undo could bring back the
  wrong wallet movement — on the phone too; a wishlist estimate typed
  with a comma came out a hundred times too big; an expense could not
  be logged ahead; the month's total counted what was logged ahead.
- **The field and the body.** A double click logged a project twice
  (and could plant a seed twice, or a goal); correcting a night on the
  web rewrote its target; switching kilograms to pounds in an edit
  kept the old weight; the first run could stop halfway, and then
  flickered back into view for a frame after it finished.
- **The gym.** Dropping a set and adding one gave two sets the same
  number — on the phone too — and the program's picture was never
  offered in the browser.
- **Records and places.** A heading with an unusual line separator in
  it froze the tab; an archive import stamped today's location on every
  row it brought, over the real one; an export left out the pictures
  not uploaded yet; a recording could get a name the phone refuses to
  download; and a geotag still waiting for its place could reach the
  phone and be given *the phone's* place.

Each came with a test that fails without its fix.

## 7. What was left, done

The second read ended with a short list of things I had written down as
decided rather than done. None of them stayed that way.

- **A restored category keeps its place** (schema v21). A category had
  no birth date, so both apps sorted by the last edit and an undo sent
  it to the bottom. It has one now, backfilled from the last edit for
  the ones that already existed, and carried in the archive.
- **Pounds are a unit of their own** ([[Gym]] Y8). A pound lifter
  rounds to a quarter pound, not a quarter kilo, so 135 lb comes back
  as 135 and not 135.03; the plate sheet loads 45s on a 45 lb bar; and
  a target lighter than the bar says the bar alone is over. One rule
  in `packages/core`, pinned by the fixture both apps read.
- **Transcribe in the browser**, through the server's assist, saying
  first what goes and to whom. Doing it found the server turning away
  any recording over about 3.7 MB — its general body limit sat in
  front of the assist's own — which the phone would have hit too. The
  phone now also says a recording is too long, or of a kind that
  cannot be sent, before reading it, rather than after the server
  refuses.
- **The phone catches up with the browser**: a saved place's reach
  edited on the card, an exercise of my own from the picker, and a
  program's days moved up and down.

## Rules touched

| Spec | Change |
| :--- | :--- |
| [[Web]] | The web writes what the phone writes; phone-only by nature is the hardware. New decisions: freezes bought, not spent; the focus timer per device; one session across devices; opt-in browser geotags; the same archive. |
| [[Wishlist]] | W4: a moved item joins the bottom. W7: a bought wish item stays open. *Bought on* is a Harvest Day. |
| [[Places]] | PL2: browser geotags are opt-in. PL8: the chip's pending state. PL9: satellite base. |
| [[Health]] H6 | Typed times on the web; a correction keeps its target. |
| [[Gym]] Y3 | A running session blocks another on either device. |
| [[Business-Rules]] #11, #13 | The web keeps the archive; the site's policy is the list. |
| [[Sync-API]] | A column added after beta.1 may be missing. |
| [[Finances]] | Guards on the wallet: paid from it only when it covers; a removal never overdraws; the month counts up to today. |
| [[Places]] PL3 | The phone's place goes only to its own recent geotags; an older one takes the trail at its time. |
| [[Gym]] Y13 | New rows go after the highest position. |
| [[Business-Rules]] #3 | A corrected night keeps its target and its note. |
| [[Gym]] Y8 | Pounds round and load in pounds; the bar alone can be over. |
| [[Notes]] N10 | Transcribe in the browser, through the server. |
| [[Places]] | A saved place's reach is edited on both devices. |

Schema v18 → v21. Tests: phone 874 → 957, web 99 → 360, shared core 219 → 270, server 74 → 75. Shipped as `v3.0.0-beta.2`, installed over the published beta.1 on the emulator first.

Related: [[Checkpoint-8]] · [[Web]] · [[Wishlist]] · [[Places]] · [[Deployment]]
