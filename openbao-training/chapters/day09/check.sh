#!/usr/bin/env bash
# Tag 9, Kontrollpunkt - Befehle wörtlich aus dem Buch.
check() { if eval "$2" >/dev/null 2>&1; then echo "✔ $1"; else echo "✘ $1"; fi; }
check "3 Pods Ready" \
  '[ "$(kubectl -n openbao get pods --no-headers | grep -c " 1/1 ")" -eq 3 ]'
check "genau 1 Active" \
  '[ "$(kubectl -n openbao get pods -l openbao-active=true --no-headers | wc -l)" -eq 1 ]'
check "3 Voter" \
  '[ "$(bao operator raft list-peers -format=json \
     | jq "[.data.config.servers[]|select(.voter)]|length")" -eq 3 ]'
check "Autopilot healthy" \
  '[ "$(bao operator raft autopilot state -format=json | jq .Healthy)" = true ]'
check "Testdaten lesbar" 'bao kv get secret/failover-test'
