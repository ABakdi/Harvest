# Localization — English & Arabic

Decision record: [[ADR-004-Localization]]. Two launch languages: **English** and **Arabic**, with full RTL.

## Mechanics

- Flutter's built-in **gen-l10n**: `app_en.arb` + `app_ar.arb`, type-safe `AppLocalizations` accessors, ICU plurals/genders.
- Language switchable in-app (system default, English, Arabic) without restart.
- **No hardcoded strings** in widgets — enforced by lint (`avoid_hardcoded_strings` custom rule or review checklist).

## RTL rules

- Only logical directional APIs: `EdgeInsetsDirectional`, `AlignmentDirectional`, `start/end` — never `left/right`.
- Icons that imply direction (back arrows, progress chevrons) auto-mirror; sprites and gauges are direction-neutral by design.
- Golden tests run every design-system component in LTR **and** RTL ([[State-Management]]).

## Content notes

- The farming voice ([[Glossary]]) must be *translated as tone, not word-for-word* — Arabic copy gets written natively, not machine-mirrored.
- Numerals follow locale settings (Western vs. Eastern Arabic numerals) via `intl` number formatting; dates respect the locale but the Harvest Day boundary stays 3 AM local regardless ([[Business-Rules]]).
