#!/usr/bin/env bash
# Gibt die Adresse eines Gateways aus (status.addresses[0].value).
# Aufruf: gw-ip.sh [gateway] [namespace]   Default: web infra
set -euo pipefail
gw="${1:-web}"
ns="${2:-infra}"
ip=$(kubectl -n "$ns" get gateway "$gw" \
  -o jsonpath='{.status.addresses[0].value}' 2>/dev/null || true)
if [ -z "$ip" ]; then
  echo "Gateway $ns/$gw hat (noch) keine Adresse – läuft cloud-provider-kind?" >&2
  exit 1
fi
echo "$ip"
