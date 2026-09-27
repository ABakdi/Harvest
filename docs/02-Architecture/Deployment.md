# Deployment

What it takes to run Harvest for myself: a server, a database, and a
folder of static files. Phase 6
([[Phase-6-Sync-Accounts-and-Web]] M6.9).

Nothing here is required to *use* Harvest. The phone works alone, as
it always has ([[Business-Rules]] #5); this is only for the account
that ties a phone to a browser.

## On a server of my own, with nginx

`deploy/deploy.sh` does the whole thing on a Debian or Ubuntu server,
from a checkout of the repository:

```sh
git clone https://github.com/ABakdi/Harvest.git && cd Harvest
sudo deploy/deploy.sh --domain harvest.example.org --email me@example.org
```

The first run installs what is missing (Docker from Docker's own
repository, nginx, certbot), writes `deploy/.env` with a fresh Ed25519
pair, two MongoDB passwords and a `KEY_SHARE_KEY` (below), and stops
to ask for the mail settings — nobody can verify an account without
them. It never replaces a key or a password already there. The second
run:

1. builds the server image and the web bundle, both inside Docker, so
   the server needs no Node of its own;
2. starts MongoDB with access control, makes sure its two users match
   `deploy/.env`, then starts the server (`deploy/compose.server.yaml`),
   on the loopback only, and waits for `/v1/health`;
3. puts the bundle in `/var/www/harvest/releases/<commit>` and moves
   the `current` link to it in one step, keeping the last three;
4. serves a holding page on port 80 while Let's Encrypt checks the
   domain (`certbot --webroot`), then writes the https site from
   `deploy/nginx/harvest.https.conf`: http to https, `/v1` to the
   server with 6 MB bodies, 32 MB only on `/v1/files/` (25 MB files) and
   `/v1/assist` (recordings, and the streamed answers), long-cached
   assets, the shell always asked again, source maps kept back, no
   nginx version on any page, the emailed `/verify/…` and `/reset/…`
   links kept out of the access log (their token is in the path), and
   the same Content-Security-Policy as the Caddy file on the site — the
   API's own headers come from the server;
5. leaves renewals to certbot's own timer, with a hook that reloads
   nginx.

Every later run is an update — `sudo deploy/deploy.sh`, with no flags:
it remembers the domain, the email and `--www`. `--staging` tries it
against Let's Encrypt's staging CA, `--no-tls` stops before the
certificate for a server whose DNS is not pointed yet, and `--no-pull`
builds what is checked out. If nginx refuses a new site, the previous
one is put back.

### The key-share key: back it up

`KEY_SHARE_KEY` seals every account's key share, the half of the
private tier's key the server keeps ([[Sync-API]], the sync key). It is
in `deploy/.env` and the server's environment, never in the database,
which is the point: a copy of the database alone cannot be used to try
anyone's PIN. It also means that **losing it makes every private tier
on the server unreadable, for good** — expenses, debts and places
stay on the devices, but no new device can open what the server holds.
So:

- back up `deploy/.env` **together with** the database volume, every
  time: one without the other is not a backup;
- encrypt both backups. A backup of the volume and `.env` together is
  as good as the server, and a backup file is the likeliest thing to
  leak;
- never generate a new one for a server that already has accounts.
  The server refuses to hand out a share its key does not open rather
  than make a new one.

### An existing database gets access control

Every deploy before this one ran MongoDB without access control (only
the compose network could reach it, but anything on that network could
read everything). Now MongoDB runs with it, and the server connects as
`harvest`, a user that may read and write the `harvest` database and
nothing else; `root` is for me and for `deploy.sh`. On a volume from
before, `deploy.sh` makes both users on the database **as it runs now**,
without access control (or on a temporary copy of the container, on no
network, if it is stopped), and only then starts it again with access
control. It writes `HARVEST_MONGO_AUTH=1` to `deploy/.env` once that is
done, and every run after only checks the two passwords still match.
MongoDB and the server share a network marked internal: MongoDB has no
way out, and nothing but the server can reach it.

**MongoDB 4.4 is a stopgap.** `deploy.sh` picks it on a CPU without
AVX, because 5 and later do not run there, but 4.4 has had no security
fixes since February 2024. Access control and the internal network
limit what that costs; the fix is a host whose CPU has AVX (most do),
then moving up a version at a time (4.4 → 5 → 6 → 7).

## All of it in Docker, with Caddy

`deploy/` holds the whole of it as one Compose file: MongoDB, the
server, and Caddy serving the site with `/v1` handed to the server on
the same origin. Caddy fetches its own certificate for the name in
`HARVEST_DOMAIN`.

```sh
cp deploy/.env.example deploy/.env      # the domain, the key pair, SMTP
openssl rand -base64 32                 # → KEY_SHARE_KEY
openssl rand -hex 24                    # → MONGO_ROOT_PASSWORD, and again → MONGO_APP_PASSWORD
docker compose -f deploy/compose.yaml --env-file deploy/.env up -d --build
```

Compose refuses to start without the domain, the key pair,
`KEY_SHARE_KEY`, the two MongoDB passwords and `SMTP_HOST`, for the
same reasons the server does (below). On a new volume the mongo image
makes the root user and `deploy/mongo-init/harvest-user.sh` the
server's. A volume from before access control needs the two users made
first, as `deploy.sh` does: start the old container as it was, run
`db.getSiblingDB('admin').createUser({user: 'root', pwd: …, roles:
['root']})` and `db.getSiblingDB('harvest').createUser({user:
'harvest', pwd: …, roles: [{role: 'readWrite', db: 'harvest'}]})` in
`mongosh` inside it, then `up -d` with the new file. The database lives
in the `mongo-data` volume; that volume **and** `deploy/.env` are what
get backed up, together and encrypted.

The rest of this note is the same thing taken apart, for a host that
already has a database or a proxy of its own.

## The server

`apps/server/Dockerfile` builds it in two stages. The first installs
the workspace and compiles the server with the packages it imports;
the second carries what `pnpm deploy --prod` wrote and nothing else —
no sources, no toolchain, no store.

```sh
docker build -f apps/server/Dockerfile -t harvest-server .
docker run -d --name harvest-server -p 8080:8080 \
  -e MONGO_URL=mongodb://mongo:27017/harvest \
  -e JWT_PRIVATE_KEY="$(cat jwt.key)" \
  -e JWT_PUBLIC_KEY="$(cat jwt.pub)" \
  -e CORS_ORIGINS=https://harvest.example.org \
  -e APP_URL=https://harvest.example.org \
  -e SMTP_HOST=smtp.example.org -e SMTP_USER=… -e SMTP_PASS=… \
  harvest-server
```

`apps/server/.env.example` lists every variable. Four of them are not
optional in production, and the server refuses to start without them
rather than failing later on the first request that needs one:

| Variable | Why it is required |
| :--- | :--- |
| `MONGO_URL` | There is nowhere to put anything otherwise. |
| `JWT_PRIVATE_KEY`, `JWT_PUBLIC_KEY` | Without them a pair is generated at every start, which signs everyone out on every restart. Ed25519, PEM: `openssl genpkey -algorithm ed25519 -out jwt.key` then `openssl pkey -in jwt.key -pubout -out jwt.pub`. |
| `KEY_SHARE_KEY` | Seals the accounts' key shares (above). 32 bytes, base64: `openssl rand -base64 32`. Outside production a fixed key is used. |
| `SMTP_HOST` | Verification and password-reset links go to the log otherwise, which means nobody can verify an account. |

Mail goes over TLS or not at all: on port 587 the server insists on
STARTTLS (TLS 1.2 or later) and refuses to send if the relay does not
offer it, because a reset link read on the way is an account taken.
Port 465 is TLS from the start (`SMTP_SECURE=true`). Only a relay on the
same machine without TLS needs `SMTP_ALLOW_PLAINTEXT=true`.

Behind a reverse proxy, set `TRUST_PROXY` to the number of hops so the
rate limits see the client's real address, and leave `COOKIE_SECURE`
alone — it defaults to on everywhere but development, and the refresh
cookie is the session.

`GET /v1/health` is what a load balancer should watch; the image's own
`HEALTHCHECK` watches the same route.

## The database

Any MongoDB 7 or later, with access control on and a user for the
server that may only read and write its own database. The indexes are
created at boot, every time, because `createIndex` on an index that
exists does nothing.

```sh
docker run -d --name harvest-mongo -v harvest-data:/data/db \
  -e MONGO_INITDB_ROOT_USERNAME=root -e MONGO_INITDB_ROOT_PASSWORD=… mongo:7
# then, as root: db.getSiblingDB('harvest').createUser({ user: 'harvest', pwd: …,
#   roles: [{ role: 'readWrite', db: 'harvest' }] })
# MONGO_URL=mongodb://harvest:…@harvest-mongo:27017/harvest?authSource=harvest
```

**Back it up**, with `KEY_SHARE_KEY` beside it and both encrypted. The
phone is the first copy and this is the second, but an account holding
the only copy of a year of pictures is an account worth
`mongodump`-ing on a schedule.

## The web

A static bundle: build it and serve the folder.

```sh
pnpm --filter @harvest/web build   # → apps/web/dist
```

Two things the host must do:

1. **Serve `index.html` for any path it does not have a file for.**
   The app routes in the browser, so `/app/field` is not a file.
2. **Send `/v1/*` to the server**, on the same origin. The refresh
   cookie is `SameSite=Strict` on `/v1/auth`, which is what makes a
   stolen token useless from another site — and what makes a separate
   API domain more trouble than it is worth. Same origin is the setup I
   run and test. `CORS_ORIGINS` does let another origin call the API,
   uploads included (`PUT`, `x-harvest-iv`, `x-harvest-plain-bytes`),
   but a browser on another *site* never sends the refresh cookie, so
   its session ends with its first access token.

`apps/web/Dockerfile` builds the bundle and serves it from Caddy with
`deploy/Caddyfile`, which does both, and also:
- sends a **Content-Security-Policy** naming the only hosts the site
  may reach: OpenFreeMap and Esri for the map, `api.frankfurter.dev`
  for the rates I ask for ([[Business-Rules]] #13) — anything else is
  refused by the browser before it leaves;
- lets hashed assets be cached for a year, and makes the browser ask
  again for `index.html` and the service worker, so a deploy reaches
  an open tab;
- keeps the source maps on the build machine.

A proxy of my own must let a request of up to about 26 MB through to
`/v1`: a picture or a recording travels up to 25 MB, a recording to
transcribe about 15 MB once encoded. Caddy sets no limit; nginx's
default of 1 MB would refuse most of them (`client_max_body_size 32m`,
as `deploy.sh` sets).

The bare minimum, with Caddy, is six lines:

```
harvest.example.org {
  handle /v1/* {
    reverse_proxy harvest-server:8080
  }
  handle {
    root * /srv/harvest
    try_files {path} /index.html
    file_server
  }
}
```

The service worker caches the shell and never the API
([[Web]] W4), so a deploy reaches an open tab as an offer to reload
rather than a page that changes under a half-written note.

## The phone

Release builds are signed with the upload key and fail without it
([[Audit-v2]] S3-08); the README has the keystore steps. The APK goes
to a GitHub release, which is where `/download` reads it from
([[Web]]).

Related: [[ADR-011-Backend]] · [[Sync-API]] · [[Accounts]] · [[Web]]
