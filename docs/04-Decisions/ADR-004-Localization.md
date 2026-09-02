# ADR-004 — Localization: gen-l10n (ARB)

**Status:** Accepted · **Date:** 2026-09-02

## Context

English + Arabic at launch, RTL required, more languages plausible later. Options: Flutter's built-in gen-l10n, `easy_localization`, `slang`.

## Decision

**Flutter's first-party gen-l10n** with ARB files ([[Localization]]).

## Rationale

- First-party: zero dependency risk, guaranteed to track Flutter releases.
- ARB is the standard interchange format — translators and tooling (including future crowd translation) speak it natively.
- Type-safe accessors and ICU plural/gender support out of the box; Arabic's six plural forms make ICU non-negotiable.
- `slang` is pleasant but a dependency doing what the SDK already does; `easy_localization` adds runtime lookup cost and weaker compile-time safety.

## Consequences

- Slightly more ceremony than string maps — accepted for compile-time safety.
- RTL correctness is a code discipline (directional APIs only), enforced via golden tests and the PR checklist.
