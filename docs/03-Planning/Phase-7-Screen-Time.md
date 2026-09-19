# Phase 7 — Screen Time (Android)

Spec: [[Screen-Time]]. The hardest platform work — scheduled late deliberately, once the habit loop is proven. It was Phase 5 until 2026-09-19, when the web app and sync went ahead of it ([[Roadmap]]). iOS enforcement lands in [[Phase-8-Social-and-Reach]] alongside iOS polish.

## M7.1 — Usage tracking
- [ ] Usage Access permission flow with explainer (opt-in, on module enable)
- [ ] UsageStats polling service + `usage_days` aggregation table
- [ ] Distracting-apps picker; total + per-app caps

## M7.2 — Weed-pull interventions
- [ ] 50% warning notification
- [ ] Overlay permission flow; 100% blocking overlay with 5-second escape hold ([[Business-Rules]] #7)
- [ ] Live remaining-minutes countdown on capped apps

## M7.3 — Integration
- [ ] Under-cap +20 XP at day close
- [ ] Doomscrolling journal (evening yes/no) → weekly report
- [ ] Optional app-block during [[Pomodoro]] focus sessions
- [ ] Screen gauge on the Field; most-used category in weekly report

**Exit:** one full week of reliable caps on my device; `v3.1.0`.
