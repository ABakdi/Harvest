# Phase 2 — Finances

Spec: [[Finances]]. Builds on a live MVP — money becomes the fourth daily tap.

## M2.1 — Expense logging
- [x] `expenses` table + repository (minor-unit integers) ([[Local-Database]])
- [x] Quick-log sheet: amount pad → category chips → optional note, < 5 s
- [x] Delete same-day entries (soft); append-only beyond
- [ ] Edit-in-place for same-day entries
- [x] +10 XP daily logging hook into [[Gamification]]

## M2.2 — Budget engine
- [x] Monthly budget setting; floating daily limit recomputed at 3 AM reset
- [x] 🟢🟡🔴 GaugeRing on the Field
- [x] Month rollover handling (new month, new budget instance)

## M2.3 — Smart repeats
- [x] 3-days-running detector → day-4 one-tap confirm card

## M2.4 — Reminders & reporting
- [x] Evening check-in notification (configurable time) with suppression ([[Notifications]])
- [x] Category breakdown in stats (biggest first)
- [ ] Weekly Harvest Report card (whole report still pending from Phase 1 scope)
- [x] Finance daily-quest templates enabled

**Exit:** a full month logged; gauge honest; `v0.2.0`.
