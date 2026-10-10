#!/usr/bin/env bash
# Schickt N Requests an den Shop und zählt die Antworten pro Backend.
# Aufruf: measure.sh [N] [zusätzliche curl-Argumente ...]
set -uo pipefail
n="${1:-200}"; shift || true
GW_IP="${GW_IP:-$(gw-ip.sh)}"
CA="${CA:-$HOME/gw-lab/tag04/lab-ca.crt}"
for _ in $(seq "$n"); do
  body=$(curl -s --max-time 2 --cacert "$CA" \
    --resolve "shop.gw.localtest.me:443:$GW_IP" "$@" \
    https://shop.gw.localtest.me/)
  jq -er .service <<<"$body" 2>/dev/null || echo FEHLER
done | sort | uniq -c
