# Phase 7 — Privacy, and every currency

Specs: [[Accounts]] · [[Sync-API]] · [[Finances]] · [[Web]]. Written 2026-09-28, after the sixth audit ([[Audit-v3.1]]), and put ahead of screen time: this goes in before Harvest runs anywhere that is not my own server ([[Roadmap]]).

## Why

Today the server stores two tiers ([[Sync-API]], *What the server can see*). Money, places and the picture and recording files are sealed on the device with a key the server does not have. Everything else — notes, seeds, check-ins, goals, lists, gym, body weight, sleep, steps, picture captions, settings — is stored as it is. So whoever runs a server can read my notes and my health, and, from the sealed rows' metadata and the request logs, can still follow when and roughly where I move.

The rule this phase sets: **the person who runs the server learns as little as possible — no notes, no files, no location, no health — and nothing leaves a device unencrypted.** The server becomes a blind store: accounts, ciphertext, and the least metadata sync can work with.

Where I am today, for the record:

| | On the phone | In the browser | In transit | On the server |
| :-- | :-- | :-- | :-- | :-- |
| Money, places | SQLCipher database, key in the Keystore | Plain in IndexedDB | HTTPS, and sealed | Sealed |
| Picture and recording files | Plain files in the app's private folder | Plain in IndexedDB | HTTPS, and sealed | Sealed, named by the plaintext's SHA-256 |
| Notes, seeds, goals, lists, gym, body, sleep, captions, settings | SQLCipher database | Plain in IndexedDB | HTTPS | **Plain** |
| Email, name | — | — | HTTPS | **Plain** |
| Password | never stored | never stored | HTTPS | argon2id hash |

## M7.1 — Nothing leaves a device in the clear

- [ ] **Every synced table moves to the private tier**: notes, note links and attachments, seed notes, seeds and check-ins, streaks and the XP ledger, goals and their items, lists and their items, the gallery's rows (captions, albums, days), gym, body weight, sleep, steps, focus sessions, and the portable settings. The server keeps only what it needs to route a row: the table, the row id, its clocks, its size.
- [ ] The server refuses a plain row for any table the contract calls private, and says so (`sealed_required`).
- [ ] **Migration**: the first sync after upgrading seals and sends every row again; once a device confirms it has sent its copy, the server deletes the plain copies. An old client meeting a new server is told to update, and its plain rows are refused, not stored.
- [ ] Anything the server used to read from a plain row (none today: it computes nothing, [[ADR-011-Backend]]) is checked for, and rankings in [[Phase-9-Social-and-Reach]] are rethought as an opt-in, separately published number, never read from my rows.

## M7.2 — Files the server cannot recognise

- [ ] A file is named by an HMAC of its bytes under a key derived from the sync key, not by the SHA-256 of its plaintext: two of my devices still agree on a name, but a server holding a known picture can no longer check whether my account has it.
- [ ] Sizes are rounded up into buckets (padding before sealing) for files and for long rows, so a length does not tell a note or a place apart.

## M7.3 — The server cannot follow where I am

- [ ] **The location trail syncs as one sealed row per day**, rewritten as the day goes on, instead of one row per point: the server no longer learns the timing and count of my movements from row clocks.
- [ ] Geotags travel inside the row they tag (the expense, the check-in, the note) rather than as rows of their own.
- [ ] **No IP addresses at rest**: the server's request log, nginx's access log and the rate limiters keep none. The limiters already hash the network; the logs drop the address, or keep only a truncated one for an hour at most for abuse, and the deploy sets that up.
- [ ] Clock precision on sealed rows goes down to what last-writer-wins needs, and the arrival time is not kept beyond the sync cursor.
- [ ] Written down, honestly: map tiles come from OpenFreeMap and Esri directly from the device, so they see which area I look at; the server never does.

## M7.4 — Encrypted at rest on every device

- [ ] **Phone**: picture and recording files sealed on disk with a key in the Keystore, like the database; the gallery opens them in memory. Existing files converted on first start, checked, then the plain copies deleted.
- [ ] **Web**: the IndexedDB store sealed with a non-extractable key kept by the browser, so the files of a browser profile read on another machine show nothing. Written down plainly: it does not protect against someone using the same browser while I am signed in; signing out still wipes everything.
- [ ] The exported archive and spreadsheet stay plain on purpose — they are mine to take elsewhere — but see M7.6.

## M7.5 — A passphrase first, a PIN if I insist

- [ ] The sync secret screen **recommends a passphrase** (a few words) and shows how long each would stand against someone holding both the database and the server's secrets: seconds to minutes for a PIN, beyond reach for a good passphrase. The PIN stays available, one tap away, with that trade-off written next to it.
- [ ] A strength meter on the passphrase (length and common-word checks from the shared rules), the same on both clients.
- [ ] The reasoning, in [[Accounts]]: from the outside, an account with a PIN and one with a passphrase look the same, so an attacker cannot pick out the weak ones without trying every account — but anyone with the database and the environment can try every PIN of every account in minutes. Only a passphrase protects against that, which is why it is the default.
- [ ] Changing from a PIN to a passphrase later is the existing *Change PIN* (start over), worded for it.

## M7.6 — Taking my data out asks who I am

- [ ] **Download my data** (the zip archive, the spreadsheet) asks for the account password on the web, and on the phone either the account password or, without an account, the phone's own lock (fingerprint or screen lock), before anything is written.
- [ ] A wrong password counts against the same limit as *Delete account*; the server checks it (`POST /v1/me/reauth`, a short-lived proof), so a stolen web session alone cannot export.

## M7.7 — The server's own data at rest

- [ ] **Backups encrypted** (`age`, to a key that is not on the server) and kept off the server; `deploy.sh` makes them that way and the plain archives already in `/root/harvest-backups` are replaced.
- [ ] The database volume on an encrypted disk, or the host's encryption documented in [[Deployment]] as a requirement.
- [ ] **Email addresses**: looked up by a keyed hash, kept encrypted under a key from the server's environment for the mail that needs them; the display name sealed like a row. A copy of the database then holds no readable address.

## M7.8 — Every currency, the right one by default

- [ ] **All ISO 4217 currencies**, with their symbol, minor units and name in English and Arabic, in `packages/core` with a fixture both clients read.
- [ ] **The default follows where I am**: the phone's locale, then its SIM or network country; the web's browser language and time zone. The server's IP-based guess is only a fallback, worked out in memory and never stored (M7.3). Always changeable in Settings.
- [ ] **Exchange rates for every currency** from a free source that covers them (the current one covers about thirty and not the dinar), fetched by the device, cached, with the date shown.
- [ ] **The dinar's parallel-market rate** (DZD against EUR and USD, typed by hand) shows only when my currency is DZD; nobody else sees DZD, EUR or USD singled out.
- [ ] Old data keeps its currency; nothing is converted without asking.

## M7.9 — Saying all of it

- [ ] **The privacy statement** (`apps/web/src/pages/site/privacy.tsx`, English and Arabic) rewritten to what is true after this phase: what stays on the device, what the server holds and cannot read, the metadata it still sees, the third parties (the mail provider, the map tiles, the assist when I use it, the exchange rates) and what each receives, how long anything is kept, how to export and delete.
- [ ] [[Accounts]], [[Sync-API]] (*What the server can see*) and [[Deployment]] brought up to it; a data map page listing every field and where it lives.
- [ ] An audit of this phase alone, by hand, with a server dump read as its operator would.

**Exit:** a dump of the production database and its logs, read by me as the operator, shows no note, no file, no place, no health figure, no email and no IP address; both apps work as before on top of it; `v3.2.0`, then production.
