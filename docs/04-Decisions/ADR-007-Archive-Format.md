# ADR-007 — The archive is a zip, and it comes back

**Status:** Accepted · 2026-09-05 · supersedes part of
[[ADR-006-Export-Format]] · [[Phase-3-Notes-and-Gallery]]

## Context

[[ADR-006-Export-Format]] settled the export as a single `.xlsx`
workbook, and the reasoning holds for everything it was written about:
rows of numbers belong in a spreadsheet, and a spreadsheet with live
formulas is a working document rather than an archive.

[[Notes]] and [[Gallery]] break that in two places.

**A note is a file, not a row.** Putting markdown in a spreadsheet cell
would take something already portable and make it less so.

**A photo is not a row at all.** Base64 in a cell is not an export, it
is a hostage situation.

And there is a second, older gap. [[Checkpoint-2]] admitted it plainly:
*"The spreadsheet is a readable record, not a restore — there is no
importer yet."* Four releases of my data have depended on this phone
not being lost. Adding files to the export without adding a way to put
them back would be adding weight to that problem.

## Decision

**One `.zip`, holding the workbook and the files, and an importer that
reads it back.**

```
harvest-2026-09-05-1430.zip
├── harvest.xlsx          the workbook, unchanged (ADR-006)
├── notes/
│   ├── Reading.md
│   └── Health/
│       └── Sleep log.md
└── gallery/
    ├── Gym/
    │   ├── 2026-09-01.jpg
    │   └── 2026-09-05.jpg
    └── Face/
        └── 2026-09-05.jpg
```

The rules that make it an archive rather than a dump:

1. **The workbook is unchanged.** Every rule in
   [[ADR-006-Export-Format]] still applies to it, and it gains three
   sheets — `Notes`, `Albums` and `Memories` — carrying the rows behind
   the files. `Memories` is the sheet that says which file belongs to
   which album, on which day, with which note: **the file tree is
   browsable, and the sheet is the index.** `Albums` is there because a
   folder of pictures cannot say what an album's *schedule* was, and an
   album without its schedule comes back as a shoebox rather than a
   seed.
2. **Notes come out as an Obsidian vault.** `notes/` is the folder
   structure the app shows, with one `.md` per note named by its title.
   Nothing about it needs Harvest to be readable.
3. **Gallery comes out as folders of pictures.** One folder per album,
   files named by their day. Somebody who has never heard of this app
   can open the zip and understand it.
4. **Filenames are made safe, and the sheet keeps the real name.** A
   note called `Q4: what now?` cannot be a filename on every platform;
   the sheet holds the title, the file holds a sanitised version, and
   the import puts the title back.
5. **Import is by uuid, and it never destroys.** Rows already present
   are updated where the incoming copy is newer, absent rows are added,
   and nothing local is deleted because it was missing from the
   archive. An import is a merge, not a restore-over.
6. **Import is previewed.** Before anything is written I am told what
   is about to happen — how many seeds, check-ins, notes and files, how
   many are new and how many are updates — and I can stop.

## Consequences

**Good.** The data finally has a second home it can come back from.
The zip is browsable without the app, the workbook still opens in
Google Sheets with its formulas live, and the notes folder is a vault.
Moving to a new phone stops being a loss.

**The cost.** A zip is not a spreadsheet: a phone with five years of
daily photos produces an archive measured in hundreds of megabytes, and
writing it takes real time. The export therefore reports progress and
can be cancelled, and the gallery downscales on import
([[Gallery]] rule G4) precisely so this number stays sane.

**Still not decided here.** The archive is **not encrypted**, exactly
as before. It lands in Downloads because that is where I asked for it,
and it is a backup I take deliberately rather than a channel. Financial
privacy ([[Business-Rules]] #6) still applies to what leaves the device
automatically — which is nothing.

**Deliberately not done.** No cloud, no sync, no account. That is
[[Phase-6-Sync-and-Social]], and the whole point of getting the archive
right first is that Phase 6 then has a shape to write into rather than
one to invent.
