# ADR-009 — One repository for the phone, the web and the server

**Status:** Accepted · 2026-09-19 · [[Phase-6-Sync-Accounts-and-Web]]

## Context

Until v2.0.0, Harvest was one Flutter app at the root of the
repository. [[Phase-6-Sync-Accounts-and-Web]] adds two more programs:
- a **sync server**, with accounts;
- a **web app**, which is the whole of Harvest in a browser,
  installable as a PWA.

The three share one data model and one sync contract. Most of all,
they share the rules: what a Harvest Day is, when a habit is due, what
a check-in pays. If those live in three places, they will drift in
three directions.

## Decision

One repository, laid out by program:

```
apps/
  mobile/        the Flutter app (Android first), unchanged inside
  web/           React 19 + Vite + shadcn/ui, the PWA
  server/        Express 5 + TypeScript, the sync and accounts API
packages/
  contracts/     zod schemas: every API body, every synced table
  core/          the rules in TypeScript: HarvestDay, isDueOn, XP, streaks
docs/            the vault, for all of it
```

- **pnpm workspaces** for the TypeScript side, with **Turborepo** to
  run `build`, `typecheck`, `lint` and `test` in dependency order. The
  Flutter app keeps its own toolchain, run from `apps/mobile`.
- **`packages/contracts`** is the single definition of the wire format.
  The server validates with it, and the web reads and writes with it.
  The Dart side is written by hand against the same shapes, and it is
  held to them by **fixture files**: JSON records in
  `packages/contracts/fixtures/` that both the TypeScript tests and the
  Dart tests parse.
- **`packages/core`** is the port of the domain rules the web needs. It
  is held to the Dart originals the same way: shared fixtures of
  *inputs → expected outputs* (a schedule and a day → due or not; a
  check-in history → a streak), run by both test suites. When a rule
  changes, the fixture changes, and whichever side was not updated goes
  red.

## Why not…

- **Separate repositories.** One pull request can then no longer
  change a contract and both of its readers, and "which version of the
  server does this app talk to" becomes a question.
- **Flutter for the web too.** It would reuse the Dart rules
  outright. But Flutter web is a canvas: no text selection worth the
  name, poor accessibility, a large first load, and no real
  PWA-installable, SEO-able landing page. The landing page and the
  install flow matter most on the web. React and shadcn/ui are what I
  want to build web UI with.
- **Nx.** It is more than I need. Turborepo runs tasks in order and
  caches them, and that is the whole requirement.

## Consequences

- Every Flutter command now runs from `apps/mobile`. CI has a job per
  toolchain.
- The domain rules exist twice, in Dart and in TypeScript, on purpose.
  The fixtures are what makes that safe. A rule without a fixture is a
  rule the two sides may disagree on.
- `docs/` stays at the root, because the vault describes the product,
  not one program.

Related: [[ADR-005-Local-First-Sync]] · [[ADR-011-Backend]] · [[ADR-012-Web-Client]]
