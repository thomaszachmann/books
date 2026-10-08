#!/usr/bin/env bash
ok() { echo "✔ $1"; }; nok() { echo "✘ $1"; }
bao audit list | grep -q '^datei/' && ok "Audit-Datei aktiv" || nok "Audit-Datei aktiv"
curl -sf --cacert "$BAO_CACERT" "$BAO_ADDR/v1/sys/metrics?format=prometheus" \
  | grep -q '^vault_core_unsealed' && ok "Metriken" || nok "Metriken"
[ "$(curl -s -o /dev/null -w '%{http_code}' --cacert "$BAO_CACERT" \
  "$BAO_ADDR/v1/sys/health")" = 200 ] && ok "Health aktiv" || nok "Health aktiv"
ls ~/bao-lab/tag12/*.snap >/dev/null 2>&1 \
  && ok "Snapshot vorhanden" || nok "Snapshot vorhanden"
bao operator raft autopilot state | grep -q 'Healthy: *true' \
  && ok "Raft gesund" || nok "Raft gesund"
[ "$(bao operator raft autopilot state -format=json \
  | jq -r '[.Servers[].Version] | unique | join(",")')" = 2.7.1 ] \
  && ok "Alle Nodes auf 2.7.1" || nok "Alle Nodes auf 2.7.1"
