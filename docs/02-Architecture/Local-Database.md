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

Later phases add tables without touching these: `expenses`, `budgets` (Phase 2); `notes`, `note_links`, `albums`, `memories` (Phase 3); `sleep_sessions`, `workout_plans`, `workout_sessions` (Phase 4); `screen_goals`, `usage_days` (Phase 5).

**Phase 3 is the first time a row points at a file.** A note's body is
text in the database, but a memory is a path into the app's own
storage. Two consequences worth settling before the code: a memory's
delete is a **hard** delete, because a photo asked to be gone must be
gone; and the archive stops being a spreadsheet, because a photo in a
spreadsheet cell is not an export ([[ADR-007-Archive-Format]]).

`seed_notes` (v9) hangs off `commitments` the way `check_ins` does — one row per seed per Harvest Day, holding what I wrote about it that day ([[Checkpoint-3]]).

`notes` and `note_links` (v10) are the vault. The body is the truth and
the link table is derived from it, rebuildable at any time — which is
what lets an import restore bodies and then reindex rather than
carrying a link table across ([[Notes]] rule N2).

`albums` and `memories` (v10) are the gallery. `memories.path` is
**relative** to the app's gallery directory, so the storage root moving
between installs does not orphan a year of photographs, and an import
can drop the files back under a fresh root and repoint nothing
([[Gallery]] rule G2).

## Migrations

Drift's stepwise migrations, tested with its schema-verification tooling. Every schema change lands with a migration test before merge. Schema history: v6 added `money_txns`, `debts`, `debt_payments`; v7 added `money_txns.kind` + `reference` so each movement records why it happened (manual / transfer / expense / debt) and what it relates to; v8 added `money_txns.link_uuid`, the row a movement belongs to (the expense it paid for, the debt payment it settled) so the two are edited and deleted as one; **v9** added `commitments.archive_note` (why a seed was put away) and the `seed_notes` table; **v10** added the Phase 3 tables — `notes`, `note_links`, `albums` and `memories`.

A seed's **start day** deliberately has no column: `created_at` already
says when it was planted, so the rule that nothing is due before then
([[Business-Rules]] #12) is derived rather than stored, and it is
correct for every row that was already in the database.

**Deleting means deleting, eventually.** Almost every "delete" in the
app is a soft delete: the row keeps its history and its `updated_at` for
a future sync. On each launch, rows soft-deleted more than 30 days ago
are purged for good (`purgeDeleted` on the commitments, finances and
vault repositories). Nothing about money lingers forever by accident.

The one hard delete is `CommitmentsRepository.hardDelete` — the seed I
planted by mistake, confirmed in the UI first, taking its check-ins, its
notes and its streak row with it in a single transaction and leaving a
`delete` outbox row behind ([[Business-Rules]] #8). Its focus sessions
are detached rather than deleted: the time was still spent. A soft
delete would have been worse here, not safer — the row would skew the
stats for thirty days and then be lost anyway.

**Every table is exportable.** The spreadsheet export
([[ADR-006-Export-Format]]) reads each table directly rather than through
the feature repositories, because those filter to what a screen should
show and a backup that quietly drops rows is not a backup. A new table
therefore owes the export a sheet — that is [[Business-Rules]] #11, and
`ExportRepository` is the one place to add it.

**The outbox and privacy.** `money_txns`, `debts`, `debt_payments` and
`expense_categories` append to the same outbox as expenses, and they
carry the most sensitive data in the app — amounts, and other people's
names. They belong in the same tier as expenses in [[Sync-Strategy]]:
end-to-end encrypted, or local-only by choice. The outbox row itself
holds no content, only a table, a uuid and an operation.
