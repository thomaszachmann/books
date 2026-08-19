#!/usr/bin/env bash
# What does a tag actually serve?
#
# An index lists manifests with a platform each. Modern builds also
# attach attestation manifests - provenance and SBOM - which appear as
# children with platform.architecture "unknown". They are real artifacts
# and they occupy real space, so the child count is roughly twice the
# platform count and neither number is wrong.
#
#   ./index-children.sh platform multi 1.0
#   INDEX_JSON="$(cat fixture.json)" ./index-children.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

P="${1:-platform}"; R="${2:-multi}"; REF="${3:-1.0}"

json="${INDEX_JSON:-}"
if [ -z "$json" ]; then
  json=$("$ROOT/scripts/harbor-api.sh" GET \
    "/projects/$P/repositories/$R/artifacts/$REF")
fi

kind=$(printf '%s' "$json" | jq -r '.manifest_media_type')
echo "manifest media type  $kind"

case "$kind" in
  *index*|*manifest.list*) ;;
  *) echo
     echo "Not an index. One platform, no choice, and nothing recorded"
     echo "about which platform it was. This is what produces"
     echo "'exec format error' on a node of the other architecture."
     exit 0 ;;
esac

total=$(printf '%s' "$json" | jq '[.references[]?] | length')
plats=$(printf '%s' "$json" | jq '
  [.references[]? | select(.platform.architecture != "unknown")] | length')

echo "children             $total"
echo "of those, platforms  $plats"
echo "attestations         $(( total - plats ))"
echo
printf '%s' "$json" | jq -r '.references[]?
  | select(.platform.architecture != "unknown")
  | "  \(.platform.os)/\(.platform.architecture)\(.platform.variant // "")"'
