# Phase 4 — Screen Time (Android)

Spec: [[Screen-Time]]. The hardest platform work — scheduled late deliberately, once the habit loop is proven. iOS enforcement lands in Phase 5 alongside iOS polish.

## M4.1 — Usage tracking
- [ ] Usage Access permission flow with explainer (opt-in, on module enable)
- [ ] UsageStats polling service + `usage_days` aggregation table
- [ ] Distracting-apps picker; total + per-app caps

## M4.2 — Weed-pull interventions
- [ ] 50% warning notification
- [ ] Overlay permission flow; 100% blocking overlay with 5-second escape hold ([[Business-Rules]] #7)
- [ ] Live remaining-minutes countdown on capped apps

## M4.3 — Integration
- [ ] Under-cap +20 XP at day close; screen-time quests enabled
- [ ] Doomscrolling journal (evening yes/no) → weekly report
- [ ] Optional app-block during [[Pomodoro]] focus sessions
- [ ] Screen gauge on the Field; most-used category in weekly report

**Exit:** one full week of reliable caps on my device; `v0.4.0`.
