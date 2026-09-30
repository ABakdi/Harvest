# Admin and news

Written 2026-09-29 ([[Checkpoint-12]]). The one place I, who run the
server, see how Harvest is used, and the one way I speak to the people
using it. It lives only on the web, at `/admin`, and only for an
account the server's environment names as an admin. Every number on it
is one the server can already see or one a device chooses to send; none
comes from reading anyone's rows, which stay sealed
([[Phase-7-Privacy-and-Currencies]]).

## Who is counted

- **Users are accounts.** Someone who uses the app without an account
  is not a user of the server and is never counted, identified or
  tracked: the app is complete without one ([[Business-Rules]] #5).
- **Downloads count everyone.** The APK's download count, per release,
  from GitHub's own figure for the release assets, is how many people
  took the app, account or not. It is a count of downloads, not of
  installs or of people.

## What a device tells the server

**The heartbeat** — `POST /v1/me/heartbeat`, from a signed-in device,
at most once a day per device (when the app opens, and on the first
sync of a new day):

| Field | Why |
| :-- | :-- |
| `platform` | `android` or `web`: how Harvest is used |
| `appVersion` | Which releases are still out there, before one is retired |
| `streak` | The current and best streak, both whole days — **only while *Share my streak* is on** (Settings › Account, on by default, said beside it); otherwise `null` |

The server keeps, per account, only the latest of each: when it was
last active, on what platform and version, and the streak last sent
(or none). It keeps no history per account: the history is the day's
totals below. A heartbeat is not needed for sync to work, and a device
that fails to send one tries again the next day.

## What the admin sees

`/admin`, three tabs.

### Overview

- **Accounts**: total, verified, and new today, this week, this month.
- **Active accounts**: today, in the last 7 days, in the last 30 days —
  an account is active on a day it sent a heartbeat.
- **Streaks**: of the accounts sharing theirs, how many share, the
  median and mean current streak, the longest, and how many sit in
  each band (0, 1–2, 3–6, 7–13, 14–29, 30–99, 100+ days).
- **Platforms and versions**: accounts by the platform and app version
  of their last heartbeat.
- **Downloads**: all APK downloads, and per release.
- **Over time**: a chart per measure, 30, 90 or 365 days: accounts,
  new accounts, daily, weekly and monthly active accounts, median
  streak.

The history is one row a day (`daily_stats`), written by the server
every hour for the day under way and final once the day is over; it
holds counts only, never an account.

### Users

A table of accounts, newest first, searchable by email: email, name,
created, verified, last active, platform, version, streak (or *not
shared*). Opening one shows the same and nothing more — the server has
nothing more to show. This is what someone who asks for help can be
found by.

### News

Where I write to people. A piece of news has:

| Field | |
| :-- | :-- |
| Title | Up to 80 characters |
| Body | Up to 1,000 characters, plain text, line breaks kept |
| Link | Optional `https://` address, opened by a button under the body |
| Push | Sent as a notification |
| Pop-up | Shown once in a dialog the next time the app opens |
| Audience | Everyone, or only people with an account |
| From / until | When it starts to show (now, by default) and when it stops (never, by default) |

It can be ended early (it stops showing and stops being fetched) or
deleted. The list shows every piece of news, live or not, newest first.

## How news reaches a device

`GET /v1/announcements` answers the news live right now, for everyone;
with a signed-in session, the news for account holders too. It carries
no identity when called without a session, and the server logs nothing
of who asked.

- **The phone** asks when it opens, and in the background every few
  hours (the same scheduler as the 3 AM job): a push it has not shown
  yet becomes a notification, and a pop-up it has not shown yet opens
  in a dialog the next time the app is in front. What it has shown is
  remembered on the phone, not on the server. So a push reaches a
  phone within a few hours, or at once when the app is opened — there
  is no Google service in between. The background check asks without the
  session, since two processes refreshing one session could end it; so
  news for account holders only reaches a phone when the app is opened.
- **The web** asks when a page of the app opens: pop-ups as on the
  phone. For push, a signed-in browser that I allow to show
  notifications subscribes with the standard Web Push API (VAPID); the
  server sends each new push to those subscriptions at once, through
  the browser's own push service, encrypted to the browser. A
  subscription is dropped when the push service says it is gone, and
  when the browser signs out.
- **Everyone can turn it off**: *News from Harvest* in Settings stops
  the asking and the notifications on that device; the web's browser
  permission does the same for push.

## Reports

*Report a problem* — in Settings on the phone and on the web, for
everyone, account or not — is how someone tells me what went wrong, in
their own words ([[Checkpoint-12]] F12-5).

- **What goes**: the text (up to 5,000 characters), up to four pictures
  and one recording (a few minutes at most), and the platform and app
  version, so I know which build it is about. About 20 MB at most, all
  told.
- **Anonymous**: the report is not tied to an account — the server does
  not read the session even when there is one — and no address is kept;
  the only limit is a count per network in memory (five an hour). If
  they want an answer, they write how to reach them in the text.
- **Not encrypted end to end**, unlike what syncs: a report is written
  to me, to be read. The form says so beside the send button.
- **Pictures lose their metadata**: each is re-encoded on the device
  before it goes, so a photo's GPS position, camera and time never leave
  with it.
- **In the admin panel**, a *Reports* tab: newest first, each with its
  text, its pictures and its recording, the platform, the version and
  when it came; marked *new*, *read* or *done*; deleted by me, and with
  it every file. Nothing is deleted on its own.

## Who is an admin

An account whose email is in `ADMIN_EMAILS` (the server's environment,
comma-separated) is an admin: `GET /v1/me` says `admin: true`, and only
then does the web show *Admin* in the account menu. Every `/v1/admin`
route checks it again, answers 404 to anyone else (the routes are not
advertised), and is rate-limited per account. There is no admin on
the phone.

## Rules

| # | Rule |
| :-- | :-- |
| AD1 | Nothing on the admin panel is read from a user's rows; every number is metadata the server already has or a heartbeat field the device chose to send. |
| AD2 | An account without a heartbeat is still an account; a device without an account is never a user, only a download. |
| AD3 | The streak leaves a device only while *Share my streak* is on. |
| AD4 | No history is kept per account; history is daily totals. |
| AD5 | News is fetched without identity unless the device is signed in, and can be turned off on every device. |
| AD6 | Only accounts named in `ADMIN_EMAILS` reach `/v1/admin`; anyone else gets 404. |
| AD7 | A report carries no account and no address; its pictures leave the device re-encoded, without their metadata. |

Related: [[Accounts]] · [[Sync-API]] · [[Data-Map]] · [[Business-Rules]] #13 · [[Notifications]]
