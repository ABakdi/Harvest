# ADR-008 — The exercise catalogue is borrowed, and the animations are fetched

**Status:** Accepted · 2026-09-06 · [[Gym]] · [[Phase-4-Health-and-Gym]]

## Context

The [[Gym]] needs a list of exercises. Not a long one — a *complete*
one, because the moment a rack is taken and I need a substitute, an
incomplete list is worse than no list.

Writing that list is not a programming problem, it is a content
problem: a thousand-odd exercises, each with a body part, an equipment
type, a target muscle, and instructions that are correct. And a
picture, because "Landmine Press" means nothing to me in text.

There is an obvious source:
[hasaneyldrm/exercises-dataset](https://github.com/hasaneyldrm/exercises-dataset)
— **1,324 exercises**, each with:

| Field | Example |
| :--- | :--- |
| `id` | `"0001"` (zero-padded, stable) |
| `name` | `"3/4 sit-up"` |
| `body_part` / `category` | `"waist"` |
| `equipment` | `"body weight"` |
| `target` | primary muscle |
| `secondary_muscles` | array |
| `instructions.<lang>` | prose, in 10 languages |
| `instruction_steps.<lang>` | the same, split into steps |
| `image` | 180×180 JPEG thumbnail |
| `gif_url` | 180×180 animated GIF |
| `attribution` | `"© Gym visual — https://gymvisual.com/"` |

Body parts break down as: upper arms 292, upper legs 227, back 203,
waist 169, chest 163, shoulders 143, lower legs 59, lower arms 37,
cardio 29, neck 2.

Two facts decide everything below.

**The licence is split.** The README is explicit: *"Code, tooling,
dataset structure, and instruction text are released under the MIT
License. Exercise media (images & GIFs) is © Gym visual and
redistributed here with permission."* The words that matter are
**redistributed here** — permission was granted to that repository, not
to every app that copies it.

**The media is enormous.** The repository is ~125 MB. The JSON alone is
**17.4 MB** because it carries ten languages. A GIF averages ~93 KB, so
1,324 of them is **~120 MB**. The release APK is currently 76 MB.

## Decision

**Bundle the words. Fetch the pictures. Cache them forever.**

### 1. The catalogue is bundled, trimmed

`exercises.json` ships inside the app, cut down to what Harvest can
actually use:

- **English only.** The dataset has ten languages and Arabic is not one
  of them ([[Localization]]). Carrying nine languages I do not show, to
  miss the one I do, would be megabytes of nothing. In the event the
  trim came out at **0.8 MB** — better than the 2 MB this ADR guessed,
  because the fields dropped alongside the languages were the bulky
  ones.
- Fields kept: `id`, `name`, `body_part`, `equipment`, `target`,
  `secondary_muscles`, `instruction_steps.en`, `media_id`.
- It is **read-only reference data**: not in the database's migration
  path, not in the outbox, not in the archive. A logged set refers to
  an exercise by its `id` and nothing else ([[Gym]] rule Y2).
- The dataset is **pinned to a commit** —
  `7455efae41b330c265e7cd4b78dfa848e7ce5ebd` — and updating it is a
  deliberate act with a release note, not a moving target. The trim is
  `tool/trim_exercises.dart`, so the asset can always be rebuilt from
  the pin.

### 2. The media is fetched on demand, never re-hosted

Thumbnails and animations are downloaded from the pinned upstream
repository the first time an exercise is opened, and cached in the
app's own storage forever after.

Harvest therefore **uses** Gym Visual's media under the same terms as
any other client of that repository, and does not become a fourth-hand
redistributor of it by baking it into an APK.

- **Attribution is shown wherever the media is** — `© Gym Visual`,
  tappable through to gymvisual.com. Not buried in an About screen.
- **A picture is fetched only when I open that exercise.** Nothing
  prefetches, nothing crawls the catalogue in the background.
- **Nothing identifying goes with the request.** It is a GET for a
  static file: no account, no device id, no exercise history. The
  request reveals which file, and that is all it can reveal.
- **"Download them all" is a button**, for someone who wants the gym
  fully offline before a trip, and it says how much it will cost in
  megabytes before it starts.
- **"Never fetch" is a switch.** With it on, the gym shows names and
  instructions and no pictures, and works completely.
- The cache reports its size and can be cleared, like the [[Gallery]]
  does ([[Gallery]] rule G4).

### 3. My own exercises sit beside it

Anything the catalogue lacks I add by name, with an optional note. Mine
live in the database, sync when there is sync, and export with my data
— because unlike the catalogue, **they are my data**.

## Consequences

**Good.** The gym has a complete, illustrated exercise list on day one,
for 0.8 MB of APK and no content-writing project. The words work
with the network off. The licence line is respected rather than argued
about.

**The cost.** An exercise opened for the first time on a train shows no
animation. That is the honest trade for not shipping 120 MB, and the
"download them all" button exists precisely for the person who knows
they are getting on a train.

**Arabic instructions do not exist.** The dataset has no `ar`, so with
the app in Arabic the exercise *names and instructions stay English*
while every word Harvest itself wrote is translated. Better than a
machine translation of a thousand exercise descriptions nobody checked
— and if it grates enough, translating the ~1,300 names alone is a
tractable job later, and the ids make it a lookup table.

**A dependency on someone else's repository.** If it disappears, the
bundled catalogue keeps working and the animations stop appearing.
Nothing breaks; something gets less good. That is an acceptable failure
mode, and it is why the words are bundled rather than fetched too.

**Deliberately not done.** No exercise database of my own, no
user-contributed catalogue, no scraping. The moment this app is in the
business of curating exercise content is the moment it stops being a
tracker.

Related: [[Gym]] · [[Localization]] · [[ADR-002-Local-Database]] · [[Business-Rules]]
