#!/usr/bin/env bash
# Create a project robot with an explicit, minimal permission list.
#
#   ./make-robot.sh platform ci-push 30 pull push
#
# The secret is returned exactly once, by this call, and there is no
# endpoint that will tell you what it was. Capture it here or refresh it
# later. Chapter 19 puts it in Vault instead of in your clipboard.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API="$ROOT/scripts/harbor-api.sh"

NS="${1:?a project name}"
NAME="${2:?a robot name}"
DAYS="${3:-30}"
shift 3 || true
ACTIONS=("$@")
[ ${#ACTIONS[@]} -gt 0 ] || ACTIONS=(pull)

# push does not imply pull. A build that pulls a cache layer before it
# pushes needs both, and the failure appears at a step the robot is
# otherwise allowed to perform.
printf '%s\n' "${ACTIONS[@]}" | grep -qx push \
  && ! printf '%s\n' "${ACTIONS[@]}" | grep -qx pull \
  && echo "note: push without pull - see Chapter 6, step 5" >&2

access=$(printf '%s\n' "${ACTIONS[@]}" \
  | jq -R '{resource:"repository", action:.}' | jq -s .)

body=$(jq -n --arg n "$NAME" --arg ns "$NS" \
             --argjson d "$DAYS" --argjson a "$access" \
  '{name:$n, level:"project", duration:$d,
    permissions:[{kind:"project", namespace:$ns, access:$a}]}')

out=$("$API" POST /robots -d "$body")
name=$(printf '%s' "$out" | jq -r .name)
secret=$(printf '%s' "$out" | jq -r .secret)

[ "$name" != null ] || { printf '%s\n' "$out" >&2; exit 1; }

cat <<TXT
name    $name
secret  $secret
expires $(printf '%s' "$out" | jq -r '.expires_at')

Read the name back rather than assembling it: the robot\$ prefix is a
system setting and the separator is not something to guess.

  echo '$secret' | docker login \\
    ${HARBOR_URL:-https://harbor.meridian.test#} -u '$name' --password-stdin
TXT
