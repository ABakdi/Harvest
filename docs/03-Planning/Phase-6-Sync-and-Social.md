# Phase 6 — Sync, Social & Platform Reach

Spec: [[Sync-Strategy]]. The local-first core goes multi-device and lightly social.

## M6.1 — Sync server
- [ ] API service (MongoDB) : auth, batch push/pull by cursor, upsert-by-uuid
- [ ] Client: outbox drain, pull-merge, conflict policy (append-union / LWW)
- [ ] E2E encryption for expenses; sleep/screen sync as aggregates only
- [ ] Two-device convergence test suite

## M6.2 — Accounts & rankings
- [ ] Optional account (app remains fully usable without — [[Business-Rules]] #5)
- [ ] Pseudonymous leaderboards on XP/streak aggregates
- [ ] Weekly Harvest Report share card

## M6.3 — Reach
- [x] ~~Home-screen widget: compact~~ — **shipped early in [[Checkpoint-3]]**; nothing about a widget needed a sync server
- [ ] Home-screen widget: medium "Vitality" ([[Dashboard-and-Widgets]]) — waits on the pillars behind its gauges
- [ ] iOS release pass: Screen Time API enforcement, BGTaskScheduler tuning, alarm strategy
- [ ] Web dashboard ("The Field" grid + keyboard quick-log)

## Later ideas (unscheduled)
- Social guilds (2–5 people), soundscapes, insights coach ([[Product-Requirements]] §7)
