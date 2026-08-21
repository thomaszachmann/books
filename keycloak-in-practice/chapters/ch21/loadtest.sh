#!/usr/bin/env bash
# What actually costs Keycloak anything. Chapter 21.
#
# Two loops, deliberately unequal:
#   logins        hit Keycloak, do password hashing and write a session
#   verifications hit nothing at all - a signature check, offline
#
# The point is not a benchmark. It is that the second number is not a
# load on Keycloak in any sense, and sizing conversations usually start
# by confusing the two.
set -euo pipefail

cd "$(dirname "$0")/../.."
ISS=${ISS:-https://sso.meridian.test/realms/meridian}
N=${1:-50}
CLIENT=${CLIENT:-meridian-batch}
SECRET=${SECRET:?set SECRET to the meridian-batch client secret}

echo "$N client-credential logins"
start=$(date +%s)
for _ in $(seq 1 "$N"); do
  curl -sS -o /dev/null -X POST "$ISS/protocol/openid-connect/token" \
    -d grant_type=client_credentials \
    -d client_id="$CLIENT" -d client_secret="$SECRET"
done
end=$(date +%s)
echo "  $((end - start))s  -> $((N / ((end - start) > 0 ? end - start : 1)))/s"

echo
echo "$N local signature verifications, for comparison"
TOKEN=$(curl -sS -X POST "$ISS/protocol/openid-connect/token" \
  -d grant_type=client_credentials \
  -d client_id="$CLIENT" -d client_secret="$SECRET" | jq -r .access_token)
curl -sS "$ISS/protocol/openid-connect/certs" > /tmp/jwks.json

start=$(date +%s)
for _ in $(seq 1 "$N"); do
  printf '%s' "$TOKEN" | cut -d. -f2 >/dev/null
done
end=$(date +%s)
echo "  $((end - start))s  - and zero requests reached Keycloak"

cat <<'NEXT'

The second loop is a stand-in: a real verifier checks the signature
against the JWKS it already holds. Either way, no request is made. Size
Keycloak for the first number.
NEXT
