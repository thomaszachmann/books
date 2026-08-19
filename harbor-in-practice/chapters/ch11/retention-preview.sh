#!/usr/bin/env bash
# What a retention run would delete. Never skip this.
#
# Harbor's retention rules only ever RETAIN - all seven templates have
# the action "retain", and there is no delete action. So a policy is read
# as "delete everything no rule keeps", which is the opposite of how
# people write cleanup rules and the reason a policy that looks harmless
# removes a release that is still in production.
#
#   ./retention-preview.sh <policy-id> [execution-id]
#   TASKS_JSON="$(cat fixture.json)" ./retention-preview.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API="$ROOT/scripts/harbor-api.sh"

json="${TASKS_JSON:-}"
if [ -z "$json" ]; then
  PID="${1:?a retention policy id}"
  EID="${2:-}"
  if [ -z "$EID" ]; then
    EID=$("$API" GET "/retentions/$PID/executions" | jq -r '.[0].id')
    dry=$("$API" GET "/retentions/$PID/executions" | jq -r '.[0].dry_run')
    [ "$dry" = true ] || echo "warning: latest execution was NOT a dry run" >&2
  fi
  json=$("$API" GET "/retentions/$PID/executions/$EID/tasks")
fi

printf '%-34s %8s %9s %8s\n' REPOSITORY TOTAL RETAINED DELETE
printf '%s' "$json" | jq -r '.[]
  | "\(.repository)\t\(.total)\t\(.retained)"' \
| while IFS=$'\t' read -r repo total retained; do
    printf '%-34s %8s %9s %8s\n' "$repo" "$total" "$retained" \
      "$(( total - retained ))"
  done

tot=$(printf '%s' "$json" | jq '[.[].total] | add // 0')
ret=$(printf '%s' "$json" | jq '[.[].retained] | add // 0')
echo
echo "$(( tot - ret )) of $tot artifact(s) would be removed."
echo
echo "Removing them frees no disk. Blobs go when garbage collection"
echo "runs - see ./gc-status.sh and Chapter 11, step 5."
