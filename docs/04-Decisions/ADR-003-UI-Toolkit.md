# ADR-003 — UI: Material 3 + Custom Design System

**Status:** Accepted · **Date:** 2026-09-02

## Context

The app must feel like a warm game (Duolingo energy) while staying minimalist, support dark/light and RTL, and not drown me in bespoke widget maintenance.

## Decision

**Material 3 as the component base**, restyled by a token-driven Harvest design system ([[Theming-and-Design-System]]), with a small set of signature custom components (CropCard, StreakFlame, XPBar, GaugeRing) and `flutter_animate` + spring physics + Lottie/Rive for the game feel.

## Rationale

- M3 gives accessibility, RTL, dark mode, and input handling for free; theming (colors, shapes, type) carries almost the entire visual identity.
- Full custom UI kits or game engines (Flame) are wildly over-scoped for a productivity app — the "game" is the *feel* (motion, haptics, celebration), not the rendering.
- Third-party design-system packages would fight the earthy custom palette and add dependency risk for no gain.

## Consequences

- Signature components need golden tests across theme × direction.
- Sprite assets (Lottie/Rive) become a small content pipeline of their own — kept to a handful of hero moments.
