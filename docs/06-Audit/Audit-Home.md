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

Updated as fixes land. IDs refer to the reports.

| Area | Fixed | Deferred (with reason) |
| :--- | :--- | :--- |
| Security | _in progress_ | S-04 SQLCipher: next milestone, needs a keystore-backed key and a migration path for existing databases |
| Code quality, part 1 | _in progress_ | |
| Code quality, part 2 | _in progress_ | |
| UX | _in progress_ | |
