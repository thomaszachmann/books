#!/usr/bin/env bash
# Schrittweiser Canary: Gewicht von shop-v2 erhöhen, nach jedem Schritt messen.
# Bei Fehlern sofort zurück auf 100 % shop-v1.
# Aufruf: rollout.sh [Schritte ...]   Default: 10 25 50 100
set -euo pipefail
if [ $# -gt 0 ]; then steps=("$@"); else steps=(10 25 50 100); fi
N="${N:-200}"
MAX_ERR="${MAX_ERR:-0}"

set_weights() {  # $1 = Gewicht v1, $2 = Gewicht v2
  kubectl -n shop patch httproute shop --type=json -p "[
    {\"op\":\"replace\",\"path\":\"/spec/rules/0/backendRefs/0/weight\",\"value\":$1},
    {\"op\":\"replace\",\"path\":\"/spec/rules/0/backendRefs/1/weight\",\"value\":$2}
  ]" >/dev/null
}

for w in "${steps[@]}"; do
  set_weights $((100 - w)) "$w"
  sleep "${SETTLE:-3}"
  result=$("$(dirname "$0")/measure.sh" "$N")
  v2=$(awk '$2=="shop-v2"{print $1}' <<<"$result"); v2=${v2:-0}
  err=$(awk '$2=="FEHLER"{print $1}' <<<"$result"); err=${err:-0}
  printf 'Schritt %3s%%: shop-v2=%3s/%s Fehler=%s\n' "$w" "$v2" "$N" "$err"
  if [ "$err" -gt "$MAX_ERR" ]; then
    set_weights 100 0
    echo "ROLLBACK: $err Fehler > $MAX_ERR – zurück auf 100 % shop-v1"
    exit 1
  fi
done
echo "Rollout fertig: 100 % shop-v2"
