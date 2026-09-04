# Audit — Home

*Started 2026-09-03 on the round-5 tree. Three read-only reviews, then a remediation pass. This page is the index and the status board; the reports hold the evidence.*

I stopped adding features to look hard at what was already there: is the app secure, is the code the quality I want to keep building on, and is every screen clear? Three reports came out of it:

- [[Security-Audit]] — Android surface, data at rest, backups, notifications, the one network call, inputs, secrets, signing.
- [[Code-Quality-Audit]] — correctness (3 AM boundary, DST, atomicity), error handling, Riverpod use, duplication, dead code, structure, accessibility, tests. Two parts: core/productivity and finances/settings/UI.
- [[UX-Audit]] — every screen, component by component: keep, simplify, merge or remove; the 15 highest-value changes; strings to rename.

## How the audit was run

Each report was produced by reading the source and the specs, quoting the exact lines, and checking claims against the toolchain (`flutter analyze`, `dart format --set-exit-if-changed`, the test suite) and the installed plugins' own code where behaviour was in doubt. Nothing was changed while auditing. Every finding has an ID, a severity, file and line, why it matters here, and a concrete fix.

## Counts

| Report | Critical | High | Medium | Low | Info |
| :--- | :---: | :---: | :---: | :---: | :---: |
| Security (S-01 … S-13) | 0 | 2 | 4 | 4 | 3 |
| Code quality, part 1 (Q-01 … Q-54) | – | 5 | 27 | 22 | – |
| Code quality, part 2 (F-01 … F-46) | – | 3 | 14 | 29 | – |
| UX (U-01 … U-15 + per-screen tables) | – | – | – | – | – |

## Remediation plan

Three waves, in this order, each ending with analyzer clean, tests green and a live check on the emulator.

1. **Platform and security** — backup exclusion, lock-screen exposure, private notification content, rate validation, release signing and shrinking, input caps, purge of soft-deleted rows, background-job hardening, reminder settings that show every reminder the planner schedules.
2. **Core correctness** — a live current-day provider so nothing freezes at 3 AM, calendar-safe Harvest Day math, atomic check-ins and freeze purchases, honest undo, pause judging, planner day alignment, pomodoro single clock and attached crop, onboarding skip, planner tests against a fake gateway.
3. **Finances and UX** — one transaction per money flow with the expense linked to its wallet move, live debt cards, wallet toggles inside the amount sheets instead of follow-up questions, budget card and settings reorganised, duplicates removed from Stats, dead strings and dead settings gone, tooltips and semantics everywhere, formatting normalised across the tree.

## Status

All three waves landed, each verified with the analyzer clean, the full
suite green, and the changed screens driven by hand on the emulator.
IDs refer to the reports.

| Area | Done | Deferred, and why |
| :--- | :--- | :--- |
| Security | S-01 backups off with extraction rules · S-02 lock-screen flags removed · S-03 private notification visibility, debts quote what is owed · S-05 rate validation on both paths, injectable client · S-06 real signing config, shrinking, obfuscation documented · S-07 amount cap · S-08 length limits · S-09 tolerant payload decoding · S-10 30-day purge, privacy tier documented · S-11 exact-alarm permissions narrowed · S-12 specific exceptions and a visible startup error · S-13 toolchain pinned | **S-04 (SQLCipher)** — encryption at rest needs a keystore-backed key and a migration for existing databases; it is the next milestone now that the data no longer leaves the device. [[Checkpoint-2]]'s app lock landed in the meantime: it stops the person holding the phone, which is the common case, but it is a shield and not encryption — someone with the file still reads it, so S-04 stays open |
| Code quality, part 1 | Q-01 live day provider · Q-02 calendar-safe arithmetic · Q-03 planner day alignment · Q-04 3 AM job · Q-05 tolerant parsing · Q-07 atomic check-in · Q-08 soft-delete undo with reversing XP · Q-09 pause judging · Q-10 guarded freeze purchase · Q-11 honest last-earned day · Q-13 idle fast path · Q-15/Q-16 isolated startup steps and specific exceptions · Q-17 one due rule · Q-18 debt amounts · Q-19 permission only on a new time · Q-20 channel names · Q-22 route constants · Q-23 background job hardening · Q-24/Q-25/Q-29/Q-30/Q-31/Q-32 controller state and one clock · Q-26 view providers moved · Q-33 skip plants nothing · Q-34 failure feedback · Q-35 tolerant habits · Q-36 memoized calendar · Q-38 clear flags · Q-40 typed settings · Q-41/Q-45 strings · Q-46/Q-48 tooltips and targets · Q-49/Q-50/Q-51/Q-52 planner, pomodoro and streak tests · Q-53 golden artifacts untracked | **Q-13 deep history**, **Q-44 SQL aggregates** — both are performance work that only bites at a scale I am nowhere near; revisit with real data. **Q-39 layering** partly done (planner uses a gateway, budget colours moved); the remaining feature-to-feature imports are a refactor, not a defect |
| Code quality, part 2 | F-01 live debts · F-02 linked expenses · F-03 no ref after pop · F-04 day-keyed providers · F-05 wallet caps · F-06 payment validation · F-07 zero-limit budget · F-08 money parsing and formatting · F-09 rate sanity · F-14 guarded writes · F-19/F-20/F-23 shared providers and helpers · F-24 one sheet body · F-30…F-35 dead code and strings · F-39 delete with undo · F-41 semantics · F-45 the missing tests | **F-25/F-26/F-29 widget extraction** and **F-36 file splits** — the flows moved behind a service, which was the point; splitting the remaining files is cosmetic and can ride along with the next feature |
| UX | U-01 wallet toggle instead of four question sheets · U-02 withdrawals land in the wallet · U-03 dead setting gone · U-04 Money section in Settings · U-05 Stats duplicates gone · U-06 simplified budget card · U-07 every reminder visible and named · U-08 coins labelled with an earn hint · U-09 tooltips and an overflow button · U-10 deadlines for projects only · U-11 undo · U-12 pomodoro flows · U-13 calendar · U-14 onboarding skip · U-15 renames | Barn wording is now Archive everywhere, but there is still no screen listing archived seeds. That is a feature, not a fix — noted for the backlog |

## What came out of it beyond the reports

Verifying the fixes on the device turned up three more, all fixed:

- Gating the first frame on the whole of startup meant a wedged platform
  channel could leave a blank screen forever. Only the day's verdict is
  awaited now; everything else runs behind the first frame.
- A background startup step finishing after the app was gone wrote to a
  disposed container.
- The expense sheet overflowed with the keyboard up once it gained the
  wallet switch, and the note field showed a character counter.

That last one turned out to be one instance of a pattern, so I went
through every screen the keyboard can reach on a 360x640 phone:

- The **calendar** overflowed by 122 px the moment I tapped its quick-add
  field. A fixed-height month grid above an `Expanded` list cannot fit a
  body the keyboard has shrunk, and the field I was typing into was
  squeezed to nothing. The body is one scroll view now.
- **`HarvestSheet`** had a `scrollable` flag, and the sheets that turned
  it off were exactly the ones that broke. The flag is gone: the body
  always scrolls, and it reserves the keyboard *and* the gesture bar
  (`MediaQuery` zeroes the padding an inset already covers, so the two
  never stack). Dragging the form now dismisses the keyboard.
- The **wallet amount sheet** had no scroll view at all — it grew a
  currency row, a cap hint, a wallet switch and a note, and simply ran
  off the bottom. It, the **debt sheet** and the **seed editor** were
  each carrying their own copy of the padding-and-scroll code; all three
  are `HarvestSheet` now, and every sheet opens through
  `showHarvestSheet`, which adds `useSafeArea` so a tall form stops at
  the status bar instead of running under it.
- The **streak**, **crop options** and **choice** sheets had no safe area
  or no scroll, so their last row sat under the gesture bar at a large
  text scale. The **new-category dialog** stacked a 20-icon grid on top
  of a focused text field; its body scrolls now.

`test/core/harvest_sheet_test.dart` pins the rules — never overflow,
never leave the confirm button under the keyboard or the gesture bar —
and two of its five cases fail against the old sheet.
