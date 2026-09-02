# Phase 3 — Gym & Health

Spec: [[Health-and-Gym]]. Soil health (sleep) and training.

## M3.1 — Sleep targets & alarm
- [ ] Target bedtime/wake settings
- [ ] Gradual-volume exact alarm with full-screen intent ([[Notifications-and-Background]])
- [ ] `SCHEDULE_EXACT_ALARM` permission flow
- [ ] Wind-down notification tied to target bedtime

## M3.2 — Morning retrospective & sleep debt
- [ ] Alarm-dismiss retrospective card (fell-asleep slider, wake time, 1–5 stars)
- [ ] `sleep_sessions` table; minute-for-minute debt engine ([[Business-Rules]])
- [ ] Debt gauge on the Field; +15 XP log hook; sleep quests enabled

## M3.3 — Workout plans
- [ ] Plan builder: routines with exercises × sets × reps/duration
- [ ] Plan ↔ habit binding (session completion = habit check-in)

## M3.4 — Workout sessions & progress
- [ ] Guided session flow with per-set logging, fast and offline
- [ ] Exercise history: best set, volume trend
- [ ] Optional daily body-weight log + chart

**Exit:** Harvest is my alarm clock and gym log; `v0.3.0`.
