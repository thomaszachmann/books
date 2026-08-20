#!/usr/bin/env bash
# Thin wrapper over the Harbor API. Harbor has no official CLI; this is
# what Appendix C is a cookbook for.
#
#   HARBOR_URL=https://harbor.meridian.test \
#   HARBOR_USER=admin HARBOR_PASS=... \
#     ./scripts/harbor-api.sh GET /projects
#
# Anything after the path is passed to curl unchanged.
set -euo pipefail

URL="${HARBOR_URL:-https://harbor.meridian.test}"
USER="${HARBOR_USER:-admin}"
PASS="${HARBOR_PASS:-}"

if [ -z "$PASS" ]; then
  echo "Set HARBOR_PASS." >&2
  echo "Under OIDC that is the CLI secret, not the password;" >&2
  echo "under LDAP and db_auth it is the password. Chapter 7." >&2
  exit 2
fi

METHOD="${1:?method, for example GET}"
PATH_="${2:?path, for example /projects}"
shift 2

curl -sk -u "$USER:$PASS" \
  -X "$METHOD" \
  -H 'Content-Type: application/json' \
  "$URL/api/v2.0${PATH_}" \
  "$@"
