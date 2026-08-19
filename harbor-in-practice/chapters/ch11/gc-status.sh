#!/usr/bin/env bash
# The last garbage collection: what it did, and what it refused.
#
# A GC log contains lines like
#
#   failed to delete untagged:1461 artifact in DB, error, ...
#   the deleting artifact is referenced by others
#
# Those are not failures to act on. Harbor refuses to delete an artifact
# that another artifact references, so the children of a multi-arch
# index survive delete_untagged - which defaults to true. The refusal is
# the protection working, and it is worth recognising before you read
# one at three in the morning.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API="$ROOT/scripts/harbor-api.sh"

log="${GC_LOG:-}"
if [ -z "$log" ]; then
  id=$("$API" GET /system/gc | jq -r '.[0].id')
  "$API" GET /system/gc | jq -r '.[0]
    | "id \(.id)  \(.job_status)  \(.job_kind)",
      "parameters \(.job_parameters)"'
  echo
  log=$("$API" GET "/system/gc/$id/log")
fi

refused=$(printf '%s' "$log" | grep -c 'referenced by others' || true)
freed=$(printf '%s' "$log" | grep -ci 'delete blob' || true)

echo "blobs deleted           $freed"
echo "artifacts refused       $refused   (referenced by an index)"
echo

if [ "$refused" -gt 0 ]; then
  cat <<'TXT'
The refusals are correct. delete_untagged is true by default and the
children of an index are untagged; Harbor declines to remove them
because something points at them. Nothing to do.
TXT
fi
