#!/usr/bin/env bash
# Chapter 21 - every error the chapter prints, on purpose.
#
# Needs the three-node cluster:  ./chapters/ch21/cluster-up.sh
# It breaks the cluster deliberately and puts it back.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh

C=cluster
export VAULT_CACERT="$PWD/$C/tls/cert.pem"
export VAULT_ADDR="https://127.0.0.1:8210"
[ -f $C/init.json ] || { echo "run ./chapters/ch21/cluster-up.sh first"; exit 1; }
VAULT_TOKEN=$(jq -r .root_token $C/init.json); export VAULT_TOKEN
UK=$(jq -r '.unseal_keys_b64[0]' $C/init.json)

at() { VAULT_ADDR="https://127.0.0.1:$1" vault "${@:2}"; }
sealed() { at "$1" status -format=json 2>/dev/null | jq -r '.sealed' 2>/dev/null; }

wwr_case "the cluster works but every request is slow"
echo "What a load balancer sees. Only one of these is the leader:"
for p in 8210 8220 8230; do
  printf '  %s: %s\n' "$p" \
    "$(curl -s -o /dev/null -w '%{http_code}' --cacert "$VAULT_CACERT" \
        "https://127.0.0.1:$p/v1/sys/health")"
done
echo "429 means standby. A balancer that treats it as healthy sends"
echo "traffic to a node that must forward it - one extra hop, hidden"
echo "behind low latency until the day it is not."

wwr_case "x509: certificate is valid for ... not vault-N"
echo "The cluster certificate names exactly three nodes:"
openssl x509 -in "$C/tls/cert.pem" -noout -ext subjectAltName | tail -1 | sed 's/^/  /'
echo
echo "Reaching a node by a name it does not carry - which is what a fourth"
echo "node joining with this certificate would do:"
out=$(curl -sv --cacert "$C/tls/cert.pem" --resolve vault-9:8210:127.0.0.1 \
        https://vault-9:8210/v1/sys/health 2>&1 | grep -iE "subjectAltName does not match|no alternative certificate subject name" | head -2)
printf '%s\n' "${out:-  (curl gave no detail - exit 60 is the certificate check)}" | sed 's/^/  /'
echo "and by a name it does carry:"
printf '  vault-1: HTTP %s\n' \
  "$(curl -s -o /dev/null -w '%{http_code}' --cacert "$C/tls/cert.pem" \
      --resolve vault-1:8210:127.0.0.1 https://vault-1:8210/v1/sys/health)"
echo
echo "This is the single most common failure when building a cluster by"
echo "hand: a certificate generated for one node, copied to three."

wwr_case "a node joins and immediately leaves - duplicate node_id"
docker rm -f vault-4 >/dev/null 2>&1
rm -rf $C/data4 && mkdir -p $C/data4 && chmod 777 $C/data4
sed 's/vault-4/vault-2/g' $C/config/vault-4.hcl > $C/config/vault-dup.hcl
echo "A configuration copied from vault-2 without editing node_id:"
grep node_id $C/config/vault-dup.hcl | sed 's/^/  /'
echo "Raft resolves two members claiming one identity by keeping one."
echo "This is why cluster-up.sh writes a config per node in a loop."
rm -f $C/config/vault-dup.hcl

wwr_case "HA Enabled false on a Raft node"
echo "cluster_addr is what makes Raft say HA Enabled true:"
at 8210 status -format=json | jq -r '"  vault-1  HA Enabled: \(.ha_enabled)"'
grep -c cluster_addr $C/config/vault-1.hcl | sed 's/^/  cluster_addr lines in vault-1.hcl: /'
echo "Remove it and Vault runs single-node without HA - silently, which"
echo "is Chapter 20's failure met again."

wwr_case "local node not active but active cluster node not found"
echo "Quorum for three nodes is two. Stop one - still fine:"
docker stop vault-3 >/dev/null 2>&1
sleep 2
at 8210 kv put -mount=cluster-demo probe n=1 >/dev/null 2>&1 \
  || vault secrets enable -path=cluster-demo -version=2 kv >/dev/null 2>&1
at 8210 kv put -mount=cluster-demo probe n=1 >/dev/null 2>&1 && echo "  writes still work"
echo "Stop a second, and quorum is gone:"
docker stop vault-2 >/dev/null 2>&1
sleep 3
at 8210 kv put -mount=cluster-demo probe n=2 2>&1 | sed -n '1,6p' | grep -v '^$' | sed 's/^/  /'
echo
echo "Counting is the diagnosis: running AND unsealed nodes against"
echo "(n / 2) + 1. Starting a container is not enough."

wwr_case "putting it back"
docker start vault-2 vault-3 >/dev/null 2>&1
# A restarted node comes back sealed AND has to rejoin before the key is
# accepted. Waiting only for "sealed" unseals too early and silently does
# nothing - the same trap cluster-up.sh had.
for p in 8220 8230; do
  for _ in $(seq 60); do
    out=$(VAULT_ADDR="https://127.0.0.1:$p" vault status -format=json 2>/dev/null || true)
    [ -n "$out" ] && printf '%s' "$out" | jq -e '.initialized' >/dev/null 2>&1 && break
    sleep 1
  done
  for _ in $(seq 10); do
    [ "$(sealed "$p")" = "false" ] && break
    at "$p" operator unseal "$UK" >/dev/null 2>&1 || true
    sleep 1
  done
  printf '  %s sealed: %s\n' "$p" "$(sealed "$p")"
done
for _ in $(seq 30); do
  at 8210 operator raft list-peers >/dev/null 2>&1 && break
  sleep 1
done
at 8210 operator raft list-peers 2>&1 | sed 's/^/  /'
at 8210 kv put -mount=cluster-demo probe n=3 >/dev/null 2>&1 \
  && echo "  writes work again"
vault secrets disable cluster-demo >/dev/null 2>&1 || true

echo
echo "Not reproduced here: recovery from total quorum loss via"
echo "raft/peers.json. It is the one procedure in this book that is"
echo "genuinely difficult under pressure, and it deserves a rehearsal"
echo "with the cluster you actually run - see the chapter."
rm -f $C/config/vault-4.hcl; rm -rf $C/data4
wwr_done
