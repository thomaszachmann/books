#!/usr/bin/env bash
# Work out why the lab is misbehaving. Read-only: this script never
# changes anything, it only reports.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/versions.sh"

line() { printf '\n== %s\n' "$1"; }

line "tools"
"$ROOT/scripts/check-prereqs.sh" 2>&1 | sed 's/^/  /'

line "multipass"
if command -v multipass >/dev/null 2>&1; then
  multipass info "$VM_NAME" 2>&1 | sed 's/^/  /' | head -12
else
  echo "  multipass not installed"
fi

line "name resolution"
HOSTS=(harbor.meridian.test harbor-2.meridian.test)
for h in "${HOSTS[@]}"; do
  ip=$(getent hosts "$h" 2>/dev/null | awk '{print $1}')
  if [ -n "${ip:-}" ]; then
    echo "  $h -> $ip"
  else
    echo "  $h does NOT resolve"
  fi
done
echo "  (harbor-2 is only needed from Chapter 13, replication)"

line "harbor health"
curl -sk --max-time 5 https://harbor.meridian.test/api/v2.0/health \
  | jq -r '.components[]? | "  \(.name): \(.status)"' 2>/dev/null \
  || echo "  no answer on https://harbor.meridian.test"

line "docker trust"
if [ -f /etc/docker/daemon.json ]; then
  grep -q insecure-registries /etc/docker/daemon.json \
    && echo "  insecure-registries is set - Chapter 3 explains why" \
    && echo "  that is a workaround and not a fix" \
    || echo "  no insecure-registries. Good."
else
  echo "  no /etc/docker/daemon.json"
fi

line "kubernetes"
kubectl config current-context 2>/dev/null | sed 's/^/  context: /' \
  || echo "  no kubectl context"
kubectl get pods -n harbor 2>&1 | sed 's/^/  /' | head -14

echo
echo "Nothing was changed. See Appendix E for what these mean."
