#!/usr/bin/env bash
# Wo die Zeit hingeht - in der Reihenfolge, in der die Ursachen
# tatsaechlich vorkommen.
#
# WICHTIG zur Methode: eine Schleife um die CLI misst nichts. Der
# Start des Go-Binaries kostet ~318ms und ist groesser als jeder
# Effekt, den dieses Skript findet. Deshalb rohes HTTP - und in
# EINEM curl-Aufruf mit wiederholter URL, damit die Verbindung
# wiederverwendet wird. Sonst misst man 22ms TLS-Handschlag je
# Anfrage statt Vault.
set -uo pipefail

cd "$(dirname "$0")/../.."

CA=${CA:-cluster/tls/cert.pem}
N=${N:-100}
T=${VAULT_TOKEN:-$(jq -r .root_token cluster/init.json)}

port_of_leader(){
  for p in 8210 8220 8230; do
    if curl -s --cacert "$CA" "https://127.0.0.1:$p/v1/sys/health" \
       2>/dev/null | jq -e '.standby == false' >/dev/null 2>&1
    then echo "$p"; return; fi
  done
  echo 8210
}
# Der Vergleichsknoten muss ein ENTSIEGELTER Standby sein.
# Ein versiegelter Knoten antwortet blitzschnell mit einem Fehler
# - im ersten Anlauf las der "Standby" dadurch scheinbar schneller
# als der Leader, und die Weiterleitungs-Metrik fehlte, weil ein
# versiegelter Knoten sie gar nicht exportiert.
port_of_standby(){
  for p in 8210 8220 8230; do
    [ "$p" = "$1" ] && continue
    if curl -s --cacert "$CA" "https://127.0.0.1:$p/v1/sys/health" \
       2>/dev/null | jq -e '.standby == true and .sealed == false' \
       >/dev/null 2>&1
    then echo "$p"; return; fi
  done
}
L=$(port_of_leader); S=$(port_of_standby "$L")
if [ -z "$S" ]; then
  echo "ABBRUCH: kein entsiegelter Standby. 'make unseal' und" \
       "erneut versuchen - sonst misst Abschnitt 2 einen" \
       "versiegelten Knoten und meldet ihn als schnell." >&2
  exit 1
fi
echo "leader $L, unsealed standby for comparison: $S"

rep(){ local u=$1 n=$2 out=""
       for _ in $(seq 1 "$n"); do out="$out $u"; done; echo "$out"; }

run(){ # $1 label  $2 url  $3.. extra curl args
  local label=$1 url=$2; shift 2
  local best=9999999
  for _ in 1 2 3; do
    # shellcheck disable=SC2046
    s=$(date +%s%N)
    curl -s --cacert "$CA" -H "X-Vault-Token: $T" "$@" \
      $(rep "$url" "$N") >/dev/null
    v=$(( ($(date +%s%N)-s)/1000000 ))
    [ "$v" -lt "$best" ] && best=$v
  done
  printf '  %-30s %6.2f ms/op  (best of 3)\n' \
    "$label" "$(echo "scale=2; $best/$N" | bc)"
}

echo
echo "== 0. what does the harness itself cost =="
curl -s -o /dev/null --cacert "$CA" -H "X-Vault-Token: $T" \
  -w '  one fresh connection: tls %{time_appconnect}s total %{time_total}s\n' \
  "https://127.0.0.1:$L/v1/sys/health"

echo
echo "== 1. reads vs writes on the leader =="
curl -s --cacert "$CA" -H "X-Vault-Token: $T" -X POST \
  -d '{"data":{"v":"1"}}' \
  "https://127.0.0.1:$L/v1/secret/data/perf/a" >/dev/null 2>&1
run "sys/health (no storage)" "https://127.0.0.1:$L/v1/sys/health"
run "KV read" "https://127.0.0.1:$L/v1/secret/data/perf/a"
run "KV write" "https://127.0.0.1:$L/v1/secret/data/perf/w" \
    -X POST -d '{"data":{"v":"1"}}'

echo
echo "== 2. does a standby serve reads, or forward them? =="
fwd(){ curl -s --cacert "$CA" \
  "https://127.0.0.1:$S/v1/sys/metrics?format=prometheus" \
  | grep '^vault_ha_rpc_client_forward_count' | awk '{print $2}'; }
before=$(fwd)
# shellcheck disable=SC2046
curl -s --cacert "$CA" -H "X-Vault-Token: $T" \
  $(rep "https://127.0.0.1:$S/v1/secret/data/perf/a" 25) >/dev/null
sleep 3
echo "  forward_count on the standby: ${before:-0} -> $(fwd)  (after 25 reads)"
run "KV read via standby" "https://127.0.0.1:$S/v1/secret/data/perf/a"

echo
echo "== 3. payload size =="
for sz in 100 10000 100000; do
  v=$(head -c "$sz" /dev/zero | tr '\0' 'x')
  run "write ${sz} bytes" \
      "https://127.0.0.1:$L/v1/secret/data/sz$sz" \
      -X POST -d "{\"data\":{\"v\":\"$v\"}}"
done

cat <<'TXT'

  Reihenfolge beim Suchen, nicht die Reihenfolge der Vermutungen:
    1 Verbindungswiederverwendung im Client
    2 Lesen oder Schreiben (Faktor ~8)
    3 spricht der Client einen Standby an (Faktor ~2, keine Kapazitaet)
    4 Anmeldungen je Anfrage - jede Anmeldung ist ein Schreibvorgang
    5 Policies je Token (~24us je Policy)
    6 Nutzlast (erst ab ~10 KB)
    7 die Platte - zuletzt, nicht zuerst
TXT
