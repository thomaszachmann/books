#!/usr/bin/env bash
# Beweist, dass der ueblich empfohlene Seal-Alarm falsch ist.
#
# vault_core_unsealed == 0 feuert auf einem kerngesunden Leader,
# weil dieser eine Restzeitreihe mit leerem cluster-Label auf 0
# exportiert. Das Label taugt auch nicht zum Filtern: ein
# wirklich versiegelter Knoten traegt das ECHTE label mit 0.
#
# Richtig ist nur:  max without (cluster) (vault_core_unsealed)
set -uo pipefail

cd "$(dirname "$0")/../.."
. ./scripts/engine.sh

CA=${CA:-cluster/tls/cert.pem}
PORTS=${PORTS:-"8210 8220 8230"}

metrics(){ curl -s --cacert "$CA" \
  "https://127.0.0.1:$1/v1/sys/metrics?format=prometheus"; }

show(){
  for p in $PORTS; do
    sealed=$(VAULT_ADDR=https://127.0.0.1:$p vault status \
             -format=json 2>/dev/null | jq -r '.sealed // "?"')
    fams=$(metrics "$p" | grep -c '^# TYPE')
    printf '  port %s  sealed=%-5s families=%-4s\n' \
      "$p" "$sealed" "$fams"
    metrics "$p" | grep '^vault_core_unsealed' | sed 's/^/      /'
  done
}

echo "== alle drei entsiegelt =="
show

echo "== jetzt einen knoten versiegeln =="
$ENGINE restart vip-vault-3 >/dev/null 2>&1
sleep 8
show

cat <<'TXT'

  naiv:    vault_core_unsealed == 0
           -> feuert auf dem gesunden Leader (Restzeitreihe)
  gefiltert: vault_core_unsealed{cluster!=""} == 0
           -> verfehlt die Standbys, trifft aber den versiegelten
  richtig: max without (cluster) (vault_core_unsealed) == 0

  Und: ein versiegelter Knoten exportiert nur einen Bruchteil der
  Familien. Was dort nicht mehr gemeldet wird, kann auch nicht
  ueber einen Schwellwert feuern - dafuer braucht es absent().
TXT
