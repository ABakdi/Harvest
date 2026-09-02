# Checkpoint 1 — Road to v1

*Taken 2026-09-02, after closing phases 0–2 (v0.2.1).*

Stopping to look at the field before the final push. What grew well,
what's missing, what broke, and exactly what stands between here and
the v1 release.

## Where we are

- **Phase 0 (Foundation)** ✅ — toolchain, design system, l10n (en/ar + RTL),
  Drift with sync-ready schema, golden tests, migration harness, CI.
- **Phase 1 (Productivity core)** ✅ — commitments with 4 schedule types,
  check-ins with the 2× cap, streaks + freezes, XP/coins/ranks, 4 daily
  quests, pomodoro with shade controls, plan ritual + reminders,
  onboarding, stats. Fully verified on the emulator.
- **Phase 2 (Finances)** ✅ — expense quick-log (+edit in place), monthly
  budget with the floating daily limit gauge, smart repeats, weekly
  report, spending stats.

66→68 tests green, analyzer clean, everything pushed and tagged.

## Bugs found at this checkpoint

| # | Bug | Status |
| :- | :--- | :--- |
| B4 | Date pickers applied the 3 AM shift — picking Sep 2 stored Sep 1 for deadlines/planned days | Fixed: `HarvestDay.fromDate` for calendar dates, regression-tested |
| B5 | Smart repeats ignored currency — three days of \$5 would suggest logging DA5 | Fixed: currency is part of the repeat pattern |
| B1 | Overscroll stretches cards (Android stretch effect) — ugly deformation at list ends | **Fix planned** → gentle bounce physics app-wide |
| B2 | Pomodoro countdown notification not re-posted after process restart | Fixed in v0.2.1 |
| B3 | User-pause showed "Break over" copy | Fixed in v0.2.1 |

## Gaps to close before v1

| # | Gap | Plan |
| :- | :--- | :--- |
| G1 | No sign on the field that a focus session is running | Live ticking mini-timer chip in the field app bar, tap → timer |
| G2 | Pomodoro lengths are hardcoded | Settings card: focus / short break / long break / blocks per long break |
| G3 | No calendar | Month calendar populated from schedules: habits due, to-dos, project commitments, deadlines; day view + plant-on-that-day |
| G4 | Creating a seed has no advanced options | Note, remind-me-at time, and deadline on any seed; per-task reminders scheduled with the daily plan |
| G5 | Finances = today only; no savings picture | Granary tabs: **Today** / **Insights**; savings pot + expected daily spend; week/month breakdowns |
| G6 | Piggy-bank icon reads wrong | Money icons (wallet/payments) across nav, gauge, buttons |
| G7 | Palette feels dull; one look only | 5 vibrant theme presets (each with dark variant) with gradients: Harvest, Sunrise, Ocean, Orchard, Dusk — user-pickable |
| G8 | Expense categories are fixed | Custom categories with icon picker; manage in finance settings |
| G9 | No visual breakdown of spending | Charts: category donut + daily bars (week/month) |
| G10 | (=B1) overscroll stretch | Bounce physics |
| G11 | Feedback could be richer | Action animations (log/claim/check), status colors everywhere: over-budget red, low-savings warning, overdue deadlines |

## Decision log for this checkpoint

- **Charts:** fl_chart (most maintained Flutter chart lib).
- **Calendar:** table_calendar (battle-tested), themed to match.
- **Custom categories:** stored as a table (`expense_categories`), expenses
  keep a string key — presets stay built-in, customs layer on top.
- **Schema v4:** commitments gain `note`, `remindAt`, `deadline`;
  new `expense_categories` table.
- **Savings rule:** the savings pot is a manually-kept number (no auto
  transfer magic in v1); it warns when it drops below 10% of the
  monthly budget.
- **Theme presets:** tokens move from constants to per-preset palettes;
  gradients used deliberately (primary action, XP bar, gauges), never
  as wallpaper.

## Round 2 — dogfooding findings

Testing the v0.9.0 candidate by hand surfaced five more items:

| # | Finding | Plan |
| :- | :--- | :--- |
| P1 | Calendar marker dots get ugly past a few items | Replace dots with a small **count badge** |
| P2 | **Bug:** to-dos planted on a future date still show on today's field | Field filter must respect the planned day; regression test added |
| P3 | Deadlines are static text | Live countdown on the card: days → hours, and a **ticking clock** once 3 hours remain |
| P4 | Single-currency finances don't match reality | Default currency setting (DZD by default); every expense and savings pot carries its own currency (DZD / USD / EUR); one savings card per currency |
| P5 | No exchange rates | Rates in settings: DZD↔USD and DZD↔EUR entered manually, EUR↔USD fetched from the ECB (Frankfurter API); amounts show the default-currency conversion in parentheses; aggregates convert before summing |

Decisions: schema v5 adds `expenses.currency`; rates and per-currency
savings live in settings storage; conversion is best-effort — a missing
rate means no parenthetical and face-value aggregation, never a block
(local-first: the rate fetch is optional network, everything else works
offline).

## Round 3 — the vault

- **App icon**: real launcher identity at last — white sprout on a
  green gradient, adaptive on Android, generated for every density.
- **Vault tab** in the Granary: wallet (spend money), savings pots per
  currency (saved money), debts, and the full movement history.
  Savings withdrawals must choose a destination (wallet or logged
  expense); expenses offer to come out of the wallet; wallet
  withdrawals need no expense. Debts carry pay-off-by, notes and a
  daily reminder until settled. Schema v6: money_txns, debts,
  debt_payments — all outbox-wired.
- Daily quests removed (previous entry) — confirmed gone from the
  field.

## Round 4 — the look, and a vault that explains itself

Dogfooding v0.9.3 left two complaints: the app still looked like a
default Material scaffold, and the vault was confusing — one wallet
card, savings tiles, debts, then a single "Recent moves" list mixing
everything. Round 4 fixes both.

- **Design system pass** — one surface language set in the theme
  (layered cards with a hairline edge, filled pill inputs/chips/segments,
  rounded tab indicator, drag-handled sheets, floating snackbars) plus
  seven shared components (SectionHeader, HeroCard, StatTile, IconBadge,
  LedgerRow, HarvestFab, EmptyState) applied across Field, Granary,
  Stats and Settings. The golden gallery covers them in light/dark × LTR/RTL.
- **Vault restructured** — three tiles (Wallet / Savings / Owed) always
  showing totals; the selected section gets a hero card with per-currency
  balances and its actions, then its *own* ledger grouped by day. Debts
  show remaining, paid progress, and expandable payments.
- **Ledger rows explain themselves** — schema v7 adds `kind` +
  `reference` to `money_txns`: transfers name the other pot, expenses
  carry their category, debt payments name the person. Paying a debt can
  now come out of the wallet; saving can come from the wallet (a real
  transfer) or be new money.
- **Money entry** — one amount sheet (big number, currency pills, note)
  replaces the old dialogs; "which one?" prompts are option sheets with
  icons and the relevant balance as a hint. Savings withdrawals are
  capped at the pot.
- **Today tab** — status-tinted budget hero (spent today, daily limit,
  left/over today, month bar with left/over month), expense rows with
  swipe-to-remove, the expense FAB only where it belongs.
- Amounts are thousands-grouped everywhere.

## Scope change

Daily quests are **out of v1**: the card and its logic were removed
pending a redesign (the generated micro-quests weren't earning their
place). The schema keeps the table; streak milestones remain the coin
source. Quests come back when there's a proper idea for them.

## v1 release criteria

- [x] G1–G11 implemented and verified on the emulator (mini-timer chip,
      pomodoro settings, calendar, advanced options, granary tabs +
      savings warning + charts, money icons, 5 gradient themes, custom
      categories incl. delete-fallback, bounce physics, bursts and
      status colors — plus the over-budget red gauge caught live)
- [x] All tests green, analyzer clean, migrations v1→v4 verified
- [x] Dark pass done across new surfaces (all verification ran in dark); RTL re-verified at v0.2.1 and new screens use directional APIs only
- [x] Docs updated (specs reflect what shipped), phases ticked
- [x] Tagged v0.9.0 and release APK built
- [x] Round 2 findings P1–P5 closed — verified live: count badges,
      future to-dos off today (with regression test), deadline
      countdown widget, per-expense currency with parenthetical
      conversions aggregating into the gauge, manual DZD rates +
      fetched EUR→USD (API moved to frankfurter.dev — fixed)

Everything after this list is **v1.x / Phase 3+** territory (gym &
health, screen time, sync).
