# Theming & Design System

Duolingo's warmth, a farmer's palette, a minimalist's restraint. Decision record: [[ADR-003-UI-Toolkit]].

## Presets

Five vibrant looks, each with light and dark variants and a signature
gradient, user-pickable in settings: **Harvest** (terracotta/sage),
**Sunrise** (coral/gold), **Ocean** (azure/teal), **Orchard**
(green/lime), **Dusk** (violet/pink). Gradients appear deliberately —
primary actions, the XP fill, selected calendar day — never as
wallpaper.

## The brand green

The presets recolour the app; they do not recolour Harvest. The
launcher icon, the loading screen and the home-screen widget all wear
one gradient — `#1F8A46 → #4FB54C → #8AD84E`, with `#17492C` for an
olive — so the app looks like itself before any of its settings have
been read. It lives in one place, `HarvestBrand` in `core/ui/tokens.dart`
([[Checkpoint-3]]).

The **icon** is a white olive branch on that gradient: a stem, five
leaves, three olives, generated from an SVG whose geometry is computed
and auto-fitted to the adaptive mask's safe circle, so it is as large as
it can be without a leaf tip being cropped. In a single-colour
silhouette the gaps are the drawing — the olives are spaced by
arithmetic, not by eye, so they stay three distinct olives at 48 dp.

## Palette (Harvest preset)

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
- A small set of signature components built on Material 3: **CropCard**, **StreakFlame**, **XPBar**, **GaugeRing**, **BigBouncyButton**. Everything else is stock M3 themed by tokens.
- Round 4 added the shared layout vocabulary every screen now speaks:
  **SectionHeader** (title, quiet subtitle, trailing action),
  **HeroCard** (gradient or status-tinted headline surface with one big
  number; children inherit its foreground), **StatTile** (a number with
  its label, optionally selectable), **IconBadge** (tinted rounded
  square holding one icon — the leading mark of every row),
  **LedgerRow** + day headers (one atomic entry with a signed amount),
  **HarvestFab** (the bouncy gradient button, floating), **EmptyState**.
- Surface language: cards sit one step above the page with a hairline
  edge; inputs, chips and segmented buttons are filled pills, never
  outlined boxes; tabs use a short rounded indicator; sheets carry a
  drag handle; snackbars float. All of it lives in `core/ui/theme.dart`
  so a screen only ever asks for `Card`, `TextField`, `ChoiceChip`.

## Motion & feel

- `flutter_animate` + spring simulations for the game feel; every check-in fires haptic "thud" + a code-drawn leaf burst.
- **The loading screen** is an olive tree growing — trunk, branches, leaves, blossom, fruit — painted by `GrowingOliveTree`, generated once from a fixed seed so it is the same tree every launch and only the progress moves. Each fork is pulled back toward vertical before it is spread (otherwise the third generation grows sideways and the tree becomes a shrub), and the whole tree is scaled about its base to fit whatever box it is painted in.
- **A reminder on a card counts down** rather than sitting there as a time: minutes and hours while distant, `M:SS` in the last five, grey and silent once the seed is done. It ticks once a minute and only switches to once a second in that last stretch — a field of cards must not be a field of per-second timers.
- All animations respect the system reduce-motion setting; with it on, the splash tree is simply there.

## Accessibility

- WCAG AA contrast in both themes (the palette above is checked at build time in golden tests).
- Full dynamic type support; the field layout must survive 200% text.
- Every gauge/flame has a text equivalent for screen readers.
