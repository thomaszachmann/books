#!/usr/bin/env bash
# The indicator that lies. Chapter 17.
#
# Restart one node and ask the obvious indicator - does the API
# answer? - then ask again a minute later. Answering and serving
# are different things, and a restarted Shamir node does the first
# within a second and the second only when a person brings a key.
#
#   ./chapters/ch17/slo.sh [node-number]     # default: 3
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/engine.sh
. ./scripts/vault-env.sh

N=${1:-3}
PORT=$((8200 + 10 * N))
URL="https://127.0.0.1:$PORT/v1/sys/health"
code() { curl -s -o /dev/null -w '%{http_code}' \
           --cacert cluster/tls/cert.pem "$URL"; }

$ENGINE restart "vip-vault-$N" >/dev/null
t0=$(date +%s%N)
until c=$(code) && [ "$c" != 000 ]; do sleep 0.05; done
echo "vault-$N is verifiably down, and"
echo "answers after $(( ($(date +%s%N) - t0) / 1000000 ))ms" \
     "with HTTP $c"

sleep 60
c=$(code)
if [ "$c" = 200 ] || [ "$c" = 429 ]; then
  echo "serving again after 60s (HTTP $c)"
else
  echo "no 200 after 60s (HTTP $c). The state:"
  curl -s --cacert cluster/tls/cert.pem "$URL" \
    | jq -r '"  sealed: \(.sealed)   initialized: \(.initialized)"'
fi
echo "('make unseal' brings it back)"
