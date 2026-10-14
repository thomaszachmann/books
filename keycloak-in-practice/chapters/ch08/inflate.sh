#!/usr/bin/env bash
# Chapter 8: make a token too big, on purpose.
#
# Creates a client `inflate-demo` with N client roles and grants them
# all to the logistics group, so that a single login produces a token
# carrying all of them. The point is not that 200 roles is realistic -
# it is that the growth is linear and nobody notices until a proxy
# refuses the request.
#
# Three kcadm calls, not N: the roles arrive in one partial import and
# are granted in one add-roles. Each kcadm call starts a JVM, and N of
# them took a quarter of an hour.
#
#   ./inflate.sh 200          create and grant
#   ./inflate.sh 200 --undo   take them away again (deletes the client,
#                             and its roles with it)
set -euo pipefail

cd "$(dirname "$0")/../.."
N="${1:-200}"
UNDO="${2:-}"
REALM=meridian
CLIENT=inflate-demo
kc() { docker compose exec -T keycloak /opt/keycloak/bin/kcadm.sh "$@"; }

case "$N" in ''|*[!0-9]*) echo "usage: $0 <number> [--undo]" >&2; exit 2 ;; esac

if [ "$UNDO" = "--undo" ]; then
  ID=$(kc get clients -r "$REALM" -q clientId="$CLIENT" \
         --fields id --format csv --noquotes)
  if [ -z "$ID" ]; then echo "nothing to undo: no client $CLIENT"; exit 0; fi
  echo "deleting client $CLIENT and its roles"
  kc delete "clients/$ID" -r "$REALM"
  echo "done. Log in again - tokens are reissued, not updated."
  exit 0
fi

# Subgroups are listed under /children; the parent's subGroups field is
# empty since Keycloak 23.
ORG=$(kc get groups -r "$REALM" -q search=meridian-freight \
        --fields id --format csv --noquotes)
LOG=$(kc get "groups/$ORG/children" -r "$REALM" \
        | jq -r '.[] | select(.name=="logistics") | .id')
if [ -z "$LOG" ]; then
  echo "no group meridian-freight/logistics - run Chapter 7 first" >&2
  exit 1
fi

echo "creating client $CLIENT with $N roles"
seq 1 "$N" | jq -R '{name: ("perm-" + .)}' | jq -s \
  --arg c "$CLIENT" '{ifResourceExists: "SKIP",
     clients: [{clientId: $c, enabled: true, publicClient: false,
                standardFlowEnabled: false, serviceAccountsEnabled: false}],
     roles: {client: {($c): .}}}' \
  | kc create partialImport -r "$REALM" -f - >/dev/null

echo "granting them to the logistics group"
args=()
for i in $(seq 1 "$N"); do args+=(--rolename "perm-$i"); done
kc add-roles -r "$REALM" --gid "$LOG" --cclientid "$CLIENT" "${args[@]}"

echo "done. Log in again - tokens are reissued, not updated."
