# Checkpoint 10 — A PIN, a phone in the browser, and the fifth audit

On top of `v3.0.0`, released as `v3.1.0-beta.1`. The first day with
v3.0.0 live on my own server showed three things wrong in use: the
Granary would not sync because the passphrase wanted twelve characters,
a picture opened on the web as an empty frame, and installing the web
app on my phone said *installing* and never finished. Fixing those
turned into a round of its own, and then into the fifth audit
([[Audit-v3]]), whose findings are all closed here.

## 1. A sync PIN, and a key a copy of the database cannot open

The passphrase became a **PIN of 4 to 6 digits** — or a passphrase of 8
or more for whoever wants one — with the same rule on both clients
([[Accounts]] AC7). A PIN has at most a million values, so on its own
it would fall to anyone holding a copy of the database. Two things
stop that:

- **A key share.** Every account has 32 random bytes on the server,
  kept sealed under a key that lives only in the server's environment,
  never in Mongo. The key is made from the PIN *and* that share, so a
  dump of the database or a backup alone opens nothing.
- **A key check.** The first device stores a small sealed value; every
  other device must open it before it keeps a PIN. Whether I *choose*
  or *enter* a PIN is now the server's answer, a wrong PIN is refused on
  the spot, and a row that won't open is counted as locked instead of
  costing a device its key. Before this, a fresh browser could choose a
  second PIN and stop the private tier on every phone for good.

Envelope v2 binds a row's clocks into what it seals, so the server
cannot roll a private row back. PINs like `1234`, `0000` or `1212` are
refused. **Forgot the PIN? Start over**, with the password, drops what
the server holds of the private tier and lets me choose a new PIN; each
device that still has its money, places and pictures sends them again.
That is also how the PIN is changed. Because the key changed, the PIN
is asked for once more after upgrading.

Signing in now asks for the PIN straight away, and **the account
circle** sits top-left on every tab of the phone and at the top of the
web: the account, online or offline, the last sync, what is waiting,
*Sync now*, the PIN, the devices, sign out.

## 2. Pictures that say why

A picture whose file is not here yet says so — *still on the phone*,
*enter your PIN to see it*, *downloading…*, or *couldn't load* with
*Try again* — and fetches that one file on its own ([[Gallery]] G9).
The empty frame was the web waiting for a file the phone had never sent,
because no PIN meant no upload.

## 3. The web, laid out like the phone

Below 768 pixels the web is the phone: the same bottom bar in the same
order (Field · Granary · Records · Body · Farmer, the optional ones only
when switched on), the same top tabs, the account circle top-left and a
back arrow on pushed screens, the primary action as a floating button,
forms as bottom sheets that drag down to close, the bar out of the way
of the keyboard, safe areas respected when installed. The Granary has
the phone's three tabs — Today, Balances, Insights — and the Field's bar
has the streak and the archive, which the web now has too. Every page,
tab and sheet was checked at 360, 390 and 412 pixels in English and
Arabic: no sideways scrolling, nothing clipped, no tap target under 44
pixels.

**Numbers are Western digits everywhere**, Arabic included; three
Arabic strings that still had Eastern digits are fixed, and a test fails
on any that come back. The phone's Arabic plurals now have their forms
for 11 to 99 and 100 up.

The install that never finished happened while the domain was still
moving to its new address, and Android builds an installed web app by
fetching the manifest and icons from the site itself. The manifest also
listed an SVG icon beside the PNGs; it now lists PNGs only, and the
button says the install is on its way.

## 4. The fifth audit

Two reads of the whole tree — security, and quality with the gaps
between the phone, the web and the specs — found 104 things, and the
first audit's S-04 was still open ([[Audit-v3]]). All are closed: 103
fixed, the sign-up answer mitigated by its own limit and written down as
the one exception to AC3, and what the server can see of sealed rows
written down in [[Sync-API]]. The larger ones:

- **The phone's database is encrypted at rest** (SQLCipher), under a
  random key in the Android Keystore; an existing file is converted in
  place on first start and checked table by table ([[Local-Database]]).
- **The server**: a pull pages by bytes instead of holding everything in
  memory, rows have a quota, the database runs with authentication,
  mail requires TLS, every password check is limited and bounded,
  bodies are parsed only after authentication, a lost refresh answer
  no longer signs every device out, and files can be freed.
- **Sync**: a pull never overwrites a newer edit waiting to go, deletes
  don't come back, a skewed clock can't leave a device behind for good,
  and rows an older app can't read wait instead of being skipped.
- **Streaks** break when a day is missed even if another device checked
  in later, and a milestone pays once.
- **Money**: the Granary rolls over at 3 AM, Undo can't charge the
  wallet twice or overpay a debt, a debt can be edited and deleted, and
  changing the currency converts the budget.
- **The rest**: a note title used twice no longer loses typing, an
  Arabic note prints as Arabic, the gym counts the sets left right,
  loads round to what the plates can make, a target weight can be set,
  and the public site's first script went from 588 kB to 204 kB.

## Tried by hand

- The published v3.0.0 on the emulator with a seed, an expense and an
  account, then this beta installed over it: the data kept, the
  database file encrypted, the PIN asked for, `123456` refused, the
  expense on the server sealed as v2.
- The web at 390 pixels, English and Arabic: the wrong PIN refused, the
  right one opening the phone's expense, the map drawing, right-to-left
  with Western digits, nothing wider than the screen.
- The web and a phone client reading each other's private rows and a
  picture through the server.

Tests: phone 1,360, web 650, core 395, contracts 209, server 126.

Related: [[Audit-v3]] · [[Accounts]] · [[Sync-API]] · [[Web]] · [[Checkpoint-9]]
