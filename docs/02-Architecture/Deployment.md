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
pair, and stops to ask for the mail settings — nobody can verify an
account without them. The second run:

1. builds the server image and the web bundle, both inside Docker, so
   the server needs no Node of its own;
2. starts MongoDB and the server (`deploy/compose.server.yaml`), the
   server on the loopback only, and waits for `/v1/health`;
3. puts the bundle in `/var/www/harvest/releases/<commit>` and moves
   the `current` link to it in one step, keeping the last three;
4. serves a holding page on port 80 while Let's Encrypt checks the
   domain (`certbot --webroot`), then writes the https site from
   `deploy/nginx/harvest.https.conf`: http to https, `/v1` to the
   server with room for 25 MB files and the assist's streamed answers,
   long-cached assets, the shell always asked again, source maps kept
   back, and the same Content-Security-Policy as the Caddy file;
5. leaves renewals to certbot's own timer, with a hook that reloads
   nginx.

Every later run is an update — `sudo deploy/deploy.sh`, with no flags:
it remembers the domain, the email and `--www`. `--staging` tries it
against Let's Encrypt's staging CA, `--no-tls` stops before the
certificate for a server whose DNS is not pointed yet, and `--no-pull`
builds what is checked out. If nginx refuses a new site, the previous
one is put back.

## All of it in Docker, with Caddy

`deploy/` holds the whole of it as one Compose file: MongoDB, the
server, and Caddy serving the site with `/v1` handed to the server on
the same origin. Caddy fetches its own certificate for the name in
`HARVEST_DOMAIN`.

```sh
cp deploy/.env.example deploy/.env      # the domain, the key pair, SMTP
docker compose -f deploy/compose.yaml --env-file deploy/.env up -d --build
```

Compose refuses to start without the domain, the key pair and
`SMTP_HOST`, for the same reasons the server does (below). The
database lives in the `mongo-data` volume, and that volume is what
gets backed up.

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
| `SMTP_HOST` | Verification and password-reset links go to the log otherwise, which means nobody can verify an account. |

Behind a reverse proxy, set `TRUST_PROXY` to the number of hops so the
rate limits see the client's real address, and leave `COOKIE_SECURE`
alone — it defaults to on everywhere but development, and the refresh
cookie is the session.

`GET /v1/health` is what a load balancer should watch; the image's own
`HEALTHCHECK` watches the same route.

## The database

Any MongoDB 7 or later. The indexes are created at boot, every time,
because `createIndex` on an index that exists does nothing.

```sh
docker run -d --name harvest-mongo -p 27017:27017 -v harvest-data:/data/db mongo:7
```

**Back it up.** The phone is the first copy and this is the second,
but an account holding the only copy of a year of pictures is an
account worth `mongodump`-ing on a schedule.

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
   API domain more trouble than it is worth.

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
