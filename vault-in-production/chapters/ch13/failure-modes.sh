#!/usr/bin/env bash
# Wie schnell meldet sich welcher Ausfall?
#
# Die dritte Zahl ist die, die entscheidet, ob eine Anwendung
# degradiert oder mitstirbt: ein abgelehnter Verbindungsversuch
# kehrt sofort zurueck, geschluckte Pakete lassen jeden Thread
# in einem "dial tcp" haengen.
#
# Stellt die Zustaende selbst her und raeumt hinterher auf.
# Voraussetzung: . ./scripts/vault-env.sh ist eingelesen und der
# Cluster laeuft entsiegelt.
set -uo pipefail

cd "$(dirname "$0")/../.."
. ./scripts/engine.sh

NODES=${NODES:-"vip-vault-1 vip-vault-2 vip-vault-3"}
PROBE=${PROBE:-"vault read sys/health"}

ms(){ s=$(date +%s%N)
      eval "$1" >/dev/null 2>&1
      printf '  %-28s %6dms\n' "$2" $(( ($(date +%s%N)-s)/1000000 )); }

ms "$PROBE" 'healthy (baseline)'

# 1) versiegelt: der Prozess lebt und antwortet, nur nicht mit Daten
for n in $NODES; do $ENGINE exec "$n" vault operator seal >/dev/null 2>&1 || true; done
# ein Standby laesst sich nicht versiegeln - neu starten wirkt immer
# shellcheck disable=SC2086
$ENGINE restart $NODES >/dev/null 2>&1
sleep 6
ms "$PROBE" 'sealed'

# 2) Prozess weg: das Betriebssystem lehnt die Verbindung ab
# shellcheck disable=SC2086
$ENGINE stop $NODES >/dev/null 2>&1
ms "$PROBE" 'connection refused'

# 3) Netz schluckt die Pakete: niemand antwortet, gar nicht
ms "env VAULT_ADDR=https://10.255.255.1:8210 $PROBE" \
   'packets dropped'
ms "env VAULT_ADDR=https://10.255.255.1:8210 \
    VAULT_CLIENT_TIMEOUT=5s $PROBE" 'dropped, timeout 5s'

# shellcheck disable=SC2086
$ENGINE start $NODES >/dev/null 2>&1
echo "  (nodes started again - they are SEALED, run 'make unseal')"
