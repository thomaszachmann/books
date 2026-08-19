#!/usr/bin/env bash
# Create a project, or bring an existing one into line. Idempotent on
# purpose: running it twice is not an error, and running it after
# somebody clicked something corrects the click.
#
#   HARBOR_PASS=... ./create-project.sh platform auto_scan=true
#
# Every metadata value is a STRING. Harbor accepts a JSON boolean,
# returns 201, and discards it. No error, no effect.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API="$ROOT/scripts/harbor-api.sh"

NAME="${1:?a project name}"; shift

meta='{"public":"false"}'
for kv in "$@"; do
  meta=$(printf '%s' "$meta" \
    | jq --arg k "${kv%%=*}" --arg v "${kv#*=}" '. + {($k): $v}')
done

code=$("$API" GET "/projects/$NAME" -o /dev/null -w '%{http_code}')
if [ "$code" = 200 ]; then
  echo "exists, reconciling metadata"
  "$API" PUT "/projects/$NAME" -d "{\"metadata\":$meta}" \
    -o /dev/null -w 'PUT %{http_code}\n'
else
  "$API" POST /projects \
    -d "{\"project_name\":\"$NAME\",\"metadata\":$meta}" \
    -o /dev/null -w 'POST %{http_code}\n'
fi

"$API" GET "/projects/$NAME" | jq '{name, metadata}'
