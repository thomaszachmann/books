#!/usr/bin/env bash
# Chapter 21 - lose quorum on purpose, then recover.
#
# The instinct is that one working machine should serve read-only
# traffic. Raft refuses, and the refusal is correct: a node that cannot
# see a majority cannot know whether writes it has not seen were
# accepted. Serving stale data silently would be worse.
set -uo pipefail
cd "$(dirname "$0")/../.."

C=cluster
export VAULT_CACERT="$PWD/$C/tls/cert.pem"
export VAULT_ADDR='https://127.0.0.1:8210'
export VAULT_TOKEN=$(jq -r '.root_token' $C/init.json)
UK=$(jq -r '.unseal_keys_b64[0]' $C/init.json)
DC="docker compose -f docker-compose.cluster.yml"

vault secrets enable -path=meridian -version=2 kv >/dev/null 2>&1 || true

echo "== 3 of 3: quorum 2, writes work =="
vault kv put meridian/ha test=three-of-three >/dev/null && echo "   ok"

echo "== stopping one node =="
$DC stop vault-3 >/dev/null 2>&1; sleep 5
vault kv put meridian/ha test=two-of-three >/dev/null 2>&1 \
  && echo "   still ok - two of three is a majority"

echo "== stopping a second node: quorum lost =="
$DC stop vault-2 >/dev/null 2>&1; sleep 5
echo -n "   write: "
vault kv put meridian/ha test=one-of-three 2>&1 | tail -1 | sed 's/^\s*//'
echo -n "   read:  "
vault kv get meridian/ha 2>&1 | tail -1 | sed 's/^\s*//'

echo
echo "== recovering =="
$DC start vault-2 >/dev/null 2>&1; sleep 6
# Starting the container is NOT enough. It comes back sealed.
VAULT_ADDR='https://127.0.0.1:8220' vault operator unseal "$UK" >/dev/null
sleep 5
vault kv put meridian/ha test=recovered >/dev/null && echo "   writes work again"

$DC start vault-3 >/dev/null 2>&1; sleep 6
VAULT_ADDR='https://127.0.0.1:8230' vault operator unseal "$UK" >/dev/null
sleep 3
vault operator raft list-peers

echo
echo "Note what recovery required: not restarting containers, but"
echo "UNSEALING them. In a real incident that is people with keys, at"
echo "whatever hour it is. That is the argument for Chapter 22."
