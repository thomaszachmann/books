#!/usr/bin/env bash
# Tag 7, Kontrollpunkt - Befehle wörtlich aus dem Buch.
cd ~/bao-lab/tls
check() { if eval "$2" >/dev/null 2>&1; then echo "✔ $1"; else echo "✘ $1"; fi; }
check "Kontext kind-bao-lab" '[ "$(kubectl config current-context)" = kind-bao-lab ]'
check "3 Worker Ready" \
  '[ "$(kubectl get nodes --no-headers | grep -c "worker.*Ready")" -eq 3 ]'
check "Zertifikat von CA signiert" 'openssl verify -CAfile ca.crt tls.crt'
check "SAN openbao-2.openbao-internal" \
  'openssl verify -CAfile ca.crt -verify_hostname openbao-2.openbao-internal tls.crt'
check "Secret openbao-tls mit 3 Keys" \
  '[ "$(kubectl -n openbao get secret openbao-tls -o json | jq ".data|length")" -eq 3 ]'
