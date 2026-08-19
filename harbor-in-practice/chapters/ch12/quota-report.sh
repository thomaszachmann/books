#!/usr/bin/env bash
# Quota usage per project, with the two things the numbers do not say.
#
# Harbor has exactly one quota resource: storage, in bytes. There is no
# artifact or tag count limit - that is retention, Chapter 11.
#
# A blob upload consumes quota only if the blob is not already
# associated with THAT project. So a layer shared inside a project is
# charged once, and the same layer in six projects is charged six times
# for one set of bytes on disk. The sum below is therefore an upper
# bound on disk usage, and the gap is your cross-project sharing.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
THRESH="${1:-80}"

json="${QUOTAS_JSON:-}"
if [ -z "$json" ]; then
  json=$("$ROOT/scripts/harbor-api.sh" GET '/quotas?page_size=100')
fi

human() { numfmt --to=iec "$1" 2>/dev/null || echo "$1"; }

printf '%-22s %12s %12s %7s\n' PROJECT USED HARD PCT
printf '%s' "$json" | jq -r '.[]
  | "\(.ref.name // "?")\t\(.used.storage // 0)\t\(.hard.storage // -1)"' \
| while IFS=$'\t' read -r name used hard; do
    if [ "$hard" -le 0 ]; then pct="-"; else pct="$(( used * 100 / hard ))%"; fi
    printf '%-22s %12s %12s %7s\n' "$name" "$(human "$used")" \
      "$([ "$hard" -le 0 ] && echo unlimited || human "$hard")" "$pct"
  done

total=$(printf '%s' "$json" | jq '[.[].used.storage // 0] | add // 0')
echo
echo "sum of project usage   $(human "$total")"
echo "on disk                run 'sudo du -sh /data/registry' on the VM"
echo
echo "The sum is >= the disk. The difference is the layer sharing"
echo "between projects. Plan capacity on the disk, set limits on the"
echo "projects; they answer different questions."

over=$(printf '%s' "$json" | jq --argjson t "$THRESH" '
  [ .[] | select((.hard.storage // -1) > 0)
        | select(.used.storage * 100 / .hard.storage > $t) ] | length')
echo
echo "$over project(s) above ${THRESH}% of quota"
[ "$over" -eq 0 ]
