#!/usr/bin/env bash
# Is the proxy cache actually able to serve?
#
# The assumption worth breaking: a proxy cache does NOT degrade into
# serving only what it already holds. Harbor checks the upstream
# registry's health before proxying and refuses when it is not healthy -
# so an upstream outage stops pulls of images the cache already has.
#
# This script reports the health that decides that, per proxy project.
#
#   HARBOR_PASS=... ./cache-health.sh
#   PROJECTS_JSON=... REGISTRIES_JSON=... ./cache-health.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API="$ROOT/scripts/harbor-api.sh"

projects="${PROJECTS_JSON:-$("$API" GET '/projects?page_size=100')}"
registries="${REGISTRIES_JSON:-$("$API" GET '/registries?page_size=100')}"

proxies=$(printf '%s' "$projects" \
  | jq '[ .[] | select((.registry_id // 0) > 0) ]')

n=$(printf '%s' "$proxies" | jq 'length')
if [ "$n" -eq 0 ]; then
  echo "no proxy cache projects"
  echo "A project is a proxy cache if and only if registry_id >= 1."
  exit 0
fi

bad=0
printf '%-20s %-18s %-10s\n' PROJECT UPSTREAM STATUS
while IFS=$'\t' read -r pname rid; do
  reg=$(printf '%s' "$registries" \
        | jq -r --argjson id "$rid" '.[] | select(.id == $id)
            | "\(.name)\t\(.status)"')
  rname=${reg%%$'\t'*}; rstatus=${reg##*$'\t'}
  [ -n "$rname" ] || { rname="id $rid"; rstatus="unknown"; }
  printf '%-20s %-18s %-10s\n' "$pname" "$rname" "$rstatus"
  [ "$rstatus" = "healthy" ] || bad=$((bad + 1))
done < <(printf '%s' "$proxies" | jq -r '.[] | "\(.name)\t\(.registry_id)"')

echo
if [ "$bad" -gt 0 ]; then
  cat <<'TXT'
At least one upstream is not healthy. Pulls through that project fail
NOW - including images the cache already holds. This is not a cache
that degrades; it is a cache that refuses.

Replicate the base images that must always work into an ordinary
project and pin builds to that. See Chapter 14, design review 4.
TXT
fi
[ "$bad" -eq 0 ]
