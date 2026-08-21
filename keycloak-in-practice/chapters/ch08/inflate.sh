#!/usr/bin/env bash
# Chapter 8: make a token too big, on purpose.
#
# Creates N client roles on meridian-api and grants them all to one
# group, so that a single login produces a token carrying all of them.
# The point is not that 200 roles is realistic - it is that the growth
# is linear and nobody notices until a proxy refuses the request.
#
#   ./inflate.sh 200          create and grant
#   ./inflate.sh 200 --undo   take them away again
set -euo pipefail

cd "$(dirname "$0")/../.."
N="${1:-200}"
UNDO="${2:-}"
REALM=meridian
kc() { docker compose exec -T keycloak /opt/keycloak/bin/kcadm.sh "$@"; }

API=$(kc get clients -r "$REALM" -q clientId=meridian-api \
        --fields id --format csv --noquotes)
ORG=$(kc get groups -r "$REALM" -q search=meridian-freight \
        --fields id --format csv --noquotes)
LOG=$(kc get "groups/$ORG" -r "$REALM" \
        | jq -r '.subGroups[] | select(.name=="logistics") | .id')

if [ "$UNDO" = "--undo" ]; then
  echo "removing $N roles"
  for i in $(seq 1 "$N"); do
    kc delete "clients/$API/roles/perm-$i" -r "$REALM" 2>/dev/null || true
  done
  echo "done"
  exit 0
fi

echo "creating $N client roles (this takes a couple of minutes)"
for i in $(seq 1 "$N"); do
  kc create "clients/$API/roles" -r "$REALM" -s "name=perm-$i" \
    >/dev/null 2>&1 || true
done

echo "granting them to the logistics group"
args=()
for i in $(seq 1 "$N"); do args+=(--rolename "perm-$i"); done
kc add-roles -r "$REALM" --gid "$LOG" --cclientid meridian-api \
  "${args[@]}"

echo "done. Log in again - tokens are reissued, not updated."
