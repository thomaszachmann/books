#!/usr/bin/env bash
# Chapter 5, steps 1 and 2. Four users, one of each interesting role.
#
# Idempotent: re-running it reconciles roles rather than failing with
# 409, because you will run it again after breaking something.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API="$ROOT/scripts/harbor-api.sh"
PROJECT="${PROJECT:-platform}"

# username role_id
MEMBERS="ana:1 bruno:4 cleo:2 dieter:5"

for m in $MEMBERS; do
  u="${m%%:*}"; r="${m##*:}"
  "$API" POST /users \
    -d "{\"username\":\"$u\",\"email\":\"$u@meridian.test\",
         \"realname\":\"$u\",\"password\":\"Lab-Passw0rd!$u\"}" \
    -o /dev/null -w "user $u: %{http_code}\n" || true

  mid=$("$API" GET "/projects/$PROJECT/members" \
        | jq -r --arg u "$u" '.[] | select(.entity_name==$u) | .id')

  if [ -n "$mid" ]; then
    "$API" PUT "/projects/$PROJECT/members/$mid" \
      -d "{\"role_id\":$r}" -o /dev/null -w "  role -> $r: %{http_code}\n"
  else
    "$API" POST "/projects/$PROJECT/members" \
      -d "{\"role_id\":$r,\"member_user\":{\"username\":\"$u\"}}" \
      -o /dev/null -w "  role -> $r: %{http_code}\n"
  fi
done

echo
"$API" GET "/projects/$PROJECT/members" \
  | jq -r '.[] | "\(.entity_name)\t\(.role_name)"'
