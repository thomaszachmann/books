#!/usr/bin/env bash
# Lädt die offiziellen Envoy-Gateway-Dashboards (Chart gateway-addons-helm)
# und legt sie als ConfigMaps für den Grafana-Sidecar an (Tag 11).
set -euo pipefail
EG_VERSION="${EG_VERSION:-v1.9.2}"
base="https://raw.githubusercontent.com/envoyproxy/gateway/$EG_VERSION"
base="$base/charts/gateway-addons-helm/dashboards"
mkdir -p dashboards
for d in envoy-proxy-global envoy-clusters envoy-gateway-global \
         resources-monitor.gen; do
  curl -sfL -o "dashboards/$d.json" "$base/$d.json"
  echo "$d: $(jq -r .title "dashboards/$d.json")"
  cm="eg-dash-${d%.gen}"
  kubectl -n monitoring create configmap "$cm" \
    --from-file="dashboards/$d.json" --dry-run=client -o yaml \
    | kubectl label --local -f - grafana_dashboard=1 -o yaml \
    | kubectl apply -f -
done
