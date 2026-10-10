#!/usr/bin/env bash
# Vergleicht das ausgelieferte Zertifikat mit dem Secret (Tag 12).
# Aufruf: cert-check.sh [host] [secret] [namespace]
set -euo pipefail
host="${1:-shop.apps.lab.internal}"; sec="${2:-apps-wildcard-tls}"
ns="${3:-infra}"; ip="${GW_IP:-10.10.20.100}"
served=$(openssl s_client -connect "$ip:443" -servername "$host" \
  </dev/null 2>/dev/null | openssl x509 -noout -serial -enddate)
stored=$(kubectl -n "$ns" get secret "$sec" -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -noout -serial -enddate)
echo "Envoy:  $(echo $served)"
echo "Secret: $(echo $stored)"
[ "$served" = "$stored" ] && echo "✔ Envoy liefert das aktuelle Zertifikat" \
  || echo "✘ Envoy liefert ein anderes Zertifikat"
