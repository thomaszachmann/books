#!/usr/bin/env sh
# Produce the Chapter 7 artifact: a dated baseline plus the context the
# report itself does not contain.
#
#   sudo ./scan.sh [profile]     default profile: bsi
#
# Writes into ../../evidence/ch07/. Changes nothing on the system - this
# evaluates, it does not remediate.
set -eu
export LC_ALL=C

PROFILE="${1:-bsi}"
DS=$(ls /usr/share/xml/scap/ssg/content/ssg-rl*-ds.xml 2>/dev/null | head -1)
[ -n "$DS" ] || { echo "no rl datastream found - see Chapter 4" >&2; exit 1; }

OUT=$(cd "$(dirname "$0")/../../" && pwd)/evidence/ch07
mkdir -p "$OUT"

echo "datastream: $DS"
oscap xccdf eval --profile "$PROFILE" \
  --results "$OUT/$PROFILE-baseline.xml" \
  --report  "$OUT/$PROFILE-baseline.html" \
  "$DS" > "$OUT/$PROFILE-baseline.txt" 2>/dev/null || true

{
  rpm -q scap-security-guide openscap-scanner
  cat /etc/redhat-release
  uname -r
  sha256sum "$DS"
  echo "profile: $PROFILE"
  echo "host: $(hostname -f 2>/dev/null || hostname)"
} > "$OUT/scan-context.txt"

echo "--- results ---"
awk '/^Result/ {print $2}' "$OUT/$PROFILE-baseline.txt" \
  | sort | uniq -c | sort -rn
echo "--- context ---"
cat "$OUT/scan-context.txt"
