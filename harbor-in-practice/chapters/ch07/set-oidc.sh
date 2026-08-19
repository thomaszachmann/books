#!/usr/bin/env bash
# Point Harbor at an OIDC provider.
#
# Every key here appears in config-keys.txt, which is extracted from the
# pinned swagger. The CI checks that, because a misspelled key can come
# back 200 with the setting never applied.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API="$ROOT/scripts/harbor-api.sh"

: "${OIDC_NAME:=meridian}"
: "${OIDC_ENDPOINT:?the issuer URL, reachable from harbor-core too}"
: "${OIDC_CLIENT_ID:=harbor}"
: "${OIDC_CLIENT_SECRET:?}"
: "${OIDC_GROUP_FILTER:=}"

body=$(jq -n \
  --arg name "$OIDC_NAME" --arg ep "$OIDC_ENDPOINT" \
  --arg id "$OIDC_CLIENT_ID" --arg sec "$OIDC_CLIENT_SECRET" \
  --arg gf "$OIDC_GROUP_FILTER" '{
    auth_mode: "oidc_auth",
    oidc_name: $name,
    oidc_endpoint: $ep,
    oidc_client_id: $id,
    oidc_client_secret: $sec,
    oidc_scope: "openid,profile,email,groups",
    oidc_user_claim: "preferred_username",
    oidc_groups_claim: "groups",
    oidc_group_filter: $gf,
    oidc_auto_onboard: true,
    oidc_verify_cert: true
  }')

code=$("$API" PUT /configurations -d "$body" -o /tmp/oidc.out -w '%{http_code}')
echo "PUT /configurations -> $code"
[ "$code" = 200 ] || { cat /tmp/oidc.out; exit 1; }

echo
echo "Read it back rather than trusting the 200:"
"$API" GET /configurations \
  | jq '{auth_mode:.auth_mode.value,
         oidc_endpoint:.oidc_endpoint.value,
         oidc_user_claim:.oidc_user_claim.value,
         oidc_groups_claim:.oidc_groups_claim.value,
         oidc_auto_onboard:.oidc_auto_onboard.value}'

cat <<'TXT'

oidc_user_claim must be immutable, not merely unique. An email address
changes when somebody's surname does; Harbor then sees a new username,
creates a second user with none of the first one's memberships, and the
person reports that they have lost access to everything.
TXT
