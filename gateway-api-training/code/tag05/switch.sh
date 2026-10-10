#!/usr/bin/env bash
# Schaltet die Default-Regel der Route shop atomar auf blue (v1) oder green (v2).
# Aufruf: switch.sh blue|green
set -euo pipefail
case "${1:-}" in
  blue)  svc=shop-v1 ;;
  green) svc=shop-v2 ;;
  *) echo "Aufruf: $0 blue|green" >&2; exit 2 ;;
esac
kubectl -n shop patch httproute shop --type=json -p "[
  {\"op\":\"replace\",\"path\":\"/spec/rules/1/backendRefs/0/name\",\"value\":\"$svc\"}
]"
echo "live: $1 ($svc)"
