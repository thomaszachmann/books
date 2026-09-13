#!/usr/bin/env bash
# Level 1 of Appendix G: empty Harbor through its API and leave it
# running. Projects, repositories, robots, users, replication endpoints
# and policies, webhooks and retention go; the installation, admin and
# the library project stay. Disk is not reclaimed - that is garbage
# collection, and the appendix says how.
#
#   ./scripts/reset-content.sh          # asks first
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API="$ROOT/scripts/harbor-api.sh"
h() { "$API" "$@"; }
ids() { jq -r '.[] | .id // .project_id // .user_id'; }

cat <<TXT
This empties the Harbor at ${HARBOR_URL:-<HARBOR_URL unset>} through its API:
every project except library, every robot, every user except admin,
every registry endpoint, replication and webhook policy. It keeps Harbor
running. It does not free disk (run a garbage collection for that).

TXT
read -r -p "Type 'yes' to continue: " reply
[ "$reply" = "yes" ] || { echo "Nothing done."; exit 0; }

h PUT /configurations -d '{"read_only": false}' >/dev/null
echo "read_only off"

echo "replication policies"
h GET '/replication/policies?page_size=100' | ids | while read -r i; do
  h DELETE "/replication/policies/$i" >/dev/null; done
echo "robots"
"$ROOT/scripts/list-robots.sh" | ids | while read -r i; do
  h DELETE "/robots/$i" >/dev/null; done

echo "projects"
h GET '/projects?page_size=100' | jq -r '.[] | select(.name != "library") | .name' \
| while read -r p; do
  # a project deletes only when empty: repositories first, then webhooks
  h GET "/projects/$p/repositories?page_size=100" | jq -r '.[].name' \
  | while read -r r; do
      enc="${r#"$p/"}"; enc="${enc//\//%252F}"
      h DELETE "/projects/$p/repositories/$enc" >/dev/null || true
    done
  h GET "/projects/$p/webhook/policies" | ids | while read -r i; do
    h DELETE "/projects/$p/webhook/policies/$i" >/dev/null; done
  h DELETE "/projects/$p" -o /dev/null -w "  $p %{http_code}\n"
done

echo "registry endpoints"
h GET '/registries?page_size=100' | ids | while read -r i; do
  h DELETE "/registries/$i" >/dev/null || true; done
echo "users"
h GET '/users?page_size=100' | jq -r '.[] | select(.username != "admin") | .user_id' \
| while read -r i; do h DELETE "/users/$i" >/dev/null; done

echo "done. library and admin remain; run a garbage collection to free disk."
