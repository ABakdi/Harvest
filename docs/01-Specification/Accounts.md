# Accounts

Phase 6 ([[Phase-6-Sync-Accounts-and-Web]]). An account is how my
phone, my laptop and any later device agree they are all me. It is
**optional forever**: [[Business-Rules]] #5 says the app is complete
without one, and nothing in the app may ask for one except sync and
the server assist.

## What an account holds

| Field | Why |
| :--- | :--- |
| Email | To sign in, and for the two emails the server ever sends: verify, and reset. Kept as a keyed hash to find it by and a sealed copy for the mail, both under keys from the server's environment (Phase 7, M7.7): a copy of the database holds no readable address |
| Password hash | argon2id ([[ADR-011-Backend]]); the password itself never touches the disk |
| Display name | Shown in the app's header on the web; nothing else. Sealed like the address |
| Verified at | Unverified accounts can sign in but not sync, so a mistyped email cannot quietly own my data |
| Sync salt | The public half of the key derivation for everything that syncs ([[Sync-Strategy]]) |
| Created at, last seen | So the devices page can say which session is stale |

It holds nothing else: no phone number, no birthday, no avatar upload.

## Flows

- **Sign up**: email, password (at least 10 characters, checked against
  the 10,000 most common passwords, no other composition rules), and an
  optional display name. A verification email goes out; its link is
  good for 24 hours and can be re-sent. I am signed in straight away,
  which is why sign-up is **the one place that says an address already
  has an account** ("An account with this email already exists"): a
  deliberate exception to AC3, the price of a session without a trip to
  the mailbox first. To keep it from being a cheap way to test a list
  of addresses, sign-up allows five attempts an hour from one address,
  far fewer than anything else.
- **Sign in**: email and password. Five failures from one address in
  15 minutes rate-limit that address. Twenty failures for one email in
  an hour from one network (the /24 or /48 around the address)
  rate-limit that email *from that network* for the rest of the hour,
  so whoever guesses at my address locks only themselves out; two
  hundred from everywhere together rate-limit it everywhere. The counts
  live in the database, so a restart does not reset them, count the
  same for an address with no account, and go the moment I sign in or
  reset the password. The answer never says whether the email exists.
- **Stay signed in**: a short access token and a rotating refresh
  token. Using a refresh token twice (theft, or a bug) revokes the
  whole family, and every device of that family must sign in again —
  with one exception: the same token again within 30 seconds, while
  the token it was exchanged for is still unused, gets that same token
  back. That is a phone retrying after its answer was lost, not a
  thief. A refresh that fails for any reason but the session (the
  database away for a moment) leaves the web's cookie where it was.
- **Forgot password**: an email with a one-hour, single-use link.
  Resetting the password signs out every device. "Forgot" and "resend
  the link" answer at once, the same for every address, and do the work
  after; one address gets at most three such emails an hour and ten a
  day, whoever asks, and past that nothing is sent. Signing a device
  out takes its current refresh token: an old one found in a log does
  nothing.
- **Devices**: a list of signed-in sessions (the device name the client
  gave, first and last seen), each with *Sign out*, asked first and
  said once it is done. The current one is marked. With two or more
  others, *Sign out all other devices* ends them together; a list that
  could not be read offers *Try again*.
- **Sync secret**: set once, on the first device, to encrypt
  **everything that syncs** — since Phase 7 every row and every file,
  not only money, places and pictures ([[Phase-7-Privacy-and-Currencies]]).
  Without it nothing leaves the device. The screen **recommends a
  passphrase** of a few words (8 characters or more), with a meter of
  how long it would stand, and keeps a **PIN of 4 to 6 digits** one tap
  away (*Use a PIN instead*), with the trade-off written beside it: a
  PIN falls in minutes to whoever holds the server's database and its
  keys together, a passphrase of four random words in thousands of
  years (`syncSecretStrength`, the same estimate on both clients, at ten
  thousand tries a second against the 600,000 rounds of PBKDF2).
  A PIN anyone would try first is refused when it is chosen: one digit
  repeated (`0000`), a run up or down (`1234`, `987654`), or two digits
  taking turns (`1212`). It is not the password and is never sent.
  Losing it means what the server holds cannot be read on a new device, only
  re-uploaded from a device that still has it. The screen says so
  plainly, twice. It is changed only by starting over (below): the
  server keeps a file under its hash and cannot re-seal it in place, so
  a new PIN means the files, like the rows, are sent again.
  - **Choose or enter: the server says which.** While no PIN is set,
    the device *chooses* one, typed twice, and stores two things before
    it seals anything: a *key check* (a short text sealed with the key,
    which the server cannot open) and a *verifier* (a hash of a proof
    drawn from the PIN, which is not the key). The first device to do so
    wins; one that chose at the same moment enters its PIN instead. Once
    a PIN is set, every other device *enters* it, once, and **the server
    checks it**: the device sends its proof, and only a proof that
    matches the verifier gets the key share back. A wrong PIN is refused
    on the spot — *"That isn't the PIN your other devices use"* — and
    nothing is kept or sealed with it. Five wrong PINs in a quarter of
    an hour, or twenty in a day, and the account waits before it may
    try again. What a device has or has not pulled yet plays no
    part, so a new phone or a fresh browser never offers to choose a
    second PIN.
  - **A row that won't open is locked, not fatal.** A key that passed
    the check is never forgotten because one sealed row does not open
    with it; that row is counted as locked (the account page says how
    many) and the rest of sync goes on.
  - **Asked for, not hidden.** Signing in on a device that has no PIN
    asks for it straight after, and until it is given the account circle
    carries a mark and says what is waiting: nothing syncs until the
    sync secret is set. Nothing is ever sent without it.
  - **Forgot the PIN? Start over.** With the account's password, the
    account page drops everything private the server holds: the money,
    the places and the pictures and recordings stored there, the key
    check and the server's key share. A new PIN is then chosen as on a
    first device, and the old one opens nothing any more. Each device
    that still has those rows and files sends them again, sealed under
    the new PIN. **Whatever no device still holds is gone for good** —
    the server has no way to read it, and neither does anyone else.
    Since everything is sealed, that is everything the server holds;
    only rows still in the clear from before Phase 7 stay. This is also
    how the PIN is changed, and how a PIN becomes a passphrase. On the phone it is *Forgot the PIN?
    Start over* on the sheet that asks for the PIN, and *Change PIN* on
    the PIN tile while I still have it; both say plainly what goes and
    ask for the password first, and then every private row and file
    on the phone goes up again under the new PIN.
  - **Changed on another device.** Every start over moves the account's
    *key epoch* on, and every sealed row and file a device sends says
    which epoch its key belongs to; the server refuses one sealed under
    an old key, so nothing is ever stored under a key the account no
    longer has. A device that finds it is behind — on a refusal, or by
    comparing the epoch before it sends anything private — forgets the
    key, says *"Your PIN was changed on another device"*, and asks for
    the new one; once it is entered, what that device holds goes up
    again under it.
  - **Set again once.** The key changed with the key check (below), so
    a device updated from 3.0.0 asks for the PIN once more, and rows
    sealed by 3.0.0 count as locked.
  - **What a PIN costs.** The key is PBKDF2-SHA256 over 600,000 rounds
    with the account's salt, then mixed (HKDF) with the account's *key
    share*: 32 random bytes the server keeps sealed under a key of its
    own, outside the database ([[Sync-API]]). Once a PIN is set, the
    share leaves the server only for a device that proves the PIN, with
    five tries a quarter of an hour and twenty a day. So **a stolen
    session** — a phone's token, a browser someone else sat at — can
    try a handful of PINs, not all million, and nothing the server hands
    it before a right PIN lets anyone try more at leisure. **A copy of
    the database or a backup** holds the share and the verifier only
    sealed, under a key it does not hold, so it opens nothing either.
    What remains is **whoever holds the whole server**, the database
    and its environment together: they could try every PIN, since a PIN
    has at most a million values. A passphrase holds against that too.
  - **Why a passphrase first.** From the outside an account with a PIN
    and one with a passphrase look the same, so someone who takes the
    server cannot pick out the weak ones without trying them all — a
    kind of herd protection. But trying all of them is cheap when they
    are PINs: every PIN of every account falls in minutes. Only a
    passphrase stands against that, which is why it is the default and
    the PIN is the exception I choose knowingly.
- **Download my data** (the archive, the spreadsheet) asks for the
  account's password first, checked by the server (`POST /v1/me/reauth`,
  counted with the wrong passwords of *Delete account*), so a session
  left open is not enough to take everything; signed out, the phone asks
  for its own lock (fingerprint or screen lock) instead. Nothing is
  written before it passes. The files themselves stay unencrypted on
  purpose: they are mine, to take elsewhere.
- **Delete account**: requires the password. It deletes every record,
  every token and the user at once, and then signs out everywhere. The
  data on my devices is untouched, because it was always theirs. Five
  wrong passwords in 15 minutes stop the account from trying again for
  a while, from any of its devices: a stolen session is not a free
  run at the password. A push or an upload already running finishes
  first, and none starts until everything is gone.

## On the phone

**The account circle**, top-left on every tab, is the account at a
glance: my initial when signed in, a plain person when not, with a
small mark for the sync state — green with a tick when everything has
gone up, amber with an arrow while something waits, grey with a slash
offline, red with a "!" on an error (a shape each, never the colour
alone), and a dot
when the sync PIN is still to set. A tap opens a sheet with the
account's email, *online* or *offline*, the last sync and what is
still waiting, *Sync now*, the PIN (set it, change it, or forget it
on this device), the signed-in
devices, and *Sign out* — or, signed out, *Sign in* and *Create
account*. The full account page stays in Settings.

**Signing in on a phone that already has data.** Things made on the
phone before signing in are not sent into the account on their own: the
first question after signing in is whether to *bring this phone's data
into the account*, or to *start from the account's data* — in which case
the phone's data is first saved as an archive in Downloads and then
replaced by the account's, so nothing is lost and nothing is doubled.
Nothing syncs until one is chosen. Creating a new account asks nothing:
it has no data of its own for the phone's to double. The first page of the onboarding
offers *I already have an account*, which signs in before any template
seed is planted. The account's server must be `https://`; plain
`http://` is refused, except to the phone itself or the emulator's host
(`localhost`, `127.0.0.1`, `10.0.2.2`), and the same holds for the
assist's own address. The account password, when a prompt asks for it
(deleting the account, starting the PIN over), is typed hidden, with no
suggestions, correction or capital letters.

Settings gains **Account** (before *My data*):
- **Signed out:** *Sign in* and *Create account*, with one paragraph on
  what an account does and does not do.
- **Signed in:** email, verification state, *Sync now*, last synced,
  the sync PIN, devices, sign out, delete account.

## On the web

`/login`, `/register`, `/forgot`, `/reset/:token` and
`/verify/:token` are the public account routes ([[Web]]). Everything
under `/app` needs a session, and, for anything to sync, the sync secret
entered once per browser. The same account circle sits at the top of
the app's rail, with the same sheet, and there *Forget it on this
browser* drops the key (what the browser already holds stays), and
*Change PIN* starts it over as on the phone. The browser asks the
server's key check too: it chooses the PIN only while the account has
none, refuses a wrong one on the spot, offers *Forgot the PIN? Start
over* when entering, and notices a PIN changed on another device. A
session the server says is gone (a refused refresh) takes this
browser's copy of the account with it, drafts included; a server that
cannot be reached does not. Signing out while offline is remembered:
this browser never picks that session up again on its own, and tells
the server as soon as it can, since only the server can end a session
whose cookie a page cannot touch. Every tab of the browser shares the
key: one that keeps or forgets it tells the others, and none ever wipes
a newer key another tab kept. Only one tab syncs at a time. The
browser does not stop me with a dialog after signing in: the circle's
dot says the PIN is missing, and the Granary and the pictures ask for
it where it is needed. The PIN is written with the digits 0–9 on
every device, in Arabic too, like every number in Harvest; a keyboard
that sends other digits is read as those.

## Rules

| # | Rule |
| :-- | :--- |
| AC1 | An account is never required for anything but sync and the server assist. No screen may nag for one. |
| AC2 | The server stores a hash of the password and nothing that can decrypt what syncs: the key share is half of an input, and the key check only says whether a key is the right one. |
| AC3 | A sign-in failure never says whether the email is registered. Sign-up is the one exception, by design (see Flows), and is rate-limited hardest. |
| AC4 | Refresh tokens rotate on every use; a reused one revokes its family. |
| AC5 | Resetting the password signs out every device. |
| AC6 | Deleting the account deletes all of it on the server, immediately, and none of it on my devices. |
| AC7 | The sync secret is a passphrase of 8 characters or more, recommended, or a PIN of 4–6 digits (not a trivially guessable one), the same rule on every client (`packages/contracts` `syncSecretProblem`, `syncSecretStrength`). A device without it sends nothing, and says so. |
| AC9 | The server keeps no address, no name and no IP address readable from its database or its logs: addresses and names are sealed under keys from its environment, the request logs keep none (Phase 7). |
| AC10 | My data is written out only after the password (or, signed out, the device's lock) is given again. |
| AC11 | An account is what the server counts as a user; the admin panel sees the account's address, its last active day, platform and version, and its streak only while shared ([[Admin]]). |
| AC8 | Whether a device chooses the PIN or enters it is decided by the account's key check on the server, and a PIN that does not open the check is never kept. |

Related: [[Sync-API]] · [[Sync-Strategy]] · [[ADR-011-Backend]] · [[Web]]
