#!/bin/bash
# Keycloak's entrypoint from Chapter 20 on.
#
# Keycloak reads its database credential once, at start. From this
# chapter, that credential is not in .env any more: Vault Agent writes it
# to /run/vault/db.env after logging in to Vault as a machine. No file,
# no start - and the restart policy in chapters/ch20/compose.yaml turns
# that into the crash-loop the chapter is about.
set -euo pipefail

F=/run/vault/db.env
for _ in {1..30}; do
  [ -s "$F" ] && break
  sleep 1
done
if [ ! -s "$F" ]; then
  echo "kc-start: no database credential after 30 s" >&2
  echo "kc-start: $F missing - is Vault up and unsealed?" >&2
  exit 1
fi

set -a
# shellcheck source=/dev/null
. "$F"
set +a
echo "kc-start: database user $KC_DB_USERNAME, from Vault" >&2
exec /opt/keycloak/bin/kc.sh "$@"
