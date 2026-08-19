#!/usr/bin/env bash
# Every artifact in a project that carries no tag.
#
# Two very different groups end up in this list, and the difference is
# the whole point of running it:
#
#   children of an index   supposed to be untagged. Do not touch them.
#   former parents         what retention left behind. These are the
#                          question.
#
# A cleanup script that treats the list as one group deletes the
# platform-specific manifests out from under working images.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
P="${1:-platform}"

json="${ARTIFACTS_JSON:-}"
if [ -z "$json" ]; then
  json=$("$ROOT/scripts/harbor-api.sh" GET \
    "/projects/$P/artifacts?with_tag=true&page_size=100")
fi

# Every digest that some index claims as a child.
children=$(printf '%s' "$json" \
  | jq '[.[] | .references[]?.child_digest] | unique')

printf '%s' "$json" | jq -r --argjson kids "$children" '
  [ .[] | select((.tags // []) | length == 0) ] as $untagged
  | ( $untagged[] | select(.digest as $d | $kids | index($d))
      | "child       \(.repository_name)  \(.digest[0:19])" ),
    ( $untagged[] | select(.digest as $d | ($kids | index($d)) | not)
      | "ORPHAN      \(.repository_name)  \(.digest[0:19])" )'

echo
echo "child  = a platform or attestation manifest of an index. Leave it."
echo "ORPHAN = an artifact that lost its tags. This is the question."
