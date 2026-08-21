#!/usr/bin/env bash
# Wait until node 1 answers. Sealed and uninitialised both count as up -
# /sys/health returns 501 and 503 for those, which is the answer we want.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
for _ in $(seq 60); do
  code=$(curl -sk -o /dev/null -w '%{http_code}' \
           https://127.0.0.1:8210/v1/sys/health 2>/dev/null || true)
  case "$code" in
    200|429|472|473|501|503) echo "vault-1 answers ($code)"; exit 0 ;;
  esac
  sleep 1
done
echo "vault-1 did not answer in 60 seconds" >&2
exit 1
