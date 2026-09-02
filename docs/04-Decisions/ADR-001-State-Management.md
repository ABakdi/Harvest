# ADR-001 — State Management: Riverpod

**Status:** Accepted · **Date:** 2026-09-02

## Context

Harvest spans four pillars whose state interacts constantly (any check-in touches streaks, XP, quests, notifications). I need something readable today, maintainable across five phases, and scalable when sync arrives. Candidates: **Riverpod** and **Bloc** (with or without Cubits).

## Decision

**Riverpod with code generation** (`riverpod_generator`, AsyncNotifier controllers).

## Rationale

- **Readability:** a feature's state is a handful of annotated functions/classes, not event+state+bloc triples per screen. Cubits close the gap but then Bloc's main structural benefit (explicit events) is gone anyway.
- **Composition:** derived state (`today's due list` = commitments × schedule × HarvestDay) is Riverpod's native strength — providers watching providers, auto-disposed, auto-recomputed. This app is *mostly* derived state over a reactive DB ([[Local-Database]]).
- **Compile-time safety:** no BuildContext lookups; codegen removes the historic provider-boilerplate complaints.
- **Testing:** `ProviderContainer` overrides make repository faking trivial ([[State-Management]]).
- **Ecosystem trajectory:** Riverpod remains actively developed and is the community default for new Flutter apps of this shape.

## Consequences

- Team-of-one discipline required: conventions codified in [[State-Management]] (watch/read rules, one controller per screen).
- build_runner in the loop — acceptable; already needed for Drift.
- If I ever want event-sourced UI flows, I can still model explicit action objects inside a Notifier.
