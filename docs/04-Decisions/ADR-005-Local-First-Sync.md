# ADR-005 — Local-First with Outbox Sync

**Status:** Accepted · **Date:** 2026-09-02

## Context

Sync and rankings arrive only in [[Phase-6-Sync-Accounts-and-Web]], on a MongoDB backend — but retrofitting sync onto years of locally-created data is where local-first apps usually die.

## Decision

Local-first is constitutional ([[Business-Rules]] #5). From schema v1, every table is **sync-ready**: client-generated UUIDs, `updatedAt`/`deletedAt`, and an **outbox** table appended on every write. Phase 6 adds only the drain + pull-merge ([[Sync-Strategy]]).

## Rationale

- The outbox rows cost microseconds now and eliminate the retrofit problem entirely — the full offline change history is already queued.
- Append-only histories (check-ins, ledger, expenses) make the dominant merge case conflict-free by construction; LWW on the few mutable rows is honest for a single user across devices.
- Derived state (streaks, balances) is never synced, only recomputed — no distributed-consistency headaches.

## Consequences

- The outbox is capped at its newest 50,000 rows (`capOutbox`, run with the startup purge). A device's first sync sends a full snapshot of every table ([[Sync-API]]), so the cap can never lose a change: the outbox is an increment, not the only copy.
- Deletes of anything that happened must be soft (`deletedAt`) from
  day one. The few things that go for good — a seed planted by
  mistake, an emptied note, a purged album, structure being edited —
  are listed in [[Business-Rules]] #8, and each leaves a `delete` row
  in the outbox.
- The sync API contract (batch push/pull by cursor, upsert-by-uuid) is fixed early, which constrains but also clarifies the Phase 6 server design ([[Sync-API]]).
