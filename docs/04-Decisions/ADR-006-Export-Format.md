# ADR-006 — The export workbook is the backup format

**Status:** Accepted · 2026-09-04 · [[Checkpoint-2]]

## Context

Every byte Harvest holds lives on one phone. [[Sync-Strategy]] puts a
second home for it in Phase 5, behind an outbox and a server I have not
written. Until then a lost phone is a lost year.

I wanted a way to get the data out that I could use *today*, and that
would not have to be thrown away when sync arrives. Two things it had to
be: readable by me without any Harvest code, and specific enough to be
the thing a "sync to a Google Sheet" feature writes later.

The alternatives were:

- **CSV per table.** Trivial to write, trivial to read, and dead — no
  cross-table totals, and one file per table to keep together.
- **A JSON dump.** Faithful and machine-friendly, but I cannot open it
  on a Sunday and see what I spent on food in August.
- **An `.xlsx` workbook.** Google Sheets imports it with formulas
  intact, which is the whole point.

## Decision

**One `.xlsx` workbook, one sheet per table, plus a Summary sheet whose
every number is a formula over the others.**

The rules that make it a contract rather than a dump:

1. **Sheet names and column headers are English and fixed**, in both app
   languages. A backup format that shifts with the UI language is not a
   format. `Expenses!AmountMinor` means the same thing in every export.
2. **Money is stored in minor units**, exactly as the database keeps it,
   with the decimal alongside as a formula (`=E2/100`). The integer is
   the value of record; the decimal is a convenience that a spreadsheet
   recomputes.
3. **Timestamps are ISO-8601 text.** Serial dates are a guessing game
   across Excel, Sheets and LibreOffice; text sorts correctly and reads
   the same everywhere.
4. **Soft-deleted rows are exported**, with their `deletedAt` intact. A
   backup that silently drops rows is a worse backup than none, because
   it looks complete.
5. **Derived columns are formulas, not values.** A debt's `Remaining` is
   `Amount − Paid`, and `Paid` is a `SUMIFS` over `DebtPayments`. Log a
   payment in the sheet and the number moves.
6. **The Summary computes nothing in Dart.** Row counts are `COUNTA`,
   totals are `SUMIFS`, the month breakdown is a `SUMPRODUCT` over a
   range bounded at the real last row.

## Consequences

**Good.** The file is a working spreadsheet, not an archive. Editing it
is a legitimate thing to do, and the totals follow. When sync arrives it
writes these same tabs into a real Google Sheet, and the shape is
already settled and already tested.

**The cost.** Formula strings are load-bearing, and a column inserted in
the wrong place would quietly point a `SUMIFS` at the wrong data. That
is why the builder resolves `{ColumnName}` placeholders against the
sheet's own headers instead of hardcoding letters, and throws on a name
it does not recognise — a wrong reference is a failing test, not a wrong
number in a file I trusted.

**Also.** `excel` (pure Dart) over `syncfusion_flutter_xlsio`: formula
support is the only thing I need from a writer, and it comes with no
licence question. It pins `xml` to 6.x, which nothing else here minds.

**Not decided here.** The workbook is not encrypted and it lands in a
folder any app with storage access can read. It is a backup, not a safe.
Encryption at rest is still S-04's problem, and the [[Checkpoint-2]] app
lock guards the app, not the export.
