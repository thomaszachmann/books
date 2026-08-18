#!/usr/bin/env bash
# Block until Harbor answers its health endpoint, or give up loudly.
# Usage: wait-for-harbor.sh [url] [seconds]
set -euo pipefail
URL="${1:-https://harbor.meridian.test}"
DEADLINE=$(( SECONDS + ${2:-180} ))

printf 'Waiting for %s ' "$URL"
while [ "$SECONDS" -lt "$DEADLINE" ]; do
  body=$(curl -sk --max-time 5 "$URL/api/v2.0/health" || true)
  if printf '%s' "$body" | grep -q '"status":"healthy"'; then
    echo " up."
    exit 0
  fi
  printf '.'
  sleep 3
done

echo
echo "Harbor did not become healthy in time."
echo "Unhealthy components, if it answered at all:"
curl -sk "$URL/api/v2.0/health" | jq -r '
  .components[]? | select(.status != "healthy")
  | "  \(.name): \(.status) \(.error // "")"' 2>/dev/null || true
echo
echo "Run 'make diagnose'."
exit 1
