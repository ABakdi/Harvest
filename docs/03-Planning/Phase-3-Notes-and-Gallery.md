# Phase 3 — Notes, Gallery & the Archive

Specs: [[Notes]] · [[Gallery]] · [[ADR-007-Archive-Format]]

The first phase after v1.0, and it jumps the queue ahead of gym, screen
time and sync. Two features and one long-overdue fix.

**Why first.** [[Phase-4-Health-and-Gym]] and
[[Phase-5-Screen-Time]] both add *more measurement* to an app that
already measures a lot. These two add the thing measurement cannot
reach — what I wrote and what I looked like — and they do it while the
data set is still small enough that the archive rewrite is cheap. Doing
this after two more phases of tables would mean rewriting the export
against twice the surface.

**Why together.** [[Notes]] and [[Gallery]] are separate features that
break the export in the same way: both are *files*, and the export is a
spreadsheet. Fixing that once, for both, is one job; fixing it twice is
two.

## The shape of the phase

```mermaid
flowchart LR
    A[M3.1 Notes] --> C[M3.3 Archive]
    B[M3.2 Gallery] --> C
    C --> D[M3.4 Import]
    D --> E[M3.5 Onboarding & release]
```

## M3.1 — Notes
- [ ] Schema: `notes` (uuid, title, folder, body, timestamps, `deletedAt`) and `note_links` (from, to-title, resolved uuid) — both outbox-wired like everything else
- [ ] Repository + a `NotesService` that keeps the link index in step with the body on every write
- [ ] The list: folders, search across title and body, sort by edited / created / title
- [ ] The editor: plain text, autosave debounced, no Save button
- [ ] The reader: markdown rendered — headings, emphasis, lists, task lists, quotes, code, links, `[[wiki links]]`
- [ ] A `[[link]]` to a note that does not exist is offered as *create it*, not shown as an error
- [ ] Backlinks: "what links here", as a list
- [ ] The feature switch, off by default, in Settings; the tab appears and disappears with it
- [ ] Tests: the link index against edited bodies, unresolved links, rename propagation, the search

## M3.2 — Gallery
- [ ] Schema: `albums` (uuid, name, `scheduleJson`, `remindAt`, timestamps) and `memories` (uuid, album, `harvestDay`, path, kind, note, timestamps)
- [ ] Capture and import: camera, and picking from the system gallery
- [ ] Downscale-on-import for images; a duration cap for video; files in the app's own storage
- [ ] Album view: grid, newest first, day on each; per-album storage shown
- [ ] **Play**: the album as a timelapse, one frame per memory, speed picked
- [ ] **Compare**: two memories side by side, first-and-latest by default
- [ ] Notes on a memory, and search across them
- [ ] **A scheduled album is a seed**: due on the field, checked in by adding a memory, feeding the streak and the XP ledger through the existing `CheckInService` rather than beside it
- [ ] The crop card for an album opens the camera instead of a quantity sheet
- [ ] Permissions requested when the feature is switched on, never at first launch
- [ ] Deleting a memory deletes the file
- [ ] The feature switch, off by default, in Settings
- [ ] Tests: the album-as-seed due rule, check-in through an added memory, the downscale, deletion actually deleting

## M3.3 — The archive becomes a zip
- [ ] `harvest.xlsx` unchanged inside the zip, plus `Notes` and `Memories` sheets ([[ADR-007-Archive-Format]])
- [ ] `notes/` written as an Obsidian-shaped vault; `gallery/<album>/` written as folders of files
- [ ] Safe filenames, with the real title kept in the sheet
- [ ] Progress reported and the export cancellable — this is now a slow operation and must not look like a hang
- [ ] Tests: the tree's shape, the round trip of an awkward title, a memory row pointing at the file that is actually there

## M3.4 — Import
- [ ] Read a Harvest zip: validate, then **preview** — how many rows and files, how many new, how many updates
- [ ] Merge by uuid: newer wins, absent rows are added, **nothing local is deleted for being missing**
- [ ] Files restored into app storage, rows repointed at them
- [ ] A failure part-way leaves the database as it was; the import is one transaction per table and a temp directory for files
- [ ] Tests: merge against a newer local row, against an older one, a corrupt zip, a zip from a future schema version

## M3.5 — Onboarding, settings and release
- [ ] Two questions in [[Onboarding]] — notes, gallery — both defaulting to no
- [ ] Both switches in Settings, with what turning off does and does not do said plainly
- [ ] Docs updated: the specs, [[Business-Rules]] #11, [[Core-Entities]], [[Local-Database]]
- [ ] `v1.1.0` tagged and installed

**Exit:** I write in it without reaching for another app, there is a
month of daily photos I can play as a run, and I have taken an archive
off this phone and put it back on a fresh install.

## Backlog (discovered during the phase)

*(nothing yet)*
