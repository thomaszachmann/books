#!/usr/bin/env bash
# Proves that the commonly recommended seal alert is wrong.
# Chapter 17.
#
# vault_core_unsealed == 0 fires on a perfectly healthy leader,
# because it exports a leftover series with an empty cluster label
# at 0. The label is no good for filtering either: a node that is
# really sealed carries the REAL label with 0.
#
# Only this is right:  max without (cluster) (vault_core_unsealed)
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
. ./scripts/engine.sh

CA=${CA:-cluster/tls/cert.pem}
PORTS=${PORTS:-"8210 8220 8230"}

metrics(){ curl -s --cacert "$CA" \
  "https://127.0.0.1:$1/v1/sys/metrics?format=prometheus"; }

show(){
  for p in $PORTS; do
    # Do NOT use  jq -r '.sealed // "?"':  // is jq's alternative
    # operator and treats false as empty, so an unsealed node
    # (sealed: false) becomes "?". The error runs in exactly the
    # direction that hides a problem - fitting for this chapter.
    sealed=$(VAULT_ADDR=https://127.0.0.1:$p vault status \
             -format=json 2>/dev/null \
             | jq -r 'if has("sealed") then (.sealed|tostring)
                      else "?" end')
    fams=$(metrics "$p" | grep -c '^# TYPE')
    printf '  port %s  sealed=%-5s families=%-4s\n' \
      "$p" "$sealed" "$fams"
    metrics "$p" | grep '^vault_core_unsealed' | sed 's/^/      /'
  done
}

echo "== all three unsealed =="
show

echo "== now seal one node =="
$ENGINE restart vip-vault-3 >/dev/null 2>&1
sleep 8
show

cat <<'TXT'

  naive:    vault_core_unsealed == 0
            -> fires on the healthy leader (leftover series)
  filtered: vault_core_unsealed{cluster!=""} == 0
            -> misses the standbys, but catches the sealed one
  right:    max without (cluster) (vault_core_unsealed) == 0

  And: a sealed node exports only a fraction of the families.
  What is no longer reported there cannot cross a threshold
  either - that needs absent().
TXT
