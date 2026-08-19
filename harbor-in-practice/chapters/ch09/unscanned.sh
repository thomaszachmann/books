#!/usr/bin/env bash
# Artifacts with no scan report. This is the list to clear BEFORE
# enabling prevent_vul anywhere.
#
# Under that policy an artifact with no report is refused - not
# permitted. A perfectly clean image nobody has looked at fails to pull,
# and the error does not mention vulnerabilities.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
P="${1:-platform}"

json="${ARTIFACTS_JSON:-}"
if [ -z "$json" ]; then
  Q='with_scan_overview=true&page_size=100'
  json=$("$ROOT/scripts/harbor-api.sh" GET "/projects/$P/artifacts?$Q")
fi

printf '%s' "$json" | jq -r '
  [ .[] | select(.scan_overview == null) ] as $none
  | ( $none[] | "no report   \(.repository_name)  \(.digest[0:19])" ),
    ( .[] | select(.scan_overview != null)
      | (.scan_overview | to_entries[0].value) as $o
      | select($o.scan_status != "Success")
      | "\($o.scan_status)     \(.repository_name)  \(.digest[0:19])" )'

n=$(printf '%s' "$json" | jq '[ .[]
  | select(.scan_overview == null
      or ((.scan_overview | to_entries[0].value.scan_status) != "Success")) ]
  | length')

echo
echo "$n artifact(s) would be refused under prevent_vul."
echo "Index children and attestation manifests are not scannable and"
echo "are skipped by the policy - they still appear here."
[ "$n" -eq 0 ]
