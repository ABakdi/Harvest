# ADR-005 — Local-First with Outbox Sync

**Status:** Accepted · **Date:** 2026-09-02

## Context

Sync and rankings arrive only in Phase 5, on a MongoDB backend — but retrofitting sync onto years of locally-created data is where local-first apps usually die.

## Decision

Local-first is constitutional ([[Business-Rules]] #5). From schema v1, every table is **sync-ready**: client-generated UUIDs, `updatedAt`/`deletedAt`, and an **outbox** table appended on every write. Phase 5 adds only the drain + pull-merge ([[Sync-Strategy]]).

## Rationale

- The outbox rows cost microseconds now and eliminate the retrofit problem entirely — the full offline change history is already queued.
- Append-only histories (check-ins, ledger, expenses) make the dominant merge case conflict-free by construction; LWW on the few mutable rows is honest for a single user across devices.
- Derived state (streaks, balances) is never synced, only recomputed — no distributed-consistency headaches.

## Consequences

- Outbox grows until Phase 5 — pruned by a size cap until a server exists to drain it.
- Deletes must be soft (`deletedAt`) everywhere from day one.
- The sync API contract (batch push/pull by cursor, upsert-by-uuid) is fixed early, which constrains but also clarifies the Phase 5 server design.
