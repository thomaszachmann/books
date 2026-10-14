#!/usr/bin/env bash
# The audit loop, measured. Chapter 15.
#
# CAREFUL: this script locks the cluster out on purpose and lets it
# back in. Run it against the lab only, with ./scripts/vault-env.sh
# sourced.
#
# The important part is the DURATION. With a single broken audit
# device Vault keeps working normally for a while - as long as the
# socket buffer takes to fill. Any test shorter than that reports
# "all fine", whatever the real state is.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
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

echo "== 0. what the lab needs first: a KV mount and a file device =="
vault secrets enable -path=secret -version=2 kv >/dev/null 2>&1 || true
vault audit enable file file_path=/vault/logs/audit.log >/dev/null 2>&1 || true
vault kv put secret/ready a=1 >/dev/null \
  || { echo "ABORT: cannot write secret/ while healthy" >&2; exit 1; }
echo "  $(vault audit list | tail -n +3 | awk '{print $1}' | xargs)"

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
# The clock starts before the container does: what the reader
# waits for is the collector starting AND Vault reconnecting.
t0=$(date +%s)
sink_up || exit 1
echo "  collector listening after $(( $(date +%s)-t0 ))s"
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
