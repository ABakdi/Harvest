# Phase 6 — Sync, Accounts & the Web

Specs: [[Sync-API]] · [[Accounts]] · [[Web]] · [[Sync-Strategy]] · [[ADR-009-Monorepo]] · [[ADR-011-Backend]] · [[ADR-012-Web-Client]]

Harvest leaves the phone. It comes in four pieces, built in this
order because each one needs the one before it:
1. **The contract**, `packages/contracts`: every synced table and
   every API body as a zod schema.
2. **The server**, `apps/server`: Express 5, TypeScript, MongoDB,
   accounts and the sync API.
3. **The phone's sync client**: an account screen, and the outbox
   finally drained.
4. **The web app**, `apps/web`: React 19, Vite and shadcn/ui,
   local-first in IndexedDB, installable as a PWA, with a public home
   page and the APK download.

It went ahead of screen time on 2026-09-19. A second device for the
data I already have is worth more to me than a cap on the phone.

```mermaid
flowchart LR
    A[M6.1 Contracts & core] --> B[M6.2 Server: accounts]
    B --> C[M6.3 Server: sync]
    C --> D[M6.4 Phone: account & sync]
    C --> E[M6.5 Web: site, install, shell]
    A --> E
    E --> F[M6.6 Web: field, goals, notes, money]
    F --> G[M6.7 Web: the rest]
    D --> H[M6.8 Private tier & files]
    G --> H
    H --> I[M6.9 Server assist & release]
```

## M6.1 — Contracts and core
- [x] `packages/contracts`:
  - error shape, auth bodies and account DTOs;
  - the `SyncRecord` envelope, the table registry (name → plaintext or
    private tier → `data` schema), push and pull bodies.
- [x] `packages/contracts/fixtures`: one JSON record per table, parsed
  by the TypeScript tests *and* by a Dart test in `apps/mobile`.
- [x] `packages/core`: `HarvestDay` (3 AM, calendar-safe), `isDueOn`
  with the start-day rule (#12), XP amounts, the over-log cap, goal
  progress, and fixtures shared with Dart for each.

## M6.2 — Server: accounts
- [x] Express 5 app factory with helmet, CORS allow-list, body caps,
  pino, the error middleware and zod-validated routes.
- [x] Mongo repositories (users, sessions, verification and reset
  tokens), with indexes created at boot.
- [x] Register, verify, login, refresh with rotation and family reuse
  detection, logout, forgot/reset, `me`, sessions, delete account
  ([[Accounts]] AC1–AC6).
- [x] Rate limits on auth; the `Mailer` interface (SMTP / log).
- [x] Tests on mongodb-memory-server: every flow, and every negative
  (reuse, expiry, wrong password, unverified sync, a cross-user read).

## M6.3 — Server: sync
- [x] `records` collection keyed `(userId, table, uuid)`; the per-user
  sequence.
- [x] Push (LWW by `updatedAt`, `stale` on a tie, invalid records
  isolated) and pull (by sequence, paged).
- [x] Private-tier envelope checks; purged tombstones.
- [x] `GET /v1/releases/latest`, cached from GitHub.
- [x] Tests: two simulated devices converging; stale edits losing;
  tombstones propagating; one user never seeing another's records.

## M6.4 — Phone: account and sync
- [x] Settings → Account ([[Accounts]]): sign up, sign in, verify
  state, devices, sign out, delete.
- [x] `ApiClient` with refresh-on-401, and tokens in secure storage.
- [x] `SyncService`: pull → push → pull, row serialisers per table
  (checked against the contract fixtures), merge without echoing into
  the outbox, derived state recomputed.
- [x] Triggers: resume, a debounce after writes, every 15 minutes while
  open. The 3 AM job does not sync yet: it runs in its own isolate,
  and the account's tokens would have to follow it there.
- [x] Tests against a fake API: a round trip per table, conflict
  ordering, the cursor, purge.

## M6.5 — Web: the site, the install, the shell
- [x] Vite + React 19 + TypeScript, Tailwind 4 + shadcn/ui themed with
  the Harvest tokens, React Router 7, i18next en/ar with RTL.
- [x] Home, download, privacy; the PWA manifest and service worker;
  the install button (and the iOS steps).
- [x] Login, register, forgot, reset, verify; session in memory with
  the refresh cookie.
- [x] `/app` shell: the rail, the Dexie store, the sync engine (the
  same protocol as the phone), the sync status, settings.
- [x] Tests: vitest + Testing Library for the flows; the sync engine
  against a fake server.

## M6.6 — Web: field, goals, notes, money
- [x] Field: today's seeds, check-in and undo, the over-log cap, the
  day's XP and the streak (`packages/core`). The web keeps the streak
  rows up to date on check-in and undo; judging closed days — freezes,
  breaks — stays with the phone, because two devices judging the same
  day would count it twice.
- [x] Seeds: plant, edit, pause, archive.
- [x] Goals board and goal screen ([[Goals]]).
- [x] Notes: folders, the editor (markdown styled in place), links and
  backlinks, search.
- [x] Expenses: log, edit, move a day, the month and the budget.
- [x] Keyboard shortcuts ([[Web]]).

## M6.7 — Web: the rest
- [x] Vault (the pots and their ledgers, debts), the month's budget
  with its floating daily limit, the calendar, and the run so far —
  the heat-map and each habit's streak — on the farmer.
- [x] Body: sleep, weight and steps, as views.
- [x] Gym: programs and history, with the catalogue's names carried as
  their own index because the catalogue does not sync (#14).
- [x] Places: the day on a MapLibre map, its trail, its pins and its
  stays, loaded only when the map is opened.
- [x] Gallery: what each album holds. The pictures wait for M6.8.

## M6.8 — The private tier, and files
- [x] Sync passphrase: PBKDF2-SHA256 → AES-256-GCM, identical in Dart
  (`cryptography`) and WebCrypto, pinned by `fixtures/crypto.json`, with
  the table and key as additional data so a sealed row cannot be moved.
- [x] Finance and location tables sync encrypted ([[Sync-API]]), checked
  end to end against the real server (`test/e2e`).
- [ ] Content-addressed file sync for pictures and recordings,
  encrypted, with size caps.
- [ ] Microsecond clocks on the phone (dates stored as text, one
  migration), so an edit can never tie with the web's ([[Sync-API]]: a
  known limit).

## M6.9 — The server assist, and the release
- [ ] `POST /v1/assist`: server-held key, per-user quota, the same
  prompt templates.
- [ ] `HarvestServerProvider` on the phone and the web.
- [ ] Deployment notes (Docker image for the server, the static web
  bundle), then the checkpoint and `v3.0.0`.

**Exit:** the phone and the browser converge on the same day's
field, the same notes and the same month of expenses, with the private
tier unreadable on the server; `v3.0.0`.
