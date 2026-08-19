#!/usr/bin/env bash
# Can auth_mode still be changed on this installation?
#
# Harbor permits the change only while no user other than the built-in
# admin exists. The refusal reads:
#
#   the auth mode cannot be modified as new users have been inserted
#   into database
#
# So this is a day-one decision. Run this before planning a migration
# to LDAP or OIDC, not during it.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API="$ROOT/scripts/harbor-api.sh"

json="${USERS_JSON:-$("$API" GET '/users?page_size=100')}"
count=$(printf '%s' "$json" | jq 'length')
mode=$("$API" GET /configurations | jq -r '.auth_mode.value' 2>/dev/null || echo '?')

echo "auth_mode  $mode"
echo "users      $count   (the built-in admin is not listed)"
echo

if [ "$count" -eq 0 ]; then
  echo "auth_mode CAN still be changed."
  exit 0
fi

cat <<TXT
auth_mode CANNOT be changed. These users would have to go first, and
their project memberships go with them:

TXT
printf '%s' "$json" | jq -r '.[] | "  \(.username)"'
cat <<'TXT'

Export the membership map before deleting anything:

  ./scripts/harbor-api.sh GET /projects \
    | jq -r '.[].name' \
    | while read -r p; do
        ./scripts/harbor-api.sh GET "/projects/$p/members" \
          | jq -r --arg p "$p" '.[] | "\($p)\t\(.entity_name)\t\(.role_name)"'
      done
TXT
exit 1
