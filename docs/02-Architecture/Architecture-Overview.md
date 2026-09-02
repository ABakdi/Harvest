# Architecture Overview

Feature-first, layered, local-first. The goal is a codebase where a feature can be found, read, and changed in one folder, and where the sync layer can be bolted on in Phase 5 without touching domain logic.

## Layers

```mermaid
flowchart TD
    subgraph Presentation
        UI[Screens & Widgets] --> C[Controllers / Notifiers<br/>Riverpod]
    end
    subgraph Domain
        C --> UC[Use cases & services<br/>streak engine, quest generator, budget calc]
        UC --> M[Entities - pure Dart]
    end
    subgraph Data
        UC --> R[Repositories - interfaces in domain]
        R --> DB[(Drift / SQLite)]
        R -.Phase 5.-> SY[Sync client → MongoDB API]
    end
    subgraph Platform
        P1[Notifications & alarms]
        P2[Background jobs - 3AM reset]
        P3[Usage stats / overlays]
        P4[Home widgets]
    end
    UC --> P1 & P2
```

- **Presentation** knows nothing about storage; it watches Riverpod providers ([[State-Management]]).
- **Domain** is pure Dart — entities and services like the streak engine live here and are unit-testable with zero mocks of Flutter or the DB.
- **Data** implements repository interfaces over Drift ([[Local-Database]]); the future sync client hangs off the same repositories ([[Sync-Strategy]]).
- **Platform** wraps the messy native parts behind thin interfaces ([[Notifications-and-Background]]).

## Package layout

```
lib/
├── app/                  # MaterialApp, router, theme wiring, l10n setup
├── core/                 # shared kernel
│   ├── domain/           #   HarvestDay, value types, Result
│   ├── db/               #   Drift database, migrations
│   ├── platform/         #   notifications, background, haptics wrappers
│   └── ui/               #   design system: tokens, shared widgets
├── features/
│   ├── commitments/      # Phase 1 — habits, projects, todos
│   │   ├── domain/  data/  presentation/
│   ├── gamification/     # Phase 1 — streaks, xp, coins, quests
│   ├── planner/          # Phase 1 — daily plan ritual
│   ├── pomodoro/         # Phase 1
│   ├── finances/         # Phase 2
│   ├── health/           # Phase 3 — sleep + gym
│   ├── screentime/       # Phase 4
│   └── onboarding/
└── main.dart
```

Every feature folder repeats the same `domain/ data/ presentation/` trio. Cross-feature communication goes through domain services (e.g., any check-in calls the gamification service), never by importing another feature's presentation layer.

## Key flows

A check-in, end to end:

```mermaid
sequenceDiagram
    participant W as Crop card (UI)
    participant N as CheckInController
    participant S as CheckInService (domain)
    participant G as GamificationService
    participant D as Drift repositories
    W->>N: tap
    N->>S: checkIn(commitment, qty)
    S->>S: validate (over-log cap, Harvest Day)
    S->>D: insert CheckIn (+ outbox row)
    S->>G: onCheckIn(event)
    G->>D: update streaks, XP, quest progress
    D-->>N: reactive streams re-emit
    N-->>W: card animates 🌱 + haptic
```

Related: [[Business-Rules]] · [[ADR-001-State-Management]] · [[ADR-002-Local-Database]]
