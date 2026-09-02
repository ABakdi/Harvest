# Phase 5 — Sync, Social & Platform Reach

Spec: [[Sync-Strategy]]. The local-first core goes multi-device and lightly social.

## M5.1 — Sync server
- [ ] API service (MongoDB) : auth, batch push/pull by cursor, upsert-by-uuid
- [ ] Client: outbox drain, pull-merge, conflict policy (append-union / LWW)
- [ ] E2E encryption for expenses; sleep/screen sync as aggregates only
- [ ] Two-device convergence test suite

## M5.2 — Accounts & rankings
- [ ] Optional account (app remains fully usable without — [[Business-Rules]] #5)
- [ ] Pseudonymous leaderboards on XP/streak aggregates
- [ ] Weekly Harvest Report share card

## M5.3 — Reach
- [ ] Home-screen widgets: compact + Vitality ([[Dashboard-and-Widgets]])
- [ ] iOS release pass: Screen Time API enforcement, BGTaskScheduler tuning, alarm strategy
- [ ] Web dashboard ("The Field" grid + keyboard quick-log)

## Later ideas (unscheduled)
- Social guilds (2–5 people), soundscapes, insights coach ([[Product-Requirements]] §7)
