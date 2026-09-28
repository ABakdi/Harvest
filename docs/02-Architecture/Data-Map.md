# Data map

Where every piece of what I keep lives, and who can read it, as of
Phase 7 ([[Phase-7-Privacy-and-Currencies]]). The privacy statement on
the site says the same in fewer words; when the two disagree, this page
is checked against the code and the statement is fixed.

**Who** is one of: *me* (on my own device, unlocked), *the device*
(its storage, if someone else holds it), *the server's operator*
(whoever runs the server, with its database, its logs and its
environment), and *a copy* (a database dump or a backup that leaked,
without the environment).

## On the phone

| What | Where | Protected by |
| :--- | :--- | :--- |
| Every row: seeds, check-ins, notes, money, places, the trail, gym, body, sleep, lists, goals, settings | The app's database, in its private folder | SQLCipher, keyed from the Android Keystore; unreadable off the phone |
| Pictures, videos, recordings | The app's private folder | Sealed one by one with AES-GCM under a Keystore-kept key (M7.4); opened in memory, or into a temporary file removed after playback |
| The sync key | Secure storage | The Keystore |
| The account's tokens | Secure storage | The Keystore |
| An export (archive, spreadsheet) | Wherever I save it | Nothing, on purpose: it is mine to take elsewhere. Written only after my password, or signed out, the phone's own lock (M7.6) |

Backups by Android are off (`allowBackup="false"`), and the screen is
kept out of screenshots and the recent-apps preview.

## In the browser

| What | Where | Protected by |
| :--- | :--- | :--- |
| Every row I have opened | IndexedDB, this browser's profile | The profile and the machine's own disk encryption. Signing out wipes it all |
| Pictures and recordings fetched | IndexedDB | The same |
| The sync key | IndexedDB, as a non-extractable key | It cannot be read back by any page, mine included; a copy of the profile carries it, though |
| The access token | Memory only | Gone with the tab |
| The refresh token | An `HttpOnly`, `Secure`, `SameSite=Strict` cookie | No page can read it |

The browser's store is not sealed again under a key of the app's own.
Any key the page could keep would sit in the same profile, so it would
protect nothing against a copy of that profile; I would rather say so
than pretend (M7.4). On a shared computer: sign out, which wipes it.

## In transit

Everything goes over HTTPS (HSTS, TLS from Let's Encrypt), and every
row and file is sealed on the device before it goes: HTTPS protects the
envelope, the sync key protects what is inside it.

## On the server

| What | What the operator sees | What a copy sees |
| :--- | :--- | :--- |
| Rows (`records`) | The table, the key, the clocks, which device id wrote it, the padded length, and for a row with a file, the file's keyed name. Never a column | The same |
| Rows stored before Phase 7 | Until a device seals them, what they say; `POST /v1/sync/sealed` deletes them | The same |
| Files (`files`, `file_blobs`) | A keyed name, a padded size, the upload and last-asked times | The same |
| Email address | Nothing without the environment; with it, the address (it has to send the mail) | A keyed hash and a sealed copy: nothing |
| Display name | As the address | Nothing |
| Password | An argon2id hash | The same |
| Sync secret | A sealed verifier, and the key share sealed, both under `KEY_SHARE_KEY` | Nothing it can use |
| Sessions | Device name, client kind, first and last seen | The same |
| Sign-in failures | A keyed hash of the email (and of the email with the network), gone within the hour | Nothing it can reverse |
| Assist use | A count a day per account, gone after 60 days | The same |
| Request log | Method, path, status, time. No address, no body, no query | — |
| nginx's log | Time, method, path, status, size, duration. No address, query or referrer | — |
| Backups | — | Encrypted with `age` to a key not on the server |

What the operator still learns: that an account exists, when its
devices sync and when rows change, roughly how much each holds, and how
many pictures it keeps. Not what any of them says, not where I was,
not what I weigh.

## Leaving the device for someone else

| To | What | When |
| :--- | :--- | :--- |
| `open.er-api.com` | A request for today's rates, with nothing of mine | When I tap *Fetch* |
| OpenFreeMap, Esri | The map tiles of the area on screen | While I look at a map |
| The exercise animations' host | A request for one animation | When I open it |
| The assist's provider | Exactly what its sheet shows | When I tap an assist action |
| The mail provider | My address and a link | Verification and password reset |

Related: [[Sync-API]] · [[Accounts]] · [[Deployment]] · [[Business-Rules]] #13
