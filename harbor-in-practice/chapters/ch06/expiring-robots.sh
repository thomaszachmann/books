#!/usr/bin/env bash
# Report robots expiring within N days. Exits non-zero if any are.
#
#   ./expiring-robots.sh 14
#
# The whole trick is select(.expires_at > 0). Harbor uses -1 for "never
# expires", and -1 is smaller than any threshold - so without that
# filter every non-expiring robot is reported as expiring immediately,
# the alert fires constantly, somebody switches it off, and the check
# that would have caught the real expiry is gone.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

DAYS="${1:-14}"
NOW=$(date +%s)

json="${ROBOTS_JSON:-}"
if [ -z "$json" ]; then
  json=$("$ROOT/scripts/harbor-api.sh" GET '/robots?page_size=100')
fi

printf '%s' "$json" | jq -r --argjson now "$NOW" --argjson d "$DAYS" '
  def days: ((. - $now) / 86400) | floor;
  [ .[] | select(.expires_at > 0) | select(.expires_at - $now < $d * 86400) ]
  as $soon
  | ( [ .[] | select(.expires_at == -1) ] as $never
    | ( $never[] | "never   \(.name)" ),
      ( $soon[]  | "\(.expires_at | days) days  \(.name)" ) )
'

count=$(printf '%s' "$json" | jq --argjson now "$NOW" --argjson d "$DAYS" '
  [ .[] | select(.expires_at > 0)
        | select(.expires_at - $now < $d * 86400) ] | length')

echo
echo "$count robot(s) expire within $DAYS days"
[ "$count" -eq 0 ]
