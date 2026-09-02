# Local Database — Drift

Decision record: [[ADR-002-Local-Database]]. Drift (SQLite) is the single source of truth on device.

## Principles

- **Money as integers** (minor units), **times as UTC + timezone name**, **Harvest Day as a date column** computed at write time ([[Business-Rules]]).
- **Append-only history:** check-ins, expenses, sleep sessions are never hard-deleted; commitments soft-delete via `archivedAt`.
- **Sync-ready from day one:** every row carries `uuid` (client-generated, the future Mongo `_id`), `updatedAt`, and `deletedAt`; every local write also appends to the `outbox` table ([[Sync-Strategy]]). Cheap now, priceless later.

## Schema v1 (Phase 1)

```mermaid
erDiagram
    commitments ||--o{ check_ins : has
    commitments {
        text uuid PK
        text type "habit|project|todo"
        text title
        text scheduleJson
        int totalTarget
        int dailyCommitment
        text dueDay
        datetime archivedAt
        datetime updatedAt
    }
    check_ins {
        text uuid PK
        text commitmentUuid FK
        text harvestDay
        int quantity
        datetime loggedAt
    }
    streaks {
        text scope PK "global or commitment uuid"
        int current
        int best
        text lastEarnedDay
    }
    ledger {
        text uuid PK
        text kind "xp|coin"
        int delta
        text reason
        text harvestDay
    }
    quests {
        text uuid PK
        text harvestDay
        text templateId
        int progress
        int target
        datetime claimedAt
    }
    pomodoro_sessions {
        text uuid PK
        text commitmentUuid
        int focusBlocks
        text harvestDay
    }
    outbox {
        int seq PK
        text tableName
        text rowUuid
        text op
        datetime queuedAt
    }
    settings {
        text key PK
        text valueJson
    }
```

XP and coins are a **ledger**, not a counter — balances are sums, history is free, and sync conflicts become trivial merges.

Later phases add tables without touching these: `expenses`, `budgets` (Phase 2); `sleep_sessions`, `workout_plans`, `workout_sessions` (Phase 3); `screen_goals`, `usage_days` (Phase 4).

## Migrations

Drift's stepwise migrations, tested with its schema-verification tooling. Every schema change lands with a migration test before merge. Schema history: v6 added `money_txns`, `debts`, `debt_payments`; v7 added `money_txns.kind` + `reference` so each movement records why it happened (manual / transfer / expense / debt) and what it relates to.
