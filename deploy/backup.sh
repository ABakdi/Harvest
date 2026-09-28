#!/usr/bin/env bash
# A backup of Harvest's database, encrypted before it touches the disk
# ([[Deployment]], Phase 7 M7.7): mongodump inside the database's own
# container, straight into `age`, to a public key whose private half is
# not on this server. Nothing unencrypted is ever written.
#
#   sudo deploy/backup.sh                  # into /root/harvest-backups
#   sudo deploy/backup.sh --dir /srv/bak --keep 14
#   sudo deploy/backup.sh --purge-plain    # and delete unencrypted dumps
#
# The recipient is HARVEST_BACKUP_RECIPIENT in deploy/.env: an age public
# key (age1...), made on another machine with `age-keygen -o harvest.key`.
# Restoring, on a machine that has that key:
#
#   age -d -i harvest.key harvest-....archive.gz.age \
#     | docker compose -f deploy/compose.server.yaml --env-file deploy/.env exec -T mongo \
#       sh -c 'mongorestore --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --archive --gzip --drop'
#
# A backup is only half of it: the rows and files are sealed by the
# devices, but the accounts' key shares and addresses are sealed with
# KEY_SHARE_KEY, so keep deploy/.env too, elsewhere and under another key.
# Then copy the .age file off this server; it is safe anywhere.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$HERE/.env"
DIR=/root/harvest-backups
KEEP=7
PURGE_PLAIN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) DIR="${2:-}"; shift 2 ;;
    --keep) KEEP="${2:-}"; shift 2 ;;
    --purge-plain) PURGE_PLAIN=1; shift ;;
    -h | --help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

die() { echo "backup: $*" >&2; exit 1; }

[[ -f "$ENV_FILE" ]] || die "no $ENV_FILE: run deploy.sh first"
[[ "$KEEP" =~ ^[0-9]+$ && "$KEEP" -ge 1 ]] || die "--keep takes a number, at least 1"
command -v age >/dev/null || die "age is not installed (apt install age)"
# Read, not sourced: the file holds multi-line keys.
recipient="$(grep -E '^HARVEST_BACKUP_RECIPIENT=' "$ENV_FILE" | tail -n 1 | cut -d= -f2- | tr -d '"'"'"' ')"
[[ "$recipient" == age1* ]] ||
  die "HARVEST_BACKUP_RECIPIENT in deploy/.env is not an age public key (age1...); make one elsewhere with age-keygen"

umask 077
mkdir -p "$DIR"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
out="$DIR/harvest-$stamp.archive.gz.age"
partial="$out.partial"
trap 'rm -f "$partial"' EXIT

# The root password never leaves the container: its own environment has it.
docker compose -f "$HERE/compose.server.yaml" --env-file "$ENV_FILE" exec -T mongo sh -c \
  'mongodump --quiet --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin --db harvest --archive --gzip' |
  age -r "$recipient" >"$partial"
[[ -s "$partial" ]] || die "the dump came out empty"
mv "$partial" "$out"
echo "backup: $out ($(du -h "$out" | cut -f1))"

# The newest KEEP encrypted backups stay; older ones go.
mapfile -t old < <(ls -1t "$DIR"/harvest-*.archive.gz.age 2>/dev/null | tail -n +$((KEEP + 1)))
for file in "${old[@]}"; do rm -f "$file"; done

# Dumps made before this script, unencrypted: named, and deleted if asked.
mapfile -t plain < <(find "$DIR" -maxdepth 1 -type f \( -name '*.archive' -o -name '*.archive.gz' -o -name '*.bson' -o -name '*.gz' \) ! -name '*.age' 2>/dev/null)
if [[ ${#plain[@]} -gt 0 ]]; then
  if [[ $PURGE_PLAIN -eq 1 ]]; then
    for file in "${plain[@]}"; do shred -u "$file" 2>/dev/null || rm -f "$file"; done
    echo "backup: deleted ${#plain[@]} unencrypted dump(s)"
  else
    echo "backup: ${#plain[@]} unencrypted dump(s) in $DIR; run with --purge-plain to delete them" >&2
  fi
fi
