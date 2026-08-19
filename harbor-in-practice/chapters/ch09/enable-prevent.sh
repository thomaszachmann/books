#!/usr/bin/env bash
# Enable prevent_vul, in the order that does not cause an outage.
#
# Refuses to enable while unscanned artifacts exist, because that is the
# Friday-afternoon incident: the policy blocks anything without a
# report, and a registry that had scanning switched on last week is full
# of things pushed before that.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API="$ROOT/scripts/harbor-api.sh"

P="${1:?a project name}"
SEV="${2:-high}"

. "$HERE/severity.sh"
sev_code "$SEV" >/dev/null || exit 2

echo "== artifacts that would be refused"
if ! "$HERE/unscanned.sh" "$P"; then
  cat <<TXT

Not enabling. Scan these first:

  ./scripts/harbor-api.sh POST \\
    /projects/$P/repositories/<repo>/artifacts/<ref>/scan

or set auto_scan and re-push, or wait for the scan-all schedule.

Enabling the policy now refuses every one of them, and the error will
not mention vulnerabilities.
TXT
  exit 1
fi

echo
echo "== enabling prevent_vul at threshold $SEV"
"$API" PUT "/projects/$P" \
  -d "{\"metadata\":{\"prevent_vul\":\"true\",\"severity\":\"$SEV\"}}" \
  -o /dev/null -w 'PUT %{http_code}\n'

"$API" GET "/projects/$P" \
  | jq '{prevent_vul: .metadata.prevent_vul,
         severity: .metadata.severity}'

echo
echo "Threshold is inclusive: $SEV and higher are refused."
