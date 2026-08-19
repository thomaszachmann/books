#!/usr/bin/env bash
# Does this installation actually support the availability claim?
#
# The chart lets seven components scale - nginx, portal, core,
# jobservice, registry, trivy, exporter - and database and redis have no
# replicas field at all, because they are single instances by
# construction. So replicas without external state are decoration.
#
# This reads a running Helm release, or a values file, and reports the
# three things that are mandatory before "highly available" is a claim
# rather than a shape.
#
#   ./ha-readiness.sh                    # reads helm release "harbor"
#   ./ha-readiness.sh k8s/values-harbor.yaml
set -euo pipefail

SRC="${1:-}"
if [ -n "$SRC" ]; then
  [ -f "$SRC" ] || { echo "no such file: $SRC" >&2; exit 1; }
  VALUES=$(cat "$SRC")
  echo "reading $SRC"
else
  command -v helm >/dev/null || { echo "helm not found" >&2; exit 1; }
  VALUES=$(helm -n "${NS:-harbor}" get values "${RELEASE:-harbor}" -a 2>/dev/null) \
    || { echo "no helm release found; pass a values file instead" >&2; exit 1; }
  echo "reading helm release ${RELEASE:-harbor} in ${NS:-harbor}"
fi

val() { printf '%s' "$VALUES" | grep -E "^\s*$1:" | head -1 \
        | sed 's/.*: *//' | tr -d '"'"'"; }

db=$(printf '%s' "$VALUES" | awk '/^database:/{f=1} f&&/^  type:/{print $2; exit}')
rd=$(printf '%s' "$VALUES" | awk '/^redis:/{f=1} f&&/^  type:/{print $2; exit}')
st=$(printf '%s' "$VALUES" | awk '/imageChartStorage:/{f=1} f&&/type:/{print $2; exit}')

: "${db:=internal}"; : "${rd:=internal}"; : "${st:=filesystem}"

fail=0
chk() { # label, actual, bad-value, why
  if [ "$2" = "$3" ]; then
    printf '  NO   %-22s %-12s %s\n' "$1" "$2" "$4"; fail=1
  else
    printf '  yes  %-22s %-12s\n' "$1" "$2"
  fi
}

echo
printf '  %-4s %-22s %-12s %s\n' '' REQUIREMENT VALUE ''
chk "external database"  "$db" internal    "single instance, no replicas field"
chk "external redis"     "$rd" internal    "single instance, no replicas field"
chk "object storage"     "$st" filesystem  "one volume, one failure domain"

echo
reps=$(printf '%s' "$VALUES" | grep -cE '^\s+replicas: *[2-9]' || true)
echo "  components scaled above one replica: $reps"

echo
if [ "$fail" -eq 0 ]; then
  echo "The state is outside the installation. Replicas mean something."
else
  cat <<'TXT'
At least one piece of state is inside the installation. Adding replicas
does not make this highly available - it makes two front ends to one
point of failure, which is the most common thing people mean when they
say they have HA.

Move the state out first. Chapter 17.
TXT
fi
[ "$fail" -eq 0 ]
