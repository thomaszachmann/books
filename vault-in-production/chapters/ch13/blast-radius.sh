#!/usr/bin/env bash
# Stop Vault, poll both credentials against the DATABASE, start
# Vault again, and keep polling - the interesting event is about
# twenty seconds after unsealing, not during the outage.
set -euo pipefail

ENGINE=${ENGINE:-docker}
NODES=${NODES:-"vip-vault-1 vip-vault-2 vip-vault-3"}

vault read -format=json database/creds/app       > /tmp/w1.json
vault read -format=json database/creds/app-noexp > /tmp/w2.json

u(){ jq -r .data.username "$1"; }; p(){ jq -r .data.password "$1"; }

# Prove the harness works before trusting a single result.
if $ENGINE exec -e PGPASSWORD=definitely-wrong pgclient \
     psql -h blast-db -U postgres -d appdb -tAc 'select 1' \
     >/dev/null 2>&1; then
  echo "ABORT: a wrong password was accepted; this test proves" \
       "nothing. Check that you are not connecting via a trust" \
       "line in pg_hba.conf." >&2
  exit 1
fi

try(){ $ENGINE exec -e PGPASSWORD="$2" pgclient \
         psql -h blast-db -U "$1" -d appdb -tAc 'select 1' \
         >/dev/null 2>&1 && printf 'valid     ' || printf 'REJECTED  '; }

row(){ printf '[+%03ds]  ' $(( $(date +%s) - t0 ))
       try "$(u /tmp/w1.json)" "$(p /tmp/w1.json)"
       try "$(u /tmp/w2.json)" "$(p /tmp/w2.json)"; echo; }

# shellcheck disable=SC2086
$ENGINE stop $NODES >/dev/null
t0=$(date +%s)
printf '%-9s %-10s %s\n' 'time' 'with VALID' 'without'
for w in 0 30 45 60 60; do [ "$w" -gt 0 ] && sleep "$w"; row; done

echo "-- orphaned roles while Vault is down --"
$ENGINE exec blast-db psql -U postgres -d appdb -tAc \
  "select count(*) from pg_roles where rolname like 'v-root-app%'"

# shellcheck disable=SC2086
$ENGINE start $NODES >/dev/null
t0=$(date +%s); sleep 5
make -C "$(git rev-parse --show-toplevel)/vault-in-production" \
  unseal >/dev/null 2>&1 || true
echo "-- after Vault returns --"
for _ in $(seq 1 12); do row; sleep 10; done

echo "-- orphaned roles after recovery --"
$ENGINE exec blast-db psql -U postgres -d appdb -tAc \
  "select count(*) from pg_roles where rolname like 'v-root-app%'"
