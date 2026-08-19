#!/usr/bin/env bash
# Chapter 4, step 5. Perform by hand what docker pull does by itself:
# get challenged, fetch a scoped bearer token, read its scope, use it.
#
#   HARBOR_PASS=... ./token-dance.sh platform/base 3.20
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO="${1:-platform/base}"
TAG="${2:-3.20}"
URL="${HARBOR_URL:-https://harbor.meridian.test}"
USER="${HARBOR_USER:-admin}"
PASS="${HARBOR_PASS:?set HARBOR_PASS - the CLI secret works too}"

echo "== 1. ask without credentials"
CHAL=$(curl -skI "$URL/v2/$REPO/manifests/$TAG" \
       | tr -d '\r' | grep -i '^www-authenticate:' || true)
[ -n "$CHAL" ] || { echo "no challenge - is the project public?"; exit 1; }
printf '%s\n' "$CHAL" | tr ' ,' '\n\n'

REALM=$(printf '%s' "$CHAL" | sed -n 's/.*realm="\([^"]*\)".*/\1/p')
SVC=$(printf '%s' "$CHAL"   | sed -n 's/.*service="\([^"]*\)".*/\1/p')

echo
echo "== 2. exchange credentials for a scoped token"
TOKEN=$(curl -sk -u "$USER:$PASS" \
  "$REALM?service=$SVC&scope=repository:$REPO:pull" | jq -r .token)
[ "$TOKEN" != null ] || { echo "no token - check the credentials"; exit 1; }

echo "   scope, from inside the token itself:"
"$HERE/jwt-decode.sh" "$TOKEN" | jq -c '.access'
echo "   expires_in, seconds:"
"$HERE/jwt-decode.sh" "$TOKEN" | jq '.exp - .iat'

echo
echo "== 3. use it"
curl -skI -H "Authorization: Bearer $TOKEN" \
  "$URL/v2/$REPO/manifests/$TAG" | head -1

echo
echo "The token names one repository and one action. That is why a"
echo "robot account with the wrong scope fails at push and not at login."
