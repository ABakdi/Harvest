# ADR-002 — Local Database: Drift (SQLite)

**Status:** Accepted · **Date:** 2026-09-02

## Context

All user data is local-first forever ([[Business-Rules]] #5), with MongoDB sync arriving in Phase 5. Requirements: open source, well supported, fast offline queries (streak math over years of check-ins), reactive queries for the UI, and a credible sync path. Candidates considered:

| Option | Verdict |
| :--- | :--- |
| **Drift** (SQLite) | ✅ Chosen |
| **Isar** | Document-model fit, but maintenance has been unreliable for long stretches; betting years of personal data on it is risky |
| **Realm** | Was MongoDB's own — but MongoDB deprecated the Realm SDKs and Atlas Device Sync; dead end |
| **Hive / Hive CE** | Key-value box store; no real queries — wrong shape for ledger/date-range math |
| **ObjectBox** | Solid tech, but sync is a paid product and the core is less open than SQLite's ecosystem |

## Decision

**Drift** on SQLite.

## Rationale

- **Support:** the single most actively maintained Flutter persistence layer, on the most battle-tested storage engine in existence. It will outlive every alternative on the list.
- **Fit:** streaks, budgets, and reports are relational/date-range queries and aggregate sums — SQL's home turf. Type-safe generated queries + stream-based watching plug straight into Riverpod ([[State-Management]]).
- **MongoDB compatibility is an API concern, not a storage one:** rows carry client-generated UUIDs and serialize to JSON documents at the sync boundary; an on-device document store would buy nothing ([[Sync-Strategy]]).
- Migrations with a testing harness, encryption available via SQLCipher if needed for expenses.

## Consequences

- Schema + codegen ceremony per table — offset by migration safety.
- The document↔row mapping lives in the Phase 5 API layer; kept trivial by designing tables sync-ready from day one ([[Local-Database]]).
