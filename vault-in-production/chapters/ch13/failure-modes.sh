#!/usr/bin/env bash
# How quickly does each kind of outage announce itself?
#
# The third number decides whether an application degrades or dies
# with Vault: a refused connection returns at once, dropped packets
# leave every thread hanging in a "dial tcp".
#
# Creates the states itself and cleans up afterwards. Needs:
# . ./scripts/vault-env.sh sourced, cluster running and unsealed.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
. ./scripts/engine.sh

NODES=${NODES:-"vip-vault-1 vip-vault-2 vip-vault-3"}
PROBE=${PROBE:-"vault read sys/health"}

ms(){ s=$(date +%s%N)
      eval "$1" >/dev/null 2>&1
      printf '  %-28s %6dms\n' "$2" $(( ($(date +%s%N)-s)/1000000 )); }

ms "$PROBE" 'healthy (baseline)'

# 1) sealed: the process is alive and answers, just not with data
for n in $NODES; do $ENGINE exec "$n" vault operator seal >/dev/null 2>&1 || true; done
# a standby cannot be sealed - a restart always works
# shellcheck disable=SC2086
$ENGINE restart $NODES >/dev/null 2>&1
sleep 6
ms "$PROBE" 'sealed'

# 2) process gone: the operating system refuses the connection
# shellcheck disable=SC2086
$ENGINE stop $NODES >/dev/null 2>&1
ms "$PROBE" 'connection refused'

# 3) the network swallows the packets: nobody answers at all
ms "env VAULT_ADDR=https://10.255.255.1:8210 $PROBE" \
   'packets dropped'
ms "env VAULT_ADDR=https://10.255.255.1:8210 \
    VAULT_CLIENT_TIMEOUT=5s $PROBE" 'dropped, timeout 5s'

# shellcheck disable=SC2086
$ENGINE start $NODES >/dev/null 2>&1
echo "  (nodes started again - they are SEALED, run 'make unseal')"
