#!/usr/bin/env bash
# What replication did NOT copy.
#
# Replication copies artifacts. It does not copy project settings,
# members, robot accounts, retention rules, immutability rules, quotas
# or scan results - and it carries a signature only if a filter happened
# to match it, which a tag filter does not, because a cosign signature's
# tag is derived from the digest it signs.
#
# This script compares the two ends on everything that is not an
# artifact, so that "the image is there" does not get mistaken for "the
# second site is equivalent".
#
#   HARBOR_PASS=... ./replication-gap.sh <source-project> <dest-project>
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API="$ROOT/scripts/harbor-api.sh"

SRC="${1:?source project}"
DST="${2:?destination project}"

get() { "$API" GET "$1" 2>/dev/null; }

row() { printf '  %-26s %-18s %s\n' "$1" "$2" "$3"; }

echo "comparing $SRC -> $DST"
echo
printf '  %-26s %-18s %s\n' WHAT "$SRC" "$DST"

count() { get "/projects/$1" | jq -r "${2}"; }

row "repositories" "$(count "$SRC" '.repo_count // 0')" \
                   "$(count "$DST" '.repo_count // 0')"
row "members" \
  "$(get "/projects/$SRC/members" | jq 'length // 0')" \
  "$(get "/projects/$DST/members" | jq 'length // 0')"
row "auto_scan" \
  "$(count "$SRC" '.metadata.auto_scan // "unset"')" \
  "$(count "$DST" '.metadata.auto_scan // "unset"')"
row "prevent_vul" \
  "$(count "$SRC" '.metadata.prevent_vul // "unset"')" \
  "$(count "$DST" '.metadata.prevent_vul // "unset"')"
row "cosign policy" \
  "$(count "$SRC" '.metadata.enable_content_trust_cosign // "unset"')" \
  "$(count "$DST" '.metadata.enable_content_trust_cosign // "unset"')"
row "quota hard" \
  "$(count "$SRC" '.quota.hard.storage // "-"')" \
  "$(count "$DST" '.quota.hard.storage // "-"')"
row "immutable rules" \
  "$(get "/projects/$SRC/immutabletagrules" | jq 'length // 0')" \
  "$(get "/projects/$DST/immutabletagrules" | jq 'length // 0')"

cat <<'TXT'

Only the artifacts crossed. Everything above is configuration, and
configuration is not replicated - which is the difference between a
mirror and a second registry.

For signatures, count the accessories rather than trusting the artifact
count, and then prove it:

  cosign verify --key cosign.pub <destination reference>

"no matching signatures" is a stronger answer than any count.
TXT
