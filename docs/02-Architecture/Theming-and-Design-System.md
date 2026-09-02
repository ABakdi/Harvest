# Theming & Design System

Duolingo's warmth, a farmer's palette, a minimalist's restraint. Decision record: [[ADR-003-UI-Toolkit]].

## Palette

| Token | Light | Role |
| :--- | :--- | :--- |
| `terracotta` | `#E07A5F` | Primary actions, streak flame |
| `sage` | `#81B29A` | Success, growth, check-ins |
| `soil` | `#3D405B` | Text, dark surfaces |
| `cream` | `#F4F1DE` | Backgrounds |
| `sun` | `#F2CC8F` | XP, coins, highlights |

Dark theme re-derives the same tokens on soil-dark surfaces — both themes ship from day one, driven by `ThemeMode` (system/light/dark). Semantic tokens only in feature code; raw hex lives in one file (`core/ui/tokens.dart`).

## Typography

**Nunito** (via `google_fonts`) — rounded, friendly, excellent Latin coverage — paired with a matching rounded Arabic face (e.g., **Baloo Bhaijaan 2** or **IBM Plex Sans Arabic**, decided by side-by-side testing) for [[Localization]]. Type scale stays Material 3's, restyled.

## Shape & components

- Chunky rounded corners (16–24 dp), soft elevation, generous tap targets (≥48 dp).
- A small set of signature components built on Material 3: **CropCard**, **StreakFlame**, **XPBar**, **GaugeRing**, **QuestChip**, **BigBouncyButton**. Everything else is stock M3 themed by tokens.

## Motion & feel

- `flutter_animate` + spring simulations for the game feel; every check-in fires haptic "thud" + a sprite (plant growing / fruit dropping into a basket).
- Sprites are Lottie/Rive assets, kept subtle: one hero moment per action, no ambient noise.
- All animations respect the system reduce-motion setting.

## Accessibility

- WCAG AA contrast in both themes (the palette above is checked at build time in golden tests).
- Full dynamic type support; the field layout must survive 200% text.
- Every gauge/flame has a text equivalent for screen readers.
