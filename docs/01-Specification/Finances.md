# Financial Granary — Expense Tracking

Phase 2 module ([[Phase-2-Finances]]). Money is a pillar like any other: log it daily, keep the gauge green, earn the XP.

## Layout

The Granary has three tabs: **Today** (gauge, quick-log, today's
entries), **Vault** (wallet, savings, debts, movement history), and
**Insights** (daily bar chart + category donut, week/month, totals
and per-day average).

## The Vault

- **Wallet** — money meant to be spent. Add and take freely; taking
  without logging an expense is allowed.
- **Savings** — money meant to be saved, one pot per currency, each on
  its own card. A withdrawal must land somewhere: **to the wallet** or
  **logged as an expense** — the prompt always asks. Total savings
  (converted) below 10% of the monthly budget turns the cards red.
- **Every movement is a row** — balances are sums over the signed
  transaction history, shown as "Recent moves".
- Logging an expense asks **"Take it from the wallet?"** — yes creates
  the matching wallet withdrawal.
- **Debts** — an amount owed to someone (no interest), with an optional
  pay-off-by day, a note, and a remind-me-at time. Unsettled debts nag
  **daily** (19:00 default) until fully paid; partial payments
  accumulate and full payment settles with a small celebration.

An **expected daily spend** records intent next to the computed
floating limit.

## Quick-log

The whole point is a **sub-5-second log**:
- **Amount** (numeric pad first)
- **Category** — preset chips (Food, Transport, Bills, Shopping, Health, Entertainment, Other) plus **custom categories**: create one inline with a name and an icon from the registry; manage (delete) them in the budget sheet
- Optional merchant/note

Stored as integer minor units (cents) — never floats. Multi-currency is out of scope for V1; a single currency is chosen in settings.

## Smart repeats

If the same amount+category (e.g., "Coffee — $5, Food") appears 3 days running, day 4 pre-fills it as a 1-tap confirm card.

## Budget logic

- I set a **Monthly Budget**.
- **Floating Daily Limit** = remaining budget ÷ remaining days in the month — recomputed at each 3 AM reset ([[Business-Rules]]).
- A real-time gauge: 🟢 under · 🟡 within 15% · 🔴 over.

```mermaid
flowchart LR
    B[Monthly budget] --> C[Remaining budget]
    E[Today's expenses] --> C
    C --> F["Floating limit = remaining ÷ days left"]
    F --> G{Today vs limit}
    G -->|under| Green[🟢]
    G -->|close| Yellow[🟡]
    G -->|over| Red[🔴]
```

## Reminders & rewards

- Evening check-in notification (default 8 PM, configurable), suppressed once logged ([[Notifications]]).
- +10 XP for logging the day's expenses; budget-related daily quests ([[Gamification]]).

## Privacy — non-negotiable

Financial data **never leaves the device** in plaintext. Local-only in Phases 2–4; when [[Phase-5-Sync-and-Social]] arrives, expense records sync end-to-end encrypted or stay local by choice. Never sold, never shared. See [[Business-Rules]].
