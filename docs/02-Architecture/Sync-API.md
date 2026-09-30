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
| `conflict` | 409 | The email is taken (sign-up), another device already chose the PIN (the key check), or `POST /v1/sync/sealed` with no PIN set |
| `key_changed` | 409 | Sealed under a key the account no longer has: the PIN was started over elsewhere |
| `payload_too_large` | 413 | Over the body cap |
| `quota_exceeded` | 507 | The account has no room left for files |
| `rate_limited` | 429 | Slow down; `Retry-After` says for how long |
| `unavailable` | 503 | A dependency is down: the database for health, GitHub with nothing cached for releases |
| `internal` | 500 | The server's fault, with no details |

## Records

A synced row travels as a **record**, and since Phase 7 every record
is sealed ([[Phase-7-Privacy-and-Currencies]], M7.1):

```json
{
  "table": "check_ins",
  "uuid": "0b9c…",
  "updatedAt": "2026-09-19T14:32:05.120Z",
  "deletedAt": null,
  "enc": { "v": 2, "iv": "…", "ct": "…" }
}
```

A record with `data` is refused, `invalid` with the issue code
`sealed_required`. What is inside the envelope is the row's `data`:

- `table` is one of the synced table names (the Drift table names,
  snake_case). `data` holds **every** column of the row in camelCase,
  its key and clocks included, with every timestamp as ISO-8601 UTC
  ending in `Z` and money in minor units, as in the export
  ([[ADR-006-Export-Format]]). A column unknown, or a
  `uuid`/`updatedAt`/`deletedAt` that disagrees with the row's own
  makes the row invalid — checked by the device that opens it
  (`checkRow`), since the server cannot read it. A column **missing** is invalid too,
  except one added after v3.0.0-beta.1 — marked `added()` in
  `packages/contracts/src/tables.ts`: `saved_places.notes`,
  `expense_categories.createdAt`, `goal_items.parentUuid`, and the
  [[Lists]] columns of `wishlist_items` (`listUuid`, `mediaType`,
  `link`, `creator`, `startedAt`, `rating`, `seedUuid`, `noteUuid`).
  A device that has not upgraded yet sends rows without them, and they
  read as null rather than vanish.
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
- **The envelope**, for every table (until Phase 7 only `expenses`,
  `money_txns`, `debts`, `debt_payments`, `expense_categories`,
  `location_points`, `geotags` and `saved_places` were sealed; the rest
  travelled as `data`):
  `{ "v": 2, "iv": "<base64 12 bytes>", "ct": "<base64>" }`. That is
  AES-256-GCM over the JSON of `data`, followed by spaces up to a
  padded length (at least 256 bytes, then the Padmé rule, at most about
  12% more), so the ciphertext's length does not tell a note from a
  place; JSON ignores the spaces. The 16-byte tag is appended to
  `ct`. The key is HKDF-SHA256 (info `harvest/sync-key/v2`, salted
  with the account's **key share**) over PBKDF2-SHA256 of the sync PIN
  or passphrase ([[Accounts]] AC7; 600,000 iterations, the account's
  salt). The key share is 32 random bytes that `GET /v1/me/sync-key`
  hands to a signed-in, verified session with the salt and the
  account's **key check**; the server keeps it sealed under a key from
  its environment, never in the database. The additional data is
  `row/<table>/<uuid>/<updatedAt µs>/<deletedAt µs or empty>` — the
  record's own clocks, as integers of microseconds, so any spelling of
  the same instant binds the same way — and after opening, the row's
  own `updatedAt`/`deletedAt`, where its table has them, must be the
  record's. An older ciphertext offered under a newer clock, a deleted
  version replayed as live, or a row moved to another uuid fails to
  open. `packages/contracts/fixtures/crypto-v2.json` and
  `crypto-v3.json` (the padding, the names) pin all of it.
  The server checks that the envelope is well-formed and nothing more.
  `updatedAt` and `deletedAt` stay in the clear, because the conflict
  rule needs them.
- **A row that will not open** — sealed by 3.0.0 (`v: 1`), or not what
  it claims to be — is **locked**: counted and shown in Settings →
  Account, never fatal, and never a reason to forget a key that opened
  the account's key check. Whether a PIN is the account's is decided by
  that check alone (`PUT /v1/me/sync-key/check` stores the first one;
  a second device choosing at the same moment gets `409` with the
  stored check and verifies against it).
- **`file`**, on a row of `memories` or `note_attachments` that names
  a file, is the name the file is stored under (below), in the clear:
  the one thing the server needs from inside such a row, to know which
  files are still wanted. It says nothing about the file.
- **The trail travels by the day** (M7.3): `trail_days`, one record a
  Harvest Day holding that day's points, keyed by a hash of the day
  under the name key (`trailKeyOf`), and stamped with the hour it was
  packed, so the server sees a day change at most once an hour and
  never which day it is. `location_points`, one record a point as 3.1
  sent it, is **retired**: a push of one is `invalid` with
  `retired_table` (a tombstone still lands), and the ones stored are
  deleted by `POST /v1/sync/sealed`. A point is never dropped from a day
  by a newer copy that lacks it; it goes by its own `deletedAt`.
- **Rows stored before Phase 7** in the clear are handed out by a pull
  as they are, with their `data`, until a device seals them: a sealed
  record replaces its own stored copy in the clear **at the same
  clock** (it is that row, sealed), and `POST /v1/sync/sealed` deletes
  what is left (below).
- **A purged row** (a hard delete: the notes trash emptied, a
  mis-planted seed) is a record with `"purged": true` and no `data`.
  The server drops the stored data and keeps the tombstone, so other
  devices purge it too.
- **Legacy settings.** 3.0.0 synced every `assist.` and `places.` key,
  the assist's provider and base URL and the map's style URL among
  them. Nothing current sends those any more (a synced row must not
  decide where a device sends its key or asks for its map), but a
  3.0.0 phone still does, so the server answers them `applied` rather
  than `invalid` for ever (`legacySettingPrefixes`), and keeps none of
  them: a hostile value never sits in the account. Current clients
  never push them.
- **Not synced**: the outbox itself, the bundled exercise catalogue
  ([[Business-Rules]] #14) — only my custom exercises travel, in `exercises` —
  and any setting outside the import allow-list. The allow-list is the
  one `importableSettingPrefixes` already defines: bookkeeping never
  leaves a device, and neither does anything that says where a request
  goes — the assist's provider, model and base URL, the map's style
  URL. A pulled row for such a key is ignored, and the assist's API
  key is only ever sent to the destination it was saved for.

Every table has a zod schema for its `data`; the server checks the
envelope, and the device that opens a row checks the row (`checkRow`),
parking one that fails rather than applying it. A record the server
refuses is refused on its own; the rest of the batch still lands.

### Sealing what was in the clear

`POST /v1/sync/sealed` `{ "deviceId": "…", "keyEpoch": 3 }` → `{ "dropped": 12 }`

After upgrading, each device sends every row it holds again, sealed,
once per key epoch, and every file it holds under its new name. When
its outbox has drained with nothing refused that could still pass, and
every file is on the server under its new name, it says so here, and
the server deletes every row it still keeps in the clear and every row
of a retired table. 409 `conflict` with no PIN set (nothing can have
been sealed); 409 `key_changed` under an epoch that is not the
account's. Asking again drops nothing more.

Files sent before Phase 7 under their plain hash are not deleted by
this call: no row names them once the rows are sealed with the new
names, and the daily sweep lets them go 30 days after they were last
sent or asked about — the grace every unnamed file gets, since a file
uploaded a moment before its row cannot be told from one no row will
ever name. For those 30 days the server still holds the old name of a
picture it already had.

## Push

`POST /v1/sync/push`

```json
{ "deviceId": "…", "keyEpoch": 1, "records": [ … up to 500 … ] }
```

A batch is at most 500 records and at most **4 MB** of JSON
(`maxPushBytes`): a client fills a batch until the next record would
take it past that. The server's own body limit is 5 MB (nginx's 6 MB);
a body over it is refused whole with **413 `payload_too_large`**, and
the client halves the batch. A single record too large for any push is
refused on the device itself, flagged like a refused row with the issue
`too_large`, so it never holds every later change behind it. `keyEpoch`
is required whenever the batch has a sealed record (the sync key,
below); a sealed record refused with `key_changed` stays queued on the
device, which forgets its key, says the PIN was changed on another
device, and sends it again under the new key once the PIN is entered.
The web runs one sync at a time across all its tabs (a browser-wide
lock), reads the outbox once per run, and applies a pull page in one
transaction over only the tables it touches, reading the page's local
rows and pending changes in bulk.

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
right for one instance and must move into MongoDB before there are two.
The lock is taken once the body has arrived, and the account is checked
again under it: a push that was still on its way when the account was
deleted writes nothing (401). A batch is applied in one go — one read
of the stored clocks, one sequence range in the batch's order, one
ordered bulk write — and a row sent twice in one batch is judged
against its own earlier copy, as one by one. The answer:

```json
{ "results": [ { "table": "…", "uuid": "…", "status": "applied" | "stale" | "invalid", "issues": [ … ] } ], "cursor": 1834 }
```

A client clears an outbox row once its record comes back `applied` or
`stale`. An `invalid` one is flagged: it stops being pending (the
circle does not stay amber for it), is counted in Settings → Account
and logged, and goes again only when the row changes again. A row the
first snapshot sends is flagged the same way when it is refused.

An `invalid` answer whose issues are only ones that can pass —
`quota_exceeded`, `clock_ahead`, `clock_too_far` — says so in words on
the account screen, and the row goes again an hour later. A `429` on
the sync or file routes is waited out for as long as `Retry-After`
says (a minute at most, three tries), and a pull page may end early
with `more: true`; the client keeps pulling.

On `stale` the server's copy is the one to keep: the pull that follows
takes it even when its clock only ties with the local one, and if it
is already behind the cursor, the next sync pulls the history again
to fetch it.

**Clocks only move forward per row.** A row pulled with a clock ahead
of the device's own (another device's clock runs fast) is remembered,
and a later local edit of it is stamped just after that clock rather
than at the device's `now`, which would lose as `stale`.

**Each account may keep 256 MB of rows**, counted as the stored size
of each row's `data` or `enc` plus 256 bytes for the rest of it. A
record that would grow the store past that comes back `invalid` with
the issue code `quota_exceeded`; one that shrinks it (a purge, a
shorter note) always lands. The total is kept on the account's counter
and charged in the same step that takes the room, and an account from
before it was kept has it filled in from its rows the first time.

## Pull

`GET /v1/sync/pull?after=<seq>&limit=<1..1000>&deviceId=<id>`

```json
{ "records": [ { …record…, "seq": 1835 } ], "cursor": 1900, "more": false }
```

Records come in sequence order, at most `limit` of them and at most
8 MB of them past the first: a page ends early, with `more: true`, where
the bytes run out, and a single row bigger than that still comes, alone.
The server reads the rows a batch at a time and never holds more than
the page. The client merges each one by the same rule as the server:
- a local row missing, or older than the record, is overwritten;
- anything else is ignored.

A purged record hard-deletes locally. The client then stores `cursor`
and pulls again while `more` is true.

**A device's own writes do not come back.** With `deviceId`, the pull
leaves out what that device pushed itself and still moves `cursor` past
it, so `cursor` can be past the last record (and a page can be empty
with `more: true`). A device rebuilding its store from nothing (after
`after=0` because its store was lost or wiped) leaves `deviceId` out and
gets its own writes back.

Every `/v1` answer carries `Cache-Control: no-store` (the release proxy
alone may be cached), so nothing pulled is left in a browser's disk
cache, and sign-out answers with `Clear-Site-Data: "cache"`.

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
- when the app starts, and on app resume (the web: on focus);
- two seconds after the last local write;
- every 15 minutes while the app is open — on the web, every minute
  while the page is visible, and other tabs of the same browser are
  told at once;
- when I ask for it (Sync now, in Settings → Account or the account
  circle), and right after signing in or setting the sync PIN.

The phone's 3 AM job does not sync: it judges the day that ended,
closes its steps, plans the reminders and refreshes the widget. A day's
changes go up the next time the app is open.

It never runs more than once at a time.

## Both clocks are finer than a second

The phone used to store its dates as whole seconds while the web wrote
milliseconds, so two edits to one row inside the same second could tie,
and a tie went to whichever reached the server first. Schema v18
stores the phone's dates as ISO-8601 text, microseconds and all: a tie
now needs two edits inside one microsecond. The migration converts
every stored date with sqlite's own `datetime(col, 'unixepoch')`, so
the instant is the one that was already there and only its spelling
changes.

## Files

Pictures and voice notes are not rows. Each device knows a file by the
SHA-256 of its plaintext; the server knows it by its **name**, since
Phase 7 (M7.2) a keyed hash of that: HMAC-SHA256 of the hash's hex
under the **name key**, HKDF-SHA256 of the sync key with the info
`harvest/file-name/v1`. Two devices with the key agree on the name, so
the same picture on two phones is one file on the server and travels
once; a server holding a known picture cannot tell whether an account
has it. A file stored before under its plain hash is fetched by that
name when the new one is not there, and sent again under the new one.

| Route | What it does |
| :--- | :--- |
| `POST /v1/files/missing` | Takes up to 500 names (the body's key is still `hashes`) and answers with the ones the account does not have, plus what it is using and what it may use. Nothing is uploaded before this asks. |
| `PUT /v1/files/<name>` | The bytes, padded (`0x80` then zeros, to the padded length of one byte more) and sealed with the private tier's key under the additional data `file/v3/<name>`, as `application/octet-stream`. The nonce travels in `x-harvest-iv`, the padded length in `x-harvest-plain-bytes` (never the file's own), and the key epoch it was sealed under in `x-harvest-key-epoch` (409 `key_changed` when it is not the account's). 201 when it was stored, 200 with `had: true` when the server already had it. |
| `GET /v1/files/<name>` | The bytes back, with the same two headers. |
| `DELETE /v1/files/<name>` | Lets the file go and gives its room back, by the sweep's rule (below): **409** `conflict` while a row, live or in the trash, still names it, or within 30 days of its upload or of a `missing` answer that said the server has it — the sweep lets it go later. Otherwise 204, whether or not the account had it. |

- **A file may be 25 MB** before sealing (a little more once padded),
  and an account may keep **2 GB**; past that
  the answer is `quota_exceeded` (507). The room is charged on the
  account's counter before the bytes are stored, in one atomic step, so
  two uploads at once cannot both take the last of it.
- **The bytes live in GridFS** (the `file_blobs` bucket), in chunks of
  255 KB, beside a small document per file. A MongoDB document stops at
  16 MB and a file may be 25, and a download goes out as a stream, a
  chunk at a time, instead of whole in memory. A file stored before
  that keeps its bytes in its document and is read from there.
- An upload that was still arriving when its account was deleted
  stores nothing (401).
- **A file that keeps failing to go waits.** The browser tries it
  again after a minute, then after twice as long each time, up to an
  hour; after three failures the gallery says some pictures could not
  be sent. A file that reaches the server is forgotten by that count.
- **A file opened in the browser is only ever a picture, a clip or a
  recording.** Its type comes from its first bytes (JPEG, PNG, WebP,
  GIF, HEIC, MP4, QuickTime, WebM, Ogg, WAV, MP3, M4A); anything else
  is kept untyped, so a file that holds a page or an SVG never runs as
  the app.
- **Files no row names are let go.** Once a day the server looks at
  each account's `memories` and `note_attachments` rows — the only rows
  that name a file — by their clear `file` (or, for one stored before
  Phase 7, its `data.fileHash`), and deletes the files none of them
  names. A row in the trash still
  names its file; a purged one does not. A file is kept anyway for 30
  days after it was uploaded or last reported as held by
  `POST /v1/files/missing`, because a device may name it in a row it has
  not pushed yet. A table that one day names a file gets a `fileHash`
  column, and with it the `file` field.
- **The name is a claim the server cannot check**, having no key. That
  is safe: a wrong name only ever misleads the account that wrote it.
  The reader checks, though — bytes that do not hash to the name they
  came under are dropped rather than written.
- **A row that names a file carries its hash inside, and its name
  outside**; the other device opens the row and fetches by the name. Files travel only once a sync PIN is
  set, because they go sealed or not at all.
- **A file never holds up a row, or another file.** One over 25 MB is
  left on the device and never sent; one that fails is tried again on
  the next sync; neither stops the others going up or coming down.
- **A named file is not a file the server has.** After an archive is
  restored, or on signing in to another account or server, the next
  pass asks `missing` about every named file, not only new ones, and
  sends what the server lacks.
- **A picture on screen that has not arrived** is fetched then, on its
  own, and drawn when it lands ([[Gallery]] G9); the pass itself
  carries twenty at a time.

## The sync key

The private tier's key is mixed from the PIN and a **key share** the
server holds for each account ([[Accounts]]): 32 random bytes, made the
first time they are asked for, and stored sealed (AES-256-GCM, the
additional data `key-share/<user id>`) under `KEY_SHARE_KEY`, a key
that lives in the server's environment and never in the database. The
schemas are in `packages/contracts` `sync-key.ts`; the derivations in
`crypto.ts`, pinned by `fixtures/crypto-v2.json`:

    base  = PBKDF2-HMAC-SHA256(secret, syncSalt, 600,000, 32 bytes)
    proof = HKDF-SHA256(base, salt = empty, info = "harvest/sync-pin-proof/v1", 32 bytes)
    key   = HKDF-SHA256(base, salt = keyShare, info = "harvest/sync-key/v2", 32 bytes)

**Once a PIN is set, the share leaves the server only for a device that
proves the PIN, online.** The first device stores the *verifier*, the
SHA-256 of its proof; the server seals it like the share (additional
data `pin-verifier/<user id>`). A later device sends its proof, and the
server hands out the share only when the proof's SHA-256 is the
verifier. Wrong proofs are counted in the database per account: **5 in
15 minutes and 20 in a day**; a right one starts the short count again.
Nothing the server hands out before a right proof lets anyone try PINs
offline, so a stolen session gets a handful of guesses, not a million.

| Route | What it does |
| :--- | :--- |
| `GET /v1/me/sync-key` | `{ "state": "none" \| "set", "salt": "…", "epoch": 1 }`. While `state` is `none` it also carries `"keyShare"` (base64, 32 bytes): nothing is protected yet, and the first device needs it to choose. It never carries the check or the verifier. |
| `POST /v1/me/sync-key/unlock` | Body `{ "proof": "<base64, 32 bytes>" }`. **200** `{ "keyShare", "check", "epoch" }` for the right PIN; **403** `{ "error": { "code": "wrong_pin", … }, "triesLeft": 3 }` for a wrong one; **429** with `Retry-After` past the limit; **409** `conflict` while no PIN is set (choose instead). |
| `PUT /v1/me/sync-key` | Body `{ "verifier": "<hex SHA-256 of the proof>", "check": <envelope> }`, only while no PIN is set. **201** `{ "epoch" }` (the same pair again, a retry, is 201 too); **409** `conflict` when another device chose first. |
| `DELETE /v1/me/sync-key` | Body `{ "password": "…" }`. Starts the private tier over (below). **204**; **403** `forbidden` for a wrong password. |

- The check is a version 2 envelope (`v: 2`, a 12-byte nonce, at most
  256 characters of `ct`) sealing the text `harvest-key-check` with the
  additional data `key-check`. The server keeps it and cannot open it; a
  device opens it after unlocking, to be sure of its key.
- **Choosing.** `GET` says `none`: the device derives the key and the
  proof from the PIN typed twice, seals the check, and `PUT`s the
  verifier and the check before it seals anything. On a 409 another
  device chose first, and it unlocks with the same PIN instead; if that
  is refused, it says a PIN was chosen elsewhere.
- **Entering.** `GET` says `set`: the device sends its proof to
  `unlock`, and with the share it derives the key.
- The routes need a verified account, and share a limit of 60 requests
  per account per 15 minutes (the unlock count comes on top). All of it
  goes with the account.

**The key epoch** names the key the private tier is under: 1, and one
more with every start over. Every sealed write says which one it was
made under:

- a push carries `keyEpoch` whenever it has an `enc` record; with any
  other epoch (or none), every sealed record comes back `invalid` with
  the issue code `key_changed`, and a tombstone still lands;
- a file upload carries the header `x-harvest-key-epoch`; with any
  other (or none) the answer is **409 `key_changed`** and nothing is
  stored, not even as "held".

So nothing is ever stored under a key the account no longer has. A
device that meets `key_changed` drops its key, says the PIN was changed
on another device, and asks for it again. The epoch in `GET` is also the
cheap way to notice before a sealed push.

- **Starting over** (a forgotten PIN, or changing it) asks for the
  account's password, counted with the same 5 wrong ones per 15 minutes
  as deleting the account, and runs under the account's lock. It drops
  the verifier, the check, the key share, the wrong-PIN count, every
  sealed row and every file, moves the epoch on, and leaves only rows
  still in the clear from before Phase 7. The share is made anew on the next `GET`, so
  nothing sealed before can be opened again, even with the old PIN. The
  sealed rows are deleted outright, with no tombstone: a pull never
  hands them out again, whatever the cursor. The byte totals are filled
  in again from what is left.
- **How a device learns of it**: the epoch `GET /v1/me/sync-key`
  answers is not the one it holds its key under (or a sealed write comes
  back `key_changed`). It drops the key and asks for the PIN as on a new
  device, and whatever rows and files it still holds it sends
  again under the new key.

## What the server can see

Since Phase 7 the server holds nothing it can read of what I keep
([[Phase-7-Privacy-and-Currencies]]); what it still sees is how the
store is shaped. For every row:

- its **table** (`notes`, `expenses`, `trail_days`…) and its **key**:
  a random uuid for most, the day for `step_days`, the scope for
  `streaks`, the setting's name for `kv_settings`, the program and
  exercise ids for `training_maxes`, and a keyed hash for a day of the
  trail;
- its **clocks** (`updatedAt`, `deletedAt`), to the microsecond, which
  the conflict rule compares — so the server can tell *when* I changed
  things, not what; the trail's are rounded to the hour;
- **which device** wrote it last (an id the device made up), for the
  pull to leave its own writes out; no arrival time is kept;
- the ciphertext's **length**, padded, so it tells a big note from a
  small one and not much more;
- for a row that names a file, the file's **name** — a keyed hash, of
  no use without the key.

For a file: its name, its padded size, and when it was uploaded and
last asked about (the sweep's grace needs them). For the account: see
[[Accounts]] — the address and the name are sealed with a key from the
server's environment, not the database. The request log keeps method,
path, status and time; neither it nor nginx's keeps an address.

## Limits

Every limit answers `rate_limited` (429) with `Retry-After`.

| What | Limit | Keyed by |
| :--- | :--- | :--- |
| Sign-in failures | 5 per 15 minutes | address |
| Sign-in failures | 20 per hour, stored in MongoDB so a restart does not reset them, gone when the hour is | email and network (/24 for IPv4, /48 for IPv6), under the server's lookup key: one machine can only lock an email out for itself |
| Sign-in failures | 200 per hour, the ceiling from everywhere together | email (keyed hash; an address with no account counts the same) |
| Reset and verification mails | 3 per hour and 10 per day to one address; past it nothing is sent and the answer is still 202 | recipient (keyed hash) |
| Sign-up | 5 per hour (a body that did not parse does not count) | address |
| Other `/v1/auth` routes that hash or mail | 30 per 15 minutes | address |
| Refresh | 120 per 15 minutes | address |
| Wrong password on `DELETE /v1/me`, `DELETE /v1/me/sync-key` or `POST /v1/me/reauth` | 5 per 15 minutes, shared | account |
| `/v1/sync` | 120 per minute | account |
| `/v1/files` | 300 per minute | account |
| `/v1/me/sync-key` | 60 per 15 minutes | account |
| Wrong PINs on `POST /v1/me/sync-key/unlock` | 5 per 15 minutes and 20 per day, in MongoDB; a right one starts the 15 minutes again | account |
| The server assist | 50 per account and 1,000 for the whole server per UTC day (`ASSIST_DAILY_LIMIT`, `ASSIST_GLOBAL_DAILY_LIMIT`) | account, server |

Password hashing (argon2id, 19 MiB each) runs at most four at a time
across sign-up, sign-in, reset and deleting the account, with at most
64 waiting; past that the answer is 429 and `Retry-After: 5`.

Nothing waits for ever. A push, an upload, a file delete or deleting
the account waits at most 30 seconds for the one before it on the same
account; past that the answer is 429 and `Retry-After: 5`, which the
clients already wait out. One database operation may take 30 seconds
(a download's reads, 30 seconds each batch of chunks). The server
assist gives the model a minute for the whole answer, then ends the
stream with `{"error":"unavailable"}`; it stops reading the model as
soon as the caller goes away.

A right password, and a password reset, clear every sign-in count of
the email. "Forgot password" and "resend" answer 202 before they look
anything up, and do the work after, so an address with an account is
not slower to answer than one without.

Signing out with a refresh token ends the session only when it is the
current token, or one exchanged within the last 30 seconds: an old one
from a log or a backup does nothing.

Bodies are read only once the caller is known, and only as large as the
route needs: 16 kB for `/v1/auth`, `/v1/me` and the sync key, 64 kB for
`POST /v1/files/missing`, `BODY_LIMIT` (5 MB) for `/v1/sync`, 25 MB of
raw bytes for a file, and the assist's own cap for `/v1/assist`. The
auth bodies are strict: a key the contract does not name is refused.

## Other routes

| Route | Auth | Purpose |
| :--- | :---: | :--- |
| `GET /v1/health` | – | Liveness, for the host |
| `POST /v1/auth/register` · `login` · `refresh` · `logout` · `verify-email` · `resend-verification` · `forgot-password` · `reset-password` | – | [[Accounts]] |
| `GET /v1/me` · `PATCH /v1/me` · `DELETE /v1/me` | ✓ | The account |
| `POST /v1/me/reauth` | ✓ | The password again, before a device writes my data out (Phase 7, M7.6): 204, or 403 `forbidden` |
| `POST /v1/sync/sealed` | ✓ | A device has sealed everything (above) |
| `POST /v1/me/heartbeat` | ✓ | Once a day: platform, version, the streak while shared ([[Admin]]) |
| `GET /v1/announcements` | optional | The news live now; with a session, the account holders' too |
| `GET /v1/push/key` · `POST`/`DELETE /v1/me/push-subscription` | – / ✓ | Web Push: the server's VAPID key, a browser's subscription |
| `POST /v1/reports` | – | A report of a problem, anonymous: no session read, no address kept, 5 an hour per network ([[Admin]]) |
| `GET /v1/admin/overview` · `history` · `users` · `announcements` (+ `POST`, `PATCH`, `DELETE`) | admin | The admin panel ([[Admin]]); 404 to anyone else |
| `GET /v1/me/sessions` · `DELETE /v1/me/sessions/:id` | ✓ | Devices |
| `GET /v1/me/sync-key` · `PUT /v1/me/sync-key/check` · `DELETE /v1/me/sync-key` | ✓ | The sync key (above) |
| `GET /v1/releases/latest` | – | The newest APK, for the download page ([[Web]]), and the newest pre-release above it when there is one |
| `GET /v1/releases/download/:name` | – | One APK the download page offers (`apk` or `legacyApk` of either release), fetched from GitHub and handed on as an attachment; any other name is 404. Twenty an hour per address (Checkpoint 12, B12-05) |
| `POST /v1/assist` | ✓ | The server assist ([[ADR-013-Assist-Providers]]), in a later milestone |

Related: [[Sync-Strategy]] · [[Accounts]] · [[ADR-011-Backend]] · [[ADR-005-Local-First-Sync]]
