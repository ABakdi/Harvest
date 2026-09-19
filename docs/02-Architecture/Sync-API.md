# Sync API

The wire contract between every Harvest client (the phone, the web)
and the server. The shapes are defined once, as zod schemas in
`packages/contracts` ([[ADR-009-Monorepo]]). This page is the prose
version of those schemas, and when the two disagree, the schema wins
and this page is the bug.

Base path `/v1`. JSON everywhere. Authentication is the
`Authorization: Bearer <access token>` header ([[Accounts]]).

## Errors

Every failure has one shape:

```json
{ "error": { "code": "validation_failed", "message": "…", "details": [ … ] } }
```

| Code | Status | Meaning |
| :--- | :---: | :--- |
| `validation_failed` | 400 | The body, query or params did not parse; `details` lists the issues |
| `unauthorized` | 401 | No token, a bad token or an expired one: refresh and retry once |
| `forbidden` | 403 | Signed in, but not allowed (for example, an unverified account syncing) |
| `not_found` | 404 | No such route or resource |
| `conflict` | 409 | The email is taken (sign-up only) |
| `payload_too_large` | 413 | Over the body cap |
| `rate_limited` | 429 | Slow down; `Retry-After` says for how long |
| `unavailable` | 503 | A dependency is down: the database for health, GitHub with nothing cached for releases |
| `internal` | 500 | The server's fault, with no details |

## Records

A synced row travels as a **record**:

```json
{
  "table": "check_ins",
  "uuid": "0b9c…",
  "updatedAt": "2026-09-19T14:32:05.120Z",
  "deletedAt": null,
  "data": { "commitmentUuid": "…", "harvestDay": "2026-09-19", "amount": 1, … }
}
```

- `table` is one of the synced table names (the Drift table names,
  snake_case). `data` holds **every** column of the row in camelCase,
  its key and clocks included, with every timestamp as ISO-8601 UTC
  ending in `Z` and money in minor units, as in the export
  ([[ADR-006-Export-Format]]). A column missing, a column unknown, or a
  `uuid`/`updatedAt`/`deletedAt` that disagrees with the row's own
  makes the record invalid — so the server ships before any phone
  schema change, never after.
- **Keys that are not uuids** travel in the `uuid` field all the same:
  `step_days` by its day, `streaks` by its scope, `kv_settings` by its
  key (and only an allow-listed one), `training_maxes` as
  `<programUuid>/<exerciseId>`.
- **Rows with no clock of their own** (`debt_payments`, the program and
  session children) send the moment the change was queued — the
  outbox's `queuedAt` — as `updatedAt`, or an edit would lose to the
  row's older self.
- `updatedAt` is the row's own clock, the one the conflict rule
  compares. Append-only tables with no `updatedAt` column (the ledger)
  send their `createdAt`.
- **The private tier** (`expenses`, `money_txns`, `debts`,
  `debt_payments`, `expense_categories`, `location_points`, `geotags`,
  `saved_places`) sends `enc` instead of `data`:
  `{ "v": 1, "iv": "<base64 12 bytes>", "ct": "<base64>" }`. That is
  AES-256-GCM over the JSON of `data`, keyed by the sync passphrase
  through PBKDF2-SHA256 (600,000 iterations, the account's salt). The
  server checks that the envelope is well-formed and nothing more.
  `updatedAt` and `deletedAt` stay in the clear, because the conflict
  rule needs them.
- **A purged row** (a hard delete: the notes trash emptied, a
  mis-planted seed) is a record with `"purged": true` and no `data`.
  The server drops the stored data and keeps the tombstone, so other
  devices purge it too.
- **Not synced**: the outbox itself, the exercise catalogue ([[Business-Rules]] #14),
  and any setting outside the import allow-list. The allow-list is the
  one `importableSettingPrefixes` already defines: bookkeeping never
  leaves a device.

Every plaintext table has a zod schema for its `data`, and a record
that fails it is rejected on its own. The rest of the batch still
lands.

## Push

`POST /v1/sync/push`

```json
{ "deviceId": "…", "records": [ … up to 500 … ] }
```

For each record, keyed by `(user, table, uuid)`:
- **No stored copy** → store it.
- **Stored, and the incoming `updatedAt` is later** → replace it.
- **Stored, and the incoming one is the same age or older** → keep the
  stored one and answer `stale`. Equal stamps are the same write coming
  back.

Every stored write takes the next value of the user's **sequence**, a
per-user counter incremented atomically. Pushes for one account are
applied one at a time, so a pull can never step over a sequence number
still being written; the lock lives in the server process, which is
right for one instance and must move into MongoDB before there are two. The answer:

```json
{ "results": [ { "table": "…", "uuid": "…", "status": "applied" | "stale" | "invalid", "issues": [ … ] } ], "cursor": 1834 }
```

A client clears an outbox row once its record comes back `applied` or
`stale`. It keeps `invalid` ones, logs them, and shows the count in
Settings → Account. It never retries them blindly.

## Pull

`GET /v1/sync/pull?after=<seq>&limit=<1..1000>`

```json
{ "records": [ { …record…, "seq": 1835 } ], "cursor": 1900, "more": false }
```

Records come in sequence order. The client merges each one by the same
rule as the server:
- a local row missing, or older than the record, is overwritten;
- anything else is ignored.

A purged record hard-deletes locally. The client then stores `cursor`
and pulls again while `more` is true.

**Merging never writes to the local outbox.** A pulled row is not a
new change, and echoing it back would loop.

## Order of a sync

1. Pull until `more` is false. Remote first, so a stale local edit
   loses to a newer remote one before it is even sent.
2. Push the outbox in batches of 500, oldest first.
3. Pull once more, to catch anything that landed meanwhile.
4. Recompute derived state (streaks, balances), because history may
   have changed.

A sync runs:
- on app resume (the web: on focus);
- two seconds after the last local write;
- every 15 minutes while the app is open;
- from the 3 AM job on the phone.

It never runs more than once at a time.

## Files

Pictures and voice notes are not rows. They sync in a later milestone
of [[Phase-6-Sync-Accounts-and-Web]], content-addressed:
- `PUT /v1/files/<sha256>` uploads the bytes, encrypted with the same
  key as the private tier.
- `GET /v1/files/<sha256>` downloads them.
- A row that names a file carries its hash.

Until then, a picture's row syncs and shows as *"on another device"*
where the file is missing.

## Other routes

| Route | Auth | Purpose |
| :--- | :---: | :--- |
| `GET /v1/health` | – | Liveness, for the host |
| `POST /v1/auth/register` · `login` · `refresh` · `logout` · `verify-email` · `resend-verification` · `forgot-password` · `reset-password` | – | [[Accounts]] |
| `GET /v1/me` · `PATCH /v1/me` · `DELETE /v1/me` | ✓ | The account |
| `GET /v1/me/sessions` · `DELETE /v1/me/sessions/:id` | ✓ | Devices |
| `GET /v1/releases/latest` | – | The newest APK, for the download page ([[Web]]) |
| `POST /v1/assist` | ✓ | The server assist ([[ADR-013-Assist-Providers]]), in a later milestone |

Related: [[Sync-Strategy]] · [[Accounts]] · [[ADR-011-Backend]] · [[ADR-005-Local-First-Sync]]
