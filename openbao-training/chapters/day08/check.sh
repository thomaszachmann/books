#!/usr/bin/env bash
# Tag 8, Kontrollpunkt - Befehle wörtlich aus dem Buch.
check() { if eval "$2" >/dev/null 2>&1; then echo "✔ $1"; else echo "✘ $1"; fi; }
check "3 Pods Running" \
  '[ "$(kubectl -n openbao get pods --field-selector=status.phase=Running \
     --no-headers | wc -l)" -eq 3 ]'
check "3 verschiedene Nodes" \
  '[ "$(kubectl -n openbao get pods -o jsonpath="{.items[*].spec.nodeName}" \
     | tr " " "\n" | sort -u | wc -l)" -eq 3 ]'
check "Services vorhanden" \
  'kubectl -n openbao get svc openbao openbao-active openbao-standby openbao-internal'
check "TLS-Secret gemountet" \
  'kubectl -n openbao exec openbao-0 -- ls /openbao/userconfig/openbao-tls/ca.crt'
check "openbao-0 sealed (Exit 2)" \
  '[ "$(kubectl -n openbao exec openbao-0 -- bao status >/dev/null; echo $?)" = 2 ]'
