#!/usr/bin/env bash
# Was ein Lease kostet, und was das Aufraeumen NICHT zurueckgibt.
#
# Die Kernmessung ist der Widerspruch am Ende: der Snapshot faellt
# auf den Ausgangswert zurueck, das Verzeichnis auf der Platte
# nicht. Freigegebene Seiten der eingebetteten Datenbank werden
# wiederverwendet, aber nie an das Dateisystem zurueckgegeben.
#
# Achtung bei der Laufzeit: die Schleife unten startet die CLI je
# einmal pro Token. Das dominiert die Dauer voellig und sagt
# NICHTS ueber Vaults Durchsatz.
set -uo pipefail

cd "$(dirname "$0")/../.."

N=${N:-2000}
NBATCH=${NBATCH:-500}
DATADIR=${DATADIR:-cluster/data1}
PREFIX=sys/leases/lookup/auth/token/create

sz(){ sudo du -sk "$DATADIR" 2>/dev/null | awk '{print $1}'; }
snap(){ vault operator raft snapshot save /tmp/lg.snap >/dev/null 2>&1
        stat -c%s /tmp/lg.snap; }
count(){ vault list -format=json "$PREFIX" 2>/dev/null \
         | jq 'length // 0'; }

echo "== baseline =="
printf '  raft %s KB   snapshot %s B   leases %s\n' \
  "$(sz)" "$(snap)" "$(count)"

vault policy write noop - >/dev/null <<'POL'
path "sys/capabilities-self" { capabilities = ["update"] }
POL

echo "== $N service tokens =="
t0=$(date +%s)
for i in $(seq 1 "$N"); do
  vault token create -policy=noop -ttl=24h >/dev/null 2>&1
done
printf '  created in %ds (CLI-bound, not Vault)\n' $(( $(date +%s)-t0 ))
printf '  raft %s KB   snapshot %s B   leases %s\n' \
  "$(sz)" "$(snap)" "$(count)"

echo "== revoke, in a LOOP - one call times out partway =="
pass=0
while [ "$(count)" != "0" ] && [ "$pass" -lt 10 ]; do
  pass=$((pass+1)); n=$(count); t0=$(date +%s)
  vault lease revoke -prefix -force auth/token/create >/dev/null 2>&1
  printf '  pass %d: %s leases before, %ds, raft now %s KB\n' \
    "$pass" "$n" $(( $(date +%s)-t0 )) "$(sz)"
done

echo "== the two numbers that disagree =="
printf '  snapshot back to %s B   but raft still %s KB\n' \
  "$(snap)" "$(sz)"

echo "== $NBATCH batch tokens, same measurement =="
vault write auth/token/roles/batchrole allowed_policies=noop \
  token_type=batch renewable=false >/dev/null 2>&1
before=$(sz); bsnap=$(snap)
for i in $(seq 1 "$NBATCH"); do
  vault token create -role=batchrole -ttl=24h >/dev/null 2>&1
done
printf '  raft %s -> %s KB (delta %s)   snapshot %s -> %s B   leases %s\n' \
  "$before" "$(sz)" "$(( $(sz) - before ))" "$bsnap" "$(snap)" "$(count)"
