# 🌱 Harvest

*Cultivate your day. Harvest your potential.*

Harvest is a gamified life-management app built with Flutter. It brings the
streak psychology that keeps people coming back to Duolingo to every pillar
of daily life — productivity, finances, health, and focus — while staying
minimalist, local-first, and entirely under the user's control.

## Documentation

The full specification, architecture, and phased plan live in the
[`docs/`](docs/Home.md) Obsidian vault:

- **Overview** — vision, PRD, glossary
- **Specification** — one note per module (entities, gamification, notifications, …)
- **Architecture** — layers, state management, database, sync strategy
- **Planning** — roadmap, phases, milestone checklists
- **Decisions** — ADRs recording every major technical choice

## Stack

- **Flutter** (Android first, iOS next) · Material 3 + custom design system
- **Riverpod** (codegen) for state · **Drift**/SQLite for local-first storage
- **English + Arabic** with full RTL support
- Local-first forever; server sync (MongoDB) arrives in Phase 5

## Development

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter test
flutter run
```
