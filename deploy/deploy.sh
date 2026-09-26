#!/usr/bin/env bash
# Build and deploy Harvest on this server: MongoDB and the sync server
# in Docker on the loopback, the web app as static files behind nginx,
# and a Let's Encrypt certificate for the domain ([[Deployment]]).
#
# Run it from a checkout of the repository, as root (or with sudo):
#
#   sudo deploy/deploy.sh --domain harvest.example.org --email me@example.org
#
# The first run installs what is missing (Docker, nginx, certbot),
# writes deploy/.env with a fresh key pair, and stops to let me fill in
# the mail settings. Every later run is an update: pull, build, restart
# the server, switch the site to the new build, reload nginx. Running it
# again with nothing new is harmless.
#
# Debian or Ubuntu.
set -Eeuo pipefail

usage() {
  cat <<'USAGE'
Usage: sudo deploy/deploy.sh --domain DOMAIN --email EMAIL [options]

  --domain DOMAIN   the public name, e.g. harvest.example.org (required
                    the first time; remembered in deploy/.env after)
  --email EMAIL     for Let's Encrypt's expiry notices (required the
                    first time; remembered in deploy/.env after)
  --www             also answer on www.DOMAIN, redirecting to DOMAIN
  --staging         use Let's Encrypt's staging CA (for a trial run;
                    the certificate is not trusted by browsers)
  --no-pull         build what is checked out; do not git pull
  --no-tls          stop after the http set-up (no certificate, no
                    https site): for a server without DNS yet
  --api-port PORT   the loopback port for the server (default 8080)
  -h, --help        this text
USAGE
}

# ------------------------------------------------------------ arguments

DOMAIN=''
EMAIL=''
WITH_WWW=''
STAGING=0
PULL=1
TLS=1
API_PORT=''

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="${2:-}"; shift 2 ;;
    --email) EMAIL="${2:-}"; shift 2 ;;
    --www) WITH_WWW=1; shift ;;
    --staging) STAGING=1; shift ;;
    --no-pull) PULL=0; shift ;;
    --no-tls) TLS=0; shift ;;
    --api-port) API_PORT="${2:-}"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# --------------------------------------------------------------- output

say() { printf '\n\033[1;32m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
die() { printf '\n\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }
trap 'die "stopped at line $LINENO (exit $?). Nothing past that step was changed."' ERR

# --------------------------------------------------------------- places

# git refuses a checkout owned by someone else when run as root; this one
# is ours to read.
git_() { git -c safe.directory="$REPO" -C "$REPO" "$@"; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY="$REPO/deploy"
ENV_FILE="$DEPLOY/.env"
COMPOSE=(docker compose -f "$DEPLOY/compose.server.yaml" --env-file "$ENV_FILE")
WEB_BASE=/var/www/harvest
ACME_ROOT=/var/www/letsencrypt
SITE=/etc/nginx/sites-available/harvest
KEEP_RELEASES=3

# ------------------------------------------------------------- the host

[[ $EUID -eq 0 ]] || die "run it as root: sudo $0 $*"
[[ -f "$REPO/pnpm-workspace.yaml" && -f "$REPO/apps/server/Dockerfile" ]] ||
  die "run it from a checkout of the Harvest repository"
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-} ${ID_LIKE:-}" in
  *debian* | *ubuntu*) ;;
  *) die "this script knows Debian and Ubuntu; this is ${PRETTY_NAME:-an unknown system}" ;;
esac

apt_install() {
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" >/dev/null
}

say "Checking the tools"
if ! command -v curl >/dev/null || ! command -v openssl >/dev/null || ! command -v git >/dev/null; then
  apt-get update -qq
  apt_install ca-certificates curl openssl git
fi

if ! command -v docker >/dev/null || ! docker compose version >/dev/null 2>&1; then
  note "installing Docker from its own apt repository"
  apt-get update -qq
  apt_install ca-certificates curl gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/${ID}/gpg" -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
    >/etc/apt/sources.list.d/docker.list
  apt-get update -qq
  apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker >/dev/null
fi

if ! command -v nginx >/dev/null; then
  note "installing nginx"
  apt-get update -qq
  apt_install nginx
  systemctl enable --now nginx >/dev/null
fi

if [[ $TLS -eq 1 ]] && ! command -v certbot >/dev/null; then
  note "installing certbot"
  apt-get update -qq
  apt_install certbot
fi
note "docker $(docker --version | awk '{print $3}' | tr -d ,), $(nginx -v 2>&1 | awk -F/ '{print "nginx " $2}')"

# ---------------------------------------------------------- deploy/.env

# One key=value in deploy/.env: read, and write in place.
env_get() { grep -E "^$1=" "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- || true; }
env_set() {
  local key="$1" value="$2" tmp
  tmp="$(mktemp)"
  if grep -qE "^$key=" "$ENV_FILE"; then
    # Through the environment, not awk -v: -v would turn the keys' \n
    # into real line breaks.
    K="$key" V="$value" awk 'BEGIN { FS = "=" } $1 == ENVIRON["K"] { print ENVIRON["K"] "=" ENVIRON["V"]; next } { print }' \
      "$ENV_FILE" >"$tmp"
  else
    cat "$ENV_FILE" >"$tmp"
    printf '%s=%s\n' "$key" "$value" >>"$tmp"
  fi
  cat "$tmp" >"$ENV_FILE"
  rm -f "$tmp"
}

say "Settings (deploy/.env)"
if [[ ! -f "$ENV_FILE" ]]; then
  cp "$DEPLOY/.env.example" "$ENV_FILE"
  note "made deploy/.env from the example"
fi
chmod 600 "$ENV_FILE"

[[ -n "$DOMAIN" ]] || DOMAIN="$(env_get HARVEST_DOMAIN)"
[[ -n "$EMAIL" ]] || EMAIL="$(env_get HARVEST_ACME_EMAIL)"
[[ -n "$WITH_WWW" ]] || WITH_WWW="$(env_get HARVEST_WWW)"
[[ -n "$API_PORT" ]] || API_PORT="$(env_get HARVEST_API_PORT)"
API_PORT="${API_PORT:-8080}"
[[ -n "$DOMAIN" && "$DOMAIN" != harvest.example.org ]] || die "give the domain: --domain harvest.example.org"
[[ "$DOMAIN" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?)+$ ]] ||
  die "'$DOMAIN' is not a domain name"
[[ "$API_PORT" =~ ^[0-9]+$ ]] || die "--api-port takes a number"
if [[ $TLS -eq 1 ]]; then
  [[ -n "$EMAIL" ]] || die "give an email for Let's Encrypt: --email me@example.org"
fi
env_set HARVEST_DOMAIN "$DOMAIN"
[[ -z "$EMAIL" ]] || env_set HARVEST_ACME_EMAIL "$EMAIL"
env_set HARVEST_WWW "${WITH_WWW:-}"
env_set HARVEST_API_PORT "$API_PORT"

# A signing pair that lasts: without one, every restart signs everyone out.
if [[ -z "$(env_get JWT_PRIVATE_KEY)" || -z "$(env_get JWT_PUBLIC_KEY)" ]]; then
  key="$(mktemp)"
  openssl genpkey -algorithm ed25519 -out "$key" 2>/dev/null
  env_set JWT_PRIVATE_KEY "$(awk '{printf "%s\\n", $0}' "$key")"
  env_set JWT_PUBLIC_KEY "$(openssl pkey -in "$key" -pubout | awk '{printf "%s\\n", $0}')"
  shred -u "$key" 2>/dev/null || rm -f "$key"
  note "made a new Ed25519 signing pair"
fi

# MongoDB 5 and later stop with an illegal instruction on a CPU without
# AVX, which some virtual servers expose. 4.4 is the last that runs
# there; Harvest works on it. Chosen once: a database made by one version
# is not opened by an older one, and moving up is a step at a time.
if [[ -z "$(env_get HARVEST_MONGO_VERSION)" ]]; then
  if grep -qw avx /proc/cpuinfo; then
    env_set HARVEST_MONGO_VERSION 7
  else
    env_set HARVEST_MONGO_VERSION 4.4
    note "this CPU has no AVX: MongoDB 4.4 (7 needs AVX)"
  fi
fi

if [[ -z "$(env_get SMTP_HOST)" ]]; then
  die "deploy/.env has no SMTP_HOST. Without mail nobody can verify an account.
    Fill in SMTP_HOST, SMTP_USER, SMTP_PASS and SMTP_FROM in $ENV_FILE,
    then run this again."
fi
note "domain $DOMAIN${WITH_WWW:+ (and www.$DOMAIN)}, server on 127.0.0.1:$API_PORT"

# ----------------------------------------------------------- the source

if [[ $PULL -eq 1 ]]; then
  say "Pulling the latest source"
  if [[ -n "$(git_ status --porcelain --untracked-files=no)" ]]; then
    die "the checkout has local changes; commit or drop them, or run with --no-pull"
  fi
  # Pulled as the checkout's owner, so its files stay theirs.
  owner="$(stat -c %U "$REPO")"
  if [[ "$owner" == root ]]; then
    git_ pull --ff-only
  else
    runuser -u "$owner" -- git -C "$REPO" pull --ff-only
  fi
fi
RELEASE="$(git_ rev-parse --short HEAD)"
note "building $RELEASE ($(git_ log -1 --format=%s))"

# ------------------------------------------------------------ the build

# An image already built for this commit is used as it is: a rerun with
# nothing new builds nothing, and images built on another machine and
# loaded here (docker save | docker load) spare a small server the build.
if docker image inspect "harvest-server:$RELEASE" >/dev/null 2>&1; then
  say "The server image for $RELEASE is already here"
else
  say "Building the server image"
  docker build -q -f "$REPO/apps/server/Dockerfile" -t "harvest-server:$RELEASE" "$REPO" >/dev/null
fi
docker tag "harvest-server:$RELEASE" harvest-server:latest

if docker image inspect "harvest-web-build:$RELEASE" >/dev/null 2>&1; then
  say "The web build for $RELEASE is already here"
else
  say "Building the web app"
  docker build -q --target build -f "$REPO/apps/web/Dockerfile" -t "harvest-web-build:$RELEASE" "$REPO" >/dev/null
fi
release_dir="$WEB_BASE/releases/$RELEASE"
rm -rf "$release_dir.tmp"
mkdir -p "$release_dir.tmp"
container="$(docker create "harvest-web-build:$RELEASE")"
docker cp "$container:/harvest/apps/web/dist/." "$release_dir.tmp/"
docker rm "$container" >/dev/null
[[ -f "$release_dir.tmp/index.html" ]] || die "the web build has no index.html"
rm -rf "$release_dir"
mv "$release_dir.tmp" "$release_dir"
chmod -R a+rX "$WEB_BASE"

# ----------------------------------------------------------- the server

say "Starting the database and the server"
export HARVEST_RELEASE="$RELEASE"
"${COMPOSE[@]}" up -d --remove-orphans
note "waiting for http://127.0.0.1:$API_PORT/v1/health"
for _ in $(seq 1 60); do
  if curl -fsS "http://127.0.0.1:$API_PORT/v1/health" >/dev/null 2>&1; then
    healthy=1
    break
  fi
  sleep 2
done
if [[ -z "${healthy:-}" ]]; then
  "${COMPOSE[@]}" logs --tail 40 server >&2 || true
  die "the server did not answer on /v1/health; its last lines are above"
fi
note "the server answers"

# ------------------------------------------------------------ the site

# The new build goes live in one step: the link moves, nothing half-copied
# is ever served.
ln -sfn "$release_dir" "$WEB_BASE/current.new"
mv -Tf "$WEB_BASE/current.new" "$WEB_BASE/current"

server_names="$DOMAIN${WITH_WWW:+ www.$DOMAIN}"
mkdir -p "$ACME_ROOT"
install -m 0644 "$DEPLOY/nginx/harvest-headers.conf" /etc/nginx/snippets/harvest-headers.conf

# `http2 on` is nginx 1.25.1 and later; older ones say it on the listen line.
nginx_version="$(nginx -v 2>&1 | sed -E 's|.*nginx/([0-9.]+).*|\1|')"
if printf '%s\n1.25.1\n' "$nginx_version" | sort -V -C; then
  h2_listen=' http2'
  h2_directive=''
else
  h2_listen=''
  h2_directive='http2 on;'
fi

render() {
  sed -e "s|__DOMAIN__|$DOMAIN|g" \
    -e "s|__SERVER_NAMES__|$server_names|g" \
    -e "s|__ACME_ROOT__|$ACME_ROOT|g" \
    -e "s|__WEB_ROOT__|$WEB_BASE/current|g" \
    -e "s|__API_PORT__|$API_PORT|g" \
    -e "s|__H2_LISTEN__|$h2_listen|g" \
    -e "s|__H2_DIRECTIVE__|$h2_directive|g" \
    "$1"
}

write_site() {
  local rendered="$1" backup=''
  [[ -f "$SITE" ]] && backup="$(mktemp)" && cp "$SITE" "$backup"
  printf '%s\n' "$rendered" >"$SITE"
  ln -sfn "$SITE" /etc/nginx/sites-enabled/harvest
  if ! nginx -t 2>/tmp/harvest-nginx-test; then
    cat /tmp/harvest-nginx-test >&2
    if [[ -n "$backup" ]]; then cp "$backup" "$SITE"; else rm -f "$SITE" /etc/nginx/sites-enabled/harvest; fi
    die "nginx refused the new site; the previous one is back in place"
  fi
  rm -f "$backup" /tmp/harvest-nginx-test
  systemctl reload nginx
}

cert="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
www_block=''
if [[ -n "$WITH_WWW" ]]; then
  www_block="server {
    listen 443 ssl$h2_listen;
    listen [::]:443 ssl$h2_listen;
    $h2_directive
    server_name www.$DOMAIN;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    return 301 https://$DOMAIN\$request_uri;
}"
fi

if [[ $TLS -eq 1 && ! -f "$cert" ]] || [[ $TLS -eq 0 ]]; then
  say "nginx: http, for the certificate's challenge"
  # Only this domain's server block: other sites on the machine, and
  # nginx's default one, are left exactly as they were.
  write_site "$(render "$DEPLOY/nginx/harvest.http.conf")"
fi

if [[ $TLS -eq 0 ]]; then
  say "Stopped before https (--no-tls)"
  note "point $server_names at this server, then run it again without --no-tls"
  exit 0
fi

# Anything already listening needs the ports: say so before certbot does.
if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q '^Status: active'; then
  ufw allow 'Nginx Full' >/dev/null
  note "ufw: http and https allowed"
fi

# A certificate is needed when there is none, or when www was added after
# the first one was issued.
need_cert=0
if [[ ! -f "$cert" ]]; then
  need_cert=1
elif [[ -n "$WITH_WWW" ]] && ! openssl x509 -in "$cert" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS:www.$DOMAIN"; then
  need_cert=1
fi
if [[ $need_cert -eq 1 ]]; then
  say "Asking Let's Encrypt for a certificate"
  domains=(-d "$DOMAIN")
  [[ -z "$WITH_WWW" ]] || domains+=(-d "www.$DOMAIN")
  staging=()
  [[ $STAGING -eq 0 ]] || staging=(--staging)
  certbot certonly --webroot -w "$ACME_ROOT" "${domains[@]}" --expand \
    --email "$EMAIL" --agree-tos --no-eff-email --non-interactive "${staging[@]}" ||
    die "Let's Encrypt did not issue a certificate. Check that $server_names points at this
    server and that ports 80 and 443 are open, then run this again."
fi

# Renewals come from certbot's own timer; nginx must pick them up.
install -d /etc/letsencrypt/renewal-hooks/deploy
cat >/etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh <<'HOOK'
#!/bin/sh
systemctl reload nginx
HOOK
chmod 755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh

say "nginx: the site on https"
site="$(render "$DEPLOY/nginx/harvest.https.conf")"
site="${site//__WWW_REDIRECT__/$www_block}"
write_site "$site"

# ------------------------------------------------------------- tidy up

say "Keeping the last $KEEP_RELEASES builds"
current="$(readlink -f "$WEB_BASE/current")"
mapfile -t old < <(ls -1dt "$WEB_BASE"/releases/*/ 2>/dev/null | sed 's|/$||' | tail -n +$((KEEP_RELEASES + 1)))
for dir in "${old[@]}"; do
  [[ "$dir" == "$current" ]] || rm -rf "$dir"
done
docker image prune -f --filter "label!=keep" >/dev/null 2>&1 || true

# ---------------------------------------------------------------- check

say "Checking it from the outside in"
sleep 1 # the reload above takes a moment to reach the workers
if curl -fsS --max-time 10 --resolve "$DOMAIN:443:127.0.0.1" "https://$DOMAIN/v1/health" >/dev/null 2>&1; then
  note "https://$DOMAIN/v1/health answers"
elif [[ $STAGING -eq 1 ]]; then
  note "staging certificate: browsers will not trust it; run again without --staging for a real one"
else
  note "https://$DOMAIN did not answer from here; check the DNS and the firewall"
fi

say "Harvest $RELEASE is live at https://$DOMAIN"
note "update: sudo deploy/deploy.sh          (it remembers the domain)"
note "logs:   docker compose -f deploy/compose.server.yaml --env-file deploy/.env logs -f server"
note "backup: the MongoDB volume harvest_mongo-data — see docs/02-Architecture/Deployment.md"
