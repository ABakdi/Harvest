# ADR-011 — The server: Express 5, TypeScript, zod, MongoDB

**Status:** Accepted · 2026-09-19 · [[Sync-API]] · [[Accounts]] · [[Phase-6-Sync-Accounts-and-Web]]

## Context

Sync was always going to need a server ([[ADR-005-Local-First-Sync]],
[[Sync-Strategy]]), and now the web app needs one too. Everything the
server holds is my life in rows, so its job is narrow:
- know who I am;
- keep an encrypted-where-it-matters copy of my rows;
- hand them to my other devices in order.

It computes **nothing**: streaks, balances and budgets are derived
state, and each client derives them from history.

## Decision

| Concern | Choice | Why |
| :--- | :--- | :--- |
| Runtime | Node 22 LTS | The same language as the web and `packages/contracts` |
| Framework | **Express 5** | Small, known, async errors handled natively since v5 |
| Language | **TypeScript**, `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes` | The contract is types; loose types would defeat it |
| Validation | **zod**, from `packages/contracts`, on every body, query and param | One schema per shape, shared with the web; nothing reaches a handler unparsed |
| Database | **MongoDB** (official driver, no ODM) | Decided in [[ADR-005-Local-First-Sync]]: rows are UUID-keyed documents already |
| Passwords | **argon2id** (`argon2`), OWASP parameters | Memory-hard; bcrypt's 72-byte cap and cost profile are worse |
| Tokens | **JWT access** (15 min, EdDSA via `jose`) + **opaque rotating refresh tokens** (30 days, hashed at rest, family reuse detection) | Access tokens are stateless and short; refresh tokens are revocable and rotate on every use |
| Web session | Refresh token in an `HttpOnly; Secure; SameSite=Strict` cookie scoped to `/v1/auth`, access token in memory | Nothing a script can read survives a reload |
| Mobile session | Refresh token in Android Keystore-backed secure storage | The same token, a different jar |
| Hardening | `helmet`, strict CORS allow-list, `express-rate-limit` on auth routes, body size caps, `pino` logs with no bodies and no emails | Defaults I would otherwise forget |
| Tests | **vitest** + **supertest** + **mongodb-memory-server** | Real queries against a real engine, no mocks of the database |
| Mail | A `Mailer` interface: SMTP in production, the log in development | Verification and reset links, and nothing else |

## The rules it keeps

1. **Every route but `/v1/health`, the auth routes and
   `/v1/releases` requires a valid access token.** The user id comes
   from the token, never from the body.
2. **Every document carries `userId`**, and every query filters by it,
   in one repository layer. A handler cannot forget, because a handler
   never touches a collection.
3. **The server never decrypts the private tier.** Finance and location
   rows arrive as ciphertext ([[Sync-Strategy]]) and are stored as
   ciphertext. The server validates their envelope, not their contents.
4. **Deleting the account deletes everything**, in one call, at once:
   records, tokens, the user. There is no soft delete on the server for
   the person, only for rows.
5. **Errors are shapes.** Every failure is
   `{ error: { code, message, details? } }`, with a code the clients
   switch on. Stack traces never leave the process.

## Consequences

- There are two implementations of password rules and email checks,
  the zod schema and the Dart form, held together by the contract
  fixtures ([[ADR-009-Monorepo]]).
- An access token is checked against its live session on every
  request — one indexed read — so signing out, a password reset and a
  deleted account take effect at once rather than up to fifteen
  minutes later.
- MongoDB needs a replica set for transactions. The sync push does not
  use transactions: each record is an idempotent upsert keyed by
  `(userId, table, uuid)`, and the cursor is a per-user counter
  incremented atomically with `findOneAndUpdate`.

Related: [[Sync-API]] · [[Accounts]] · [[ADR-005-Local-First-Sync]]
