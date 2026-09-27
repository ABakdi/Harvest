#!/bin/bash
# Run once by the mongo image, when the volume is new
# (/docker-entrypoint-initdb.d): the user the server connects as, which
# may read and write the harvest database and nothing else. The root
# user from MONGO_INITDB_ROOT_* is only for me, and for deploy.sh.
set -euo pipefail
: "${MONGO_APP_PASSWORD:?MONGO_APP_PASSWORD is required}"
# `mongo` (the shell, pointed at the init instance) and `_js_escape` come
# from the image's entrypoint, which sources this file.
# shellcheck disable=SC2154
"${mongo[@]}" admin <<EOJS
db.getSiblingDB('harvest').createUser({
  user: 'harvest',
  pwd: $(_js_escape "$MONGO_APP_PASSWORD"),
  roles: [{ role: 'readWrite', db: 'harvest' }],
});
EOJS
