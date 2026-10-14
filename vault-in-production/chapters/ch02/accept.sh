#!/usr/bin/env bash
# The seven conditions from Chapter 2, as a script instead of a meeting.
#
# Run in the lab directory, with the environment set:
#   . ./scripts/vault-env.sh && ./chapters/ch02/accept.sh
#
# Exits 0 when all seven pass. The lab in this book deliberately passes
# only five of them - see Chapter 2, Step 2.
set -uo pipefail

pass=0; fail=0
chk() {
  printf "  %-46s " "$1"
  if eval "$2" >/dev/null 2>&1; then
    echo "PASS"; pass=$((pass+1))
  else
    echo "FAIL"; fail=$((fail+1))
  fi
}

chk "storage is not in-memory" \
  '[ "$(vault status -format=json | jq -r .storage_type)" != "inmem" ]'
chk "more than one node" \
  '[ "$(vault operator raft list-peers -format=json \
        | jq ".data.config.servers|length")" -gt 1 ]'
chk "TLS in use" \
  'echo "${VAULT_ADDR:-}" | grep -q "^https"'
chk "at least one audit device" \
  '[ "$(vault audit list -format=json | jq "keys|length")" -ge 1 ]'
chk "initial root token revoked" \
  '! vault token lookup -format=json | jq -e ".data.policies|index(\"root\")"'
chk "a snapshot can be taken" \
  'vault operator raft snapshot save /tmp/accept-probe.snap'
chk "failure tolerance at least 1" \
  '[ "$(vault operator raft autopilot state -format=json \
        | jq .FailureTolerance)" -ge 1 ]'

rm -f /tmp/accept-probe.snap
echo "  ---"
echo "  $pass passed, $fail open"
[ "$fail" -eq 0 ]
