#!/usr/bin/env bash
# Vergleicht alten (ingress-nginx) und neuen Pfad (Envoy Gateway) für
# dieselben Requests: Statuscode, Pfad am Backend, X-Legacy-Header (Tag 13).
set -uo pipefail
H="${HOST:-legacy.apps.lab.internal}"
OLD="${OLD_IP:-10.10.20.110}"; NEW="${NEW_IP:-10.10.20.100}"
probe() {  # $1 = IP, $2 = Pfad
  local out
  out=$(curl -s -D - --resolve "$H:80:$1" "http://$H$2" --max-time 3)
  printf '%s|%s|%s' \
    "$(sed -n '1s/^HTTP[^ ]* \([0-9]*\).*/\1/p' <<<"$out")" \
    "$(sed -n '/^{/,$p' <<<"$out" | jq -r '.path // "-"' 2>/dev/null)" \
    "$(grep -ci '^x-legacy: true' <<<"$out")"
}
fail=0
for p in / /index.html /api/v1/orders /api/v1 /API/v1/orders /api/v10; do
  o=$(probe "$OLD" "$p"); n=$(probe "$NEW" "$p")
  if [ "$o" = "$n" ]; then echo "✔ $p  $o"; else echo "✘ $p  alt=$o neu=$n"; fail=1; fi
done
exit $fail
