# Product Requirements — Harvest

**Version:** 2.0 · **Platforms:** Android first, iOS next, Web later (Flutter) · **Tagline:** *Cultivate your day. Harvest your potential.*

This is the consolidated PRD. Each section links to the detailed spec note that owns it.

## 1. Summary

Harvest turns personal development into an engaging daily ritual. Inspired by Duolingo's behavioral psychology, it replaces the anxiety of doomscrolling with the satisfaction of cultivating. Four pillars — **Productivity**, **Finances**, **Health** and **Focus** — feed one unified gamification engine. Full background in [[Vision]].

## 2. Core entities

Six entities structure everything (full spec: [[Core-Entities]]):

| Entity | Type | Example | End-state |
| :--- | :--- | :--- | :--- |
| **Project** | Finite | "Read *Atomic Habits* (305 pages)" | Completed at 100% |
| **Habit** | Recurring | "Exercise", "Practice Spanish" | Perpetual, streak-tracked |
| **To-Do** | One-off | "Call the dentist" | Checked off |
| **Sleep Session** | Daily | Target 11 PM–7 AM, actual logged | Logged → sleep debt |
| **Screen Goal** | Daily | Social media ≤ 45 min/day | Resets daily |
| **Expense Entry** | Daily | $15 lunch, Food category | Logged → budget |
| **Note** (P3) | Free | "What I want from this year" | Kept, linked, searchable |
| **Album** (P3) | Recurring | "Gym — every Monday" | Perpetual; a memory a day, played back |

## 3. Modules

| Module | Owns | Spec |
| :--- | :--- | :--- |
| Productivity Engine | Projects, Habits, To-Dos, daily plan ritual | [[Productivity-Engine]] |
| Pomodoro | Focus timer attached to tasks | [[Pomodoro]] |
| Gamification | Streaks, XP, coins, quests, ranks | [[Gamification]] |
| Financial Granary | Expenses, budgets, floating limit | [[Finances]] |
| Health (Sleep Sanctuary + Gym) | Alarm, sleep debt, workouts | [[Health-and-Gym]] |
| Focus Field | Screen caps, weed-pull interventions | [[Screen-Time]] |
| Notifications | Gentle-to-urgent escalation | [[Notifications]] |
| Dashboard & Widgets | Today view, weekly report, home-screen widgets | [[Dashboard-and-Widgets]] |
| Notes (Phase 3) | Markdown notes with links between them | [[Notes]] |
| Gallery (Phase 3) | Photo albums that are seeds; the daily picture, played back | [[Gallery]] |
| Onboarding | Templates, Daily Harvest Goal setup, the two opt-ins | [[Onboarding]] |

## 4. Immutable rules

Day reset at 3 AM, over-log cap at 2×, minute-for-minute sleep-debt payment, on-device financial data — all defined once in [[Business-Rules]].

## 5. Technical foundation

- **Framework:** Flutter — Android first, iOS after the MVP proves itself, Web dashboard later.
- **State:** Riverpod ([[ADR-001-State-Management]]).
- **Storage:** Drift/SQLite, strictly local-first ([[ADR-002-Local-Database]], [[Sync-Strategy]]).
- **UI:** Material 3 + custom Harvest design system, dark & light themes ([[Theming-and-Design-System]]).
- **Languages:** English and Arabic with full RTL ([[Localization]]).
- **Background work:** local notifications, exact alarms, 3 AM reset job ([[Notifications-and-Background]]).

## 6. Delivery

Built in phases — productivity core first (MVP), then finances. That
reached **v1.0**. Next comes what a number cannot hold — notes and the
gallery, with the archive rewritten around them — and then gym &
health, screen time, and sync. Details and milestones in the
[[Roadmap]].

## 7. Later (post-V1)

- **Server sync + rankings** on MongoDB — [[Phase-6-Sync-and-Social]]
- **Social guilds:** 2–5 person accountability groups with anonymous streak visibility
- **Soundscapes:** unlockable ambient nature audio for focus sessions
- **Insights coach:** weekly personalized summaries correlating sleep, screen and spending data
