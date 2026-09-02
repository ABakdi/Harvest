# Phase 2 — Finances

Spec: [[Finances]]. Builds on a live MVP — money becomes the fourth daily tap.

## M2.1 — Expense logging
- [ ] `expenses` table + repository (minor-unit integers) ([[Local-Database]])
- [ ] Quick-log sheet: amount pad → category chips → optional note, < 5 s
- [ ] Edit/delete same-day entries; append-only beyond
- [ ] +10 XP daily logging hook into [[Gamification]]

## M2.2 — Budget engine
- [ ] Monthly budget setting; floating daily limit recomputed at 3 AM reset
- [ ] 🟢🟡🔴 GaugeRing on the Field
- [ ] Month rollover handling (new month, new budget instance)

## M2.3 — Smart repeats
- [ ] 3-days-running detector → day-4 one-tap confirm card

## M2.4 — Reminders & reporting
- [ ] Evening check-in notification (configurable time) with suppression ([[Notifications]])
- [ ] Category breakdown in stats; biggest-category line in the weekly report
- [ ] Finance daily-quest templates enabled

**Exit:** a full month logged; gauge honest; `v0.2.0`.
