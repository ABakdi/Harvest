# Checkpoint 11 — A PIN the server checks, and the sixth audit

On top of `v3.1.0-beta.1`, released as `v3.1.0-beta.2`. Beta 1 was
tagged but never published or deployed, and before it went out I read
the whole tree again, deeper: security, code quality and performance on
a seeded account of 31,438 rows, and both apps by hand
([[Audit-v3.1]]). It found 140 things, none of them losing data, and
this beta closes every one. Because beta 1 never reached anyone, its
sync key protocol could still change without a migration, and it did.

## 1. The PIN is checked by the server

In beta 1, any signed-in session could fetch the salt, the key share
and the key check in one request, and then try every 4–6 digit PIN
offline in about a minute. A stolen session was as good as the PIN.

Now the key share leaves the server only after the device proves it
knows the PIN ([[Accounts]], [[Sync-API]]):

- One slow derivation from the PIN gives two things: the **proof**,
  shown to the server, and the key, which never leaves the device. The
  proof is not the key, and the key cannot be had from it.
- The server keeps a **verifier** of the proof, sealed like the share
  under a key that lives only in its environment, so even a copy of the
  database can't be searched for the PIN.
- **Five wrong tries in 15 minutes, twenty in a day**, counted in the
  database, then a pause with the minutes said. Three tries or fewer
  left are said too.
- Every account has a **key epoch**, moved on by every start over.
  Every sealed push and file upload names the epoch it was made with,
  and the server refuses a stale one. A device that missed a start over
  is told "Your PIN was changed on another device" and asked again,
  instead of storing something no device can open.

## 2. Sync that holds up under a real account

- **First sync of a large account on the web**: 95 s with the page
  frozen for 17 s of it, now 13.8 s with one 52 ms pause.
- **Pushing**: a batch is filled by bytes and halved when too large, so
  one big row can no longer stop sync for good. The server writes a
  batch in one go: about 480 rows a second before, 9,700 now.
- **Files**: bytes live in GridFS, so a clip between 16 and 25 MB syncs
  at last. Files stored before still read. Thirty parallel downloads
  use 63 MB of memory, not 513.
- A pull leaves out what the device itself just sent. Tabs of the web
  share one sync and one key. Nothing on the server waits forever: a
  busy account answers "try again in 5 seconds" after 30.
- On the phone, the database opens behind a first frame drawn at once,
  a Keystore error shows a retry screen instead of starting empty over
  my data, and the tables sync reads most have indexes (schema v25).

## 3. Accounts

- **Signing in on a phone that already has data asks first**: bring
  this phone's data into the account, or start from the account's data
  (this phone's is saved as an archive in Downloads first). Onboarding
  has an "I already have an account" path.
- The sync mark says its state with a shape, not only a colour.
  Devices can sign out every other device at once.
- Signing out while offline really ends the session once back online.
  `/v1` answers are never cached by the browser. Sign-in failures are
  counted per address and network, so nobody can lock me out from one
  place. Common passwords with digits or leetspeak added are refused.

## 4. The phone and the web, polished

- **The phone** shows how far today's actions are toward the daily
  harvest ("2 of 3"). Achieving then deleting a goal takes its XP back.
  Notes Assist works, and an empty new note is discarded. Planned
  purchases opens the list and Back returns to the Granary. The money
  sheets have a keypad with `+`, and the brand colours used as text
  meet 4.5:1 contrast in every look. Dusk is one shade deeper on both
  apps.
- **The web** has an error screen instead of a stack trace, reloads
  once when an update removed the code it needs, and notices going
  offline at once. User text follows its own direction in Arabic, and
  pages hold at 200% text. It opens `/app` with 40 KB less script, draws
  the Places list before the map, and installs 2.1 MB instead of 4.7.
- Both apps refuse typo amounts and weights by one shared rule, and
  work out the average per day the same way.

## Tried by hand

- The published beta 1 on the emulator with two habits and 80 XP, then
  this beta installed over it: the data kept, and "2 of 3 actions" on
  the Field.
- Against a server of this code: signing in again, the join question,
  choosing a PIN on the phone. A browser then refused a wrong PIN,
  opened with the phone's PIN and saw the phone's seeds; its expense
  showed on the phone.
- Two browsers: choose, a wrong PIN with the tries left, start over in
  one, "changed on another device" in the other, the old PIN refused
  and the new one opening the other's expense. A common password
  refused at sign-up. Arabic at 390 pixels, right to left, Western
  digits, nothing wider than the screen.

This pass found three phone bugs that no test had caught (H6-01 to
H6-03 in [[Audit-v3.1]]). Setting a PIN hung on Android, where the
platform's HMAC refuses the empty salt of the proof. Signing in again
went nowhere, because the first request left before the saved server
address was read. And the PIN sheet stayed open with a wrong message
when the session had ended. All three are fixed, with tests.

Tests: phone 1,455, web 687, core 422, contracts 227, server 159.

Related: [[Audit-v3.1]] · [[Accounts]] · [[Sync-API]] · [[Web]] · [[Checkpoint-10]]
