# Phase 1 — Productivity Core (MVP) 🎯

The product. When this phase ends I should *prefer opening Harvest to keeping my Duolingo streak*. Specs: [[Productivity-Engine]] · [[Gamification]] · [[Pomodoro]] · [[Notifications]].

## M1.1 — Commitments
- [x] Create/edit/archive Habits (all four schedule types), Projects (target + daily commitment), To-Dos (optional due day)
- [x] Schedule engine: "what is due on Harvest Day X?" — pure Dart, heavily unit-tested
- [x] Vacation-mode pause for habits

## M1.2 — Check-ins
- [x] One-tap check-in for habits/to-dos with undo (same day)
- [x] Quantity sheet for projects; 2× over-log cap enforced ([[Business-Rules]])
- [x] Haptic + sprite celebration; project 100% completion moment
- [x] Append-only history, archive-safe

## M1.3 — The Field (dashboard v1)
- [x] Today view: due commitments as CropCards, urgency-ordered ([[Dashboard-and-Widgets]])
- [x] Streak flame + XP bar header
- [x] Pull-down: tomorrow's plan view

## M1.4 — Streak engine
- [x] Global Streak from Daily Harvest Goal; individual streaks per habit/project
- [x] 3 AM reset job real implementation: streak evaluation, freeze auto-consumption ([[Business-Rules]])
- [x] Lazy idempotent reconciliation on app open (multi-day gaps handled)
- [x] Streak milestones (7/30/100) with coin rewards

## M1.5 — XP, coins, quests
- [x] Ledger-based XP + coins; Farmer Ranks every 1,000 XP ([[Gamification]])
- [x] Streak Freeze store item (max 2 held)
- [x] Daily quest generator (4/day from template pool) + claim flow

## M1.6 — Daily plan ritual
- [x] Evening planner flow (from wind-down notification deep link)
- [x] Morning review/catch-up flow (morning reminder deep-links to the field)
- [x] Prime-time learning (median of last 14 first-check-ins) ([[Notifications]])

## M1.7 — Pomodoro
- [x] Timer with configurable blocks, attached to commitments ([[Pomodoro]])
- [x] Persistent notification with countdown; wall-clock timekeeping
- [x] Notification actions (pause/abandon from the shade)
- [x] Session → check-in handoff; +5 XP; session history

## M1.8 — Notifications v1
- [x] Full daily plan scheduling at reset; suppression on completion
- [x] Gentle→urgent escalation incl. late streak-risk nudge; 4/day cap
- [x] Per-category mute settings

## M1.9 — Onboarding & release
- [x] Onboarding flow with Phase-1 templates ([[Onboarding]])
- [x] Stats v1: per-commitment heat-map, project burn-up
- [x] Settings: language, theme, Daily Harvest Goal, all reminder times (fully configurable)
- [x] `v0.1.0` tagged, installed on my phone — **dogfooding begins**

## Backlog (discovered during the phase)
- (cleared — everything shipped; the check-in celebration is a code-drawn
  leaf burst rather than Lottie/Rive assets, which can still upgrade later)
