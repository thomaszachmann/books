#!/usr/bin/env bash
# Die Audit-Schleife, gemessen.
#
# ACHTUNG: dieses Skript sperrt den Cluster absichtlich aus und
# holt ihn wieder herein. Nur gegen das Labor laufen lassen.
#
# Der wichtige Teil ist die DAUER. Mit einem einzigen kaputten
# Audit-Geraet laeuft Vault noch etwa 35 Sekunden voellig normal
# weiter - so lange, wie der Socket-Puffer traegt. Jede Messung
# unter einer Minute meldet deshalb "alles in Ordnung", egal wie
# es wirklich steht.
set -uo pipefail

cd "$(dirname "$0")/../.."
. ./scripts/engine.sh

NET=${NET:-vault-in-production_default}
ALPINE=${ALPINE:-docker.io/library/alpine:3.20}
ROUNDS=${ROUNDS:-60}
GAP=${GAP:-2}

sink_up(){
  $ENGINE rm -f logsink >/dev/null 2>&1
  $ENGINE run -d --name logsink --network "$NET" "$ALPINE" \
    sh -c 'apk add -q --no-cache netcat-openbsd; nc -lk -p 5140 > /tmp/rx.log' \
    >/dev/null
  for _ in $(seq 1 30); do
    $ENGINE exec logsink sh -c 'netstat -ltn 2>/dev/null | grep -q 5140' \
      && return 0
    sleep 2
  done
  echo "collector never listened" >&2; return 1
}

hammer(){   # $1 = label
  local ok=0 fail=0 first="" t0; t0=$(date +%s)
  for i in $(seq 1 "$ROUNDS"); do
    if vault kv put "secret/$1$i" a=$i >/dev/null 2>&1
      then ok=$((ok+1))
      else fail=$((fail+1))
           [ -z "$first" ] && first=" (first failure after $(( $(date +%s)-t0 ))s)"
    fi
    sleep "$GAP"
  done
  echo "  over $(( $(date +%s)-t0 ))s: $ok ok, $fail failed$first"
}

echo "== 1. collector up, and PROVE it collects =="
sink_up || exit 1
vault audit enable -path=collector socket \
  address=logsink:5140 socket_type=tcp >/dev/null
vault kv put secret/audittest a=1 >/dev/null 2>&1
sleep 2
got=$($ENGINE exec logsink sh -c 'wc -c < /tmp/rx.log' 2>/dev/null | tr -d ' ')
echo "  collector received ${got:-0} bytes"
if [ "${got:-0}" -lt 100 ]; then
  echo "ABORT: nothing arrived, so a later failure would prove" \
       "nothing." >&2
  exit 1
fi

echo "== 2. make it the only device, then remove the collector =="
vault audit disable file >/dev/null 2>&1
$ENGINE rm -f logsink >/dev/null 2>&1
hammer stress

echo "== 3. try to fix it from inside =="
echo "  vault audit disable collector -> $(vault audit disable collector 2>&1 | tail -1 | tr -d '\n')"

echo "== 4. fix it from outside =="
sink_up || exit 1
t0=$(date +%s)
for _ in $(seq 1 30); do
  vault kv put secret/back a=1 >/dev/null 2>&1 && break
  sleep 2
done
echo "  Vault serves again after $(( $(date +%s)-t0 ))s"

echo "== 5. now with TWO devices, same failure =="
vault audit enable file file_path=/vault/logs/audit.log >/dev/null 2>&1
$ENGINE rm -f logsink >/dev/null 2>&1
hammer two

vault audit disable collector >/dev/null 2>&1
echo "done; 'make reset' to clean up"
