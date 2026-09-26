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
  good for 24 hours and can be re-sent.
- **Sign in**: email and password. Five failures from one address in
  15 minutes rate-limit that address. The answer never says whether the
  email exists.
- **Stay signed in**: a short access token and a rotating refresh
  token. Using a refresh token twice (theft, or a bug) revokes the
  whole family, and every device of that family must sign in again.
- **Forgot password**: an email with a one-hour, single-use link.
  Resetting the password signs out every device.
- **Devices**: a list of signed-in sessions (the device name the client
  gave, first and last seen), each with *Sign out*. The current one is
  marked.
- **Sync passphrase**: set once, on the first device, to encrypt the
  private tier. It is not the password and is never sent. Losing it
  means the private tier cannot be read on a new device, only
  re-uploaded from a device that still has it. The screen says so
  plainly, twice.
- **Delete account**: requires the password. It deletes every record,
  every token and the user at once, and then signs out everywhere. The
  data on my devices is untouched, because it was always theirs.

## On the phone

Settings gains **Account** (before *My data*):
- **Signed out:** *Sign in* and *Create account*, with one paragraph on
  what an account does and does not do.
- **Signed in:** email, verification state, *Sync now*, last synced,
  the sync passphrase, devices, sign out, delete account.

## On the web

`/login`, `/register`, `/forgot`, `/reset/:token` and
`/verify/:token` are the public account routes ([[Web]]). Everything
under `/app` needs a session, and for the private tier, the
passphrase entered once per browser.

## Rules

| # | Rule |
| :-- | :--- |
| AC1 | An account is never required for anything but sync and the server assist. No screen may nag for one. |
| AC2 | The server stores a hash of the password and nothing that can decrypt the private tier. |
| AC3 | A sign-in failure never says whether the email is registered. |
| AC4 | Refresh tokens rotate on every use; a reused one revokes its family. |
| AC5 | Resetting the password signs out every device. |
| AC6 | Deleting the account deletes all of it on the server, immediately, and none of it on my devices. |

Related: [[Sync-API]] · [[Sync-Strategy]] · [[ADR-011-Backend]] · [[Web]]
