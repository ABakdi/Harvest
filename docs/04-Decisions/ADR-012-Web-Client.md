# ADR-012 — The web app is local-first too: React 19, Vite, shadcn/ui, IndexedDB

**Status:** Accepted · 2026-09-19 · [[Web]] · [[Phase-6-Sync-Accounts-and-Web]]

## Context

The web version is the **whole app**, not a dashboard: I should be able
to check a seed in, log an expense or write a note from a laptop. It
also carries the public face of the project:
- a home page;
- the APK download;
- the button that installs it as a PWA.

There are two shapes this could take:
1. **A thin client over the API.** Every screen asks the server, and
   the server computes streaks, budgets and progress.
2. **A second local-first client.** The browser keeps its own copy in
   IndexedDB, writes locally, and syncs through the same outbox
   protocol as the phone.

## Decision

**The second.** The web is a peer of the phone, not a window onto the
server.

- **Local store:** IndexedDB through **Dexie**. It has one table per
  synced table, the same UUIDs and the same `updatedAt`/`deletedAt`,
  and an `outbox` table drained by the same push.
- **The rules:** `packages/core`, the TypeScript port of the Dart
  domain, held to it by shared fixtures ([[ADR-009-Monorepo]]).
  Streaks, due days and XP are computed in the browser, from history,
  exactly as on the phone.
- **Stack:**
  - **React 19**, **Vite**, **TypeScript** (strict).
  - **React Router 7** for routing.
  - **TanStack Query** for the few calls that really are online
    (auth, account).
  - **Tailwind CSS 4** and **shadcn/ui**, themed with the Harvest
    palette and Nunito ([[Theming-and-Design-System]]).
  - **i18next** for English and Arabic, with RTL.
  - **vite-plugin-pwa** (Workbox) for the service worker and the
    manifest.
  - **MapLibre GL** for [[Places]] ([[ADR-010-Maps]]).
- **One app, two faces.** The public routes (`/`, `/download`,
  `/privacy`) are light and render without the local store. The app
  lives under `/app`, and is what the PWA opens by default.

## Why not the thin client

- **Business rule #5**, local-first, is constitutional. A web app that
  shows a spinner on a train would break it on the one platform where
  losing the connection is most normal.
- **The server would have to compute derived state**, and
  [[ADR-011-Backend]] rules that out: derived state computed in one
  place and cached in another is exactly the class of bug the first
  two audits kept finding.
- **The sync protocol already exists for the phone.** A second client
  of it costs less than a second API shaped for screens.

## Why not Next.js

There is nothing to render on the server. The landing page is small
and static, and the app is private and client-side by nature. Vite
builds a static bundle that any host serves, with no server runtime
beside the API.

## Consequences

- Every domain rule the web shows needs a TypeScript port and a
  fixture. [[Phase-6-Sync-Accounts-and-Web]] ports them feature by
  feature, in the order the web gains screens.
- The browser's storage can be evicted. The app asks for persistent
  storage (`navigator.storage.persist()`), and a signed-in browser can
  always re-pull everything from the server.
- The private tier (finances, places) is decrypted in the browser with
  the key derived from my sync passphrase, which is never sent
  ([[Sync-Strategy]]).

Related: [[Web]] · [[ADR-009-Monorepo]] · [[ADR-011-Backend]]
