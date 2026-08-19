#!/usr/bin/env bash
# Walk the role boundaries by hitting them. Prints the status code each
# role gets for each operation, so the table in the chapter can be
# checked against the running Harbor rather than believed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API="$ROOT/scripts/harbor-api.sh"
P="${PROJECT:-platform}"
REPO="${REPO:-util}"
TAG="${TAG:-1.0}"

probe() {   # user, method, path
  HARBOR_USER="$1" HARBOR_PASS="Lab-Passw0rd!$1" \
    "$API" "$2" "$3" -o /dev/null -w '%{http_code}'
}

printf '%-8s %-8s %-8s %-8s %-8s\n' user delete scan members logs
for u in alice bruno cleo dieter; do
  printf '%-8s %-8s %-8s %-8s %-8s\n' "$u" \
    "$(probe "$u" DELETE "/projects/$P/repositories/$REPO/artifacts/$TAG")" \
    "$(probe "$u" POST "/projects/$P/repositories/$REPO/artifacts/$TAG/scan")" \
    "$(probe "$u" GET "/projects/$P/members")" \
    "$(probe "$u" GET "/projects/$P/logs")"
done

cat <<'TXT'

403 is a refusal on role. 401 would mean Harbor does not know who you
are. 404 on a private project means you have no role on it at all, and
is deliberate: the existence of a project is not disclosed to somebody
who cannot see it.
TXT
