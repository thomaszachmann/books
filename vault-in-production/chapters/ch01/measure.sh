#!/usr/bin/env bash
# Chapter 1, Lab 1 - measure what depends on you.
#
# The value of these numbers is in the second reading, so the output is
# one line per run, appendable to a file you keep.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/vault-env.sh

# Captured before parsing: several of these commands exit non-zero for
# reasons that are not failures, and under pipefail that would append a
# second value to the one jq already printed.
raw_mounts=$(vault auth list -format=json 2>/dev/null || true)
raw_leases=$(vault list -format=json sys/leases/lookup/ 2>/dev/null || true)
mounts=$(printf '%s' "${raw_mounts:-{\}}" | jq 'length' 2>/dev/null || echo '?')
leases=$(printf '%s' "${raw_leases:-{\}}" | jq 'length' 2>/dev/null || echo 0)
size=$(du -sk cluster/data1 2>/dev/null | awk '{print $1}')

printf "%s  auth_mounts=%s  lease_prefixes=%s  node1_kb=%s\n" \
  "$(date -u '+%Y-%m-%dT%H:%MZ')" "${mounts:-?}" "${leases:-0}" "${size:-?}"

echo
echo "Consumers Vault does not know about - ranked by what actually ran:"
if [ -f logs/audit.log ]; then
  jq -r '.request.path' logs/audit.log 2>/dev/null \
    | sort | uniq -c | sort -rn | head -20
else
  echo "  no audit device. That is the first finding of this book:"
  echo "  you cannot answer any of the three questions without one."
fi
