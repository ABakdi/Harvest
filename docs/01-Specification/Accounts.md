# Accounts

Phase 6 ([[Phase-6-Sync-Accounts-and-Web]]). An account is how my
phone, my laptop and any later device agree they are all me. It is
**optional forever**: [[Business-Rules]] #5 says the app is complete
without one, and nothing in the app may ask for one except sync and
the server assist.

## What an account holds

| Field | Why |
| :--- | :--- |
| Email | To sign in, and for the two emails the server ever sends: verify, and reset |
| Password hash | argon2id ([[ADR-011-Backend]]); the password itself never touches the disk |
| Display name | Shown in the app's header on the web; nothing else |
| Verified at | Unverified accounts can sign in but not sync, so a mistyped email cannot quietly own my data |
| Sync salt | The public half of the key derivation for the private tier ([[Sync-Strategy]]) |
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
  15 minutes rate-limit that address, and twenty failures for one email
  in an hour, from anywhere, rate-limit that email for the rest of the
  hour (counted in the database, so a restart does not reset them, and
  counted the same for an address with no account). The answer never
  says whether the email exists.
- **Stay signed in**: a short access token and a rotating refresh
  token. Using a refresh token twice (theft, or a bug) revokes the
  whole family, and every device of that family must sign in again —
  with one exception: the same token again within 30 seconds, while
  the token it was exchanged for is still unused, gets that same token
  back. That is a phone retrying after its answer was lost, not a
  thief. A refresh that fails for any reason but the session (the
  database away for a moment) leaves the web's cookie where it was.
- **Forgot password**: an email with a one-hour, single-use link.
  Resetting the password signs out every device.
- **Devices**: a list of signed-in sessions (the device name the client
  gave, first and last seen), each with *Sign out*. The current one is
  marked.
- **Sync PIN**: set once, on the first device, to encrypt the private
  tier — money, places, and the pictures and recordings. A **PIN of 4
  to 6 digits** (the screen suggests 6), or, for whoever wants more, a
  **passphrase of 8 characters or more** ("Use a passphrase instead").
  A PIN anyone would try first is refused when it is chosen: one digit
  repeated (`0000`), a run up or down (`1234`, `987654`), or two digits
  taking turns (`1212`). It is not the password and is never sent.
  Losing it means the private tier cannot be read on a new device, only
  re-uploaded from a device that still has it. The screen says so
  plainly, twice. It is changed only by starting over (below): the
  server keeps a file under its hash and cannot re-seal it in place, so
  a new PIN means the files, like the rows, are sent again.
  - **Choose or enter: the server says which.** The account keeps a
    *key check* on the server: a short text sealed with the key, which
    the server stores and cannot open. While there is none, the device
    *chooses* the PIN, typed twice, and stores its check before it seals
    anything; the first device to do so wins, and one that chose at the
    same moment is checked against the winner's. Once there is one,
    every other device *enters* the PIN, once, and it is accepted only
    if it opens the check. A wrong PIN is refused on the spot — *"That
    isn't the PIN your other devices use"* — and nothing is kept or
    sealed with it. What a device has or has not pulled yet plays no
    part, so a new phone or a fresh browser never offers to choose a
    second PIN.
  - **A row that won't open is locked, not fatal.** A key that passed
    the check is never forgotten because one sealed row does not open
    with it; that row is counted as locked (the account page says how
    many) and the rest of sync goes on.
  - **Asked for, not hidden.** Signing in on a device that has no PIN
    asks for it straight after, and until it is given the account circle
    carries a mark and says what is waiting: *"Money, places and
    pictures stay on this phone until you set your sync PIN."* Nothing
    private is ever sent without it.
  - **Forgot the PIN? Start over.** With the account's password, the
    account page drops everything private the server holds: the money,
    the places and the pictures and recordings stored there, the key
    check and the server's key share. A new PIN is then chosen as on a
    first device, and the old one opens nothing any more. Each device
    that still has those rows and files sends them again, sealed under
    the new PIN. **Whatever no device still holds is gone for good** —
    the server has no way to read it, and neither does anyone else. The
    plain tier (habits, notes, gym, and the rest) is not touched. This
    is also how the PIN is changed. On the phone it is *Forgot the PIN?
    Start over* on the sheet that asks for the PIN, and *Change PIN* on
    the PIN tile while I still have it; both say plainly what goes and
    ask for the password first, and then every private row and file
    on the phone goes up again under the new PIN.
  - **Changed on another device.** A device whose key no longer opens
    the account's check — held against it now and then, before
    anything private is sent, and when rows stop opening — forgets the
    key, says *"Your PIN was changed on another device"*, and asks for
    the new one; once it is entered, what that device holds goes up
    again under it.
  - **Set again once.** The key changed with the key check (below), so
    a device updated from 3.0.0 asks for the PIN once more, and rows
    sealed by 3.0.0 count as locked.
  - **What a PIN costs.** The key is PBKDF2-SHA256 over 600,000 rounds
    with the account's salt, then mixed (HKDF) with the account's *key
    share*: 32 random bytes the server keeps sealed under a key of its
    own, outside the database, and hands only to a signed-in, verified
    session ([[Sync-API]]). A copy of the database or a backup alone is
    therefore not enough to try PINs; someone who has the server's
    environment too still could, since a PIN has at most a million
    values. It keeps the private tier unreadable to a leaked backup,
    not to whoever holds the whole server; a passphrase holds against
    that too. On a server I run myself, that is the trade I choose —
    and the screen offers the passphrase to anyone who doesn't.
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
small mark for the sync state — green when everything has gone up,
amber while something waits, grey offline, red on an error, and a dot
when the sync PIN is still to set. A tap opens a sheet with the
account's email, *online* or *offline*, the last sync and what is
still waiting, *Sync now*, the PIN (set it, change it, or forget it
on this device), the signed-in
devices, and *Sign out* — or, signed out, *Sign in* and *Create
account*. The full account page stays in Settings.

Settings gains **Account** (before *My data*):
- **Signed out:** *Sign in* and *Create account*, with one paragraph on
  what an account does and does not do.
- **Signed in:** email, verification state, *Sync now*, last synced,
  the sync PIN, devices, sign out, delete account.

## On the web

`/login`, `/register`, `/forgot`, `/reset/:token` and
`/verify/:token` are the public account routes ([[Web]]). Everything
under `/app` needs a session, and for the private tier, the sync PIN
entered once per browser. The same account circle sits at the top of
the app's rail, with the same sheet, and there *Forget it on this
browser* drops the key (what the browser already holds stays), and
*Change PIN* starts it over as on the phone. The browser asks the
server's key check too: it chooses the PIN only while the account has
none, refuses a wrong one on the spot, offers *Forgot the PIN? Start
over* when entering, and notices a PIN changed on another device. A
session the server says is gone (a refused refresh) takes this
browser's copy of the account with it; a server that cannot be reached
does not. The
browser does not stop me with a dialog after signing in: the circle's
dot says the PIN is missing, and the Granary and the pictures ask for
it where it is needed. The PIN is written with the digits 0–9 on
every device, in Arabic too, like every number in Harvest; a keyboard
that sends other digits is read as those.

## Rules

| # | Rule |
| :-- | :--- |
| AC1 | An account is never required for anything but sync and the server assist. No screen may nag for one. |
| AC2 | The server stores a hash of the password and nothing that can decrypt the private tier: the key share is half of an input, and the key check only says whether a key is the right one. |
| AC3 | A sign-in failure never says whether the email is registered. Sign-up is the one exception, by design (see Flows), and is rate-limited hardest. |
| AC4 | Refresh tokens rotate on every use; a reused one revokes its family. |
| AC5 | Resetting the password signs out every device. |
| AC6 | Deleting the account deletes all of it on the server, immediately, and none of it on my devices. |
| AC7 | The sync secret is a PIN of 4–6 digits (not a trivially guessable one) or a passphrase of 8 characters or more, the same rule on every client (`packages/contracts` `syncSecretProblem`). A device without it sends nothing private, and says so. |
| AC8 | Whether a device chooses the PIN or enters it is decided by the account's key check on the server, and a PIN that does not open the check is never kept. |

Related: [[Sync-API]] · [[Sync-Strategy]] · [[ADR-011-Backend]] · [[Web]]
