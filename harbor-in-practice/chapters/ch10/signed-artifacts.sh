#!/usr/bin/env bash
# Which artifacts carry a cosign signature, and which do not.
#
# This list is NOT "signed by us". Harbor records that an accessory of
# type signature.cosign exists; it does not verify it against any key,
# because there is no field in which to tell Harbor whose signatures are
# acceptable. An artifact signed with a key somebody generated thirty
# seconds ago appears here exactly like one signed by your pipeline.
#
# Producing the stronger list means running cosign verify against each
# artifact with a key you trust. That it cannot be answered from
# Harbor's API alone is the whole of Chapter 10.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
P="${1:-platform}"

json="${ARTIFACTS_JSON:-}"
if [ -z "$json" ]; then
  Q='with_accessory=true&page_size=100'
  json=$("$ROOT/scripts/harbor-api.sh" GET "/projects/$P/artifacts?$Q")
fi

printf '%s' "$json" | jq -r '
  [ .[] | select(.accessories != null)
        | .accessories[]
        | select(.type == "signature.cosign")
        | .subject_artifact_digest ] as $signed
  | .[]
  | select((.accessories // []) | map(.type == "signature.cosign")
           | any | not)
  | select(.digest as $d | ($signed | index($d)) | not)
  | "unsigned  \(.repository_name)  \(.digest[0:19])"'

printf '%s' "$json" | jq -r '
  .[] | select(.accessories != null) | .accessories[]
  | select(.type == "signature.cosign")
  | "signature \(.subject_artifact_repo)  subject \(.subject_artifact_digest[0:19])"'

cat <<'TXT'

"signature" means an accessory of that type exists. It does not mean the
signature is one you would accept. See Chapter 10, step 4.
TXT
