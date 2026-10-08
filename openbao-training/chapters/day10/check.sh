#!/usr/bin/env bash
# Tag 10, Kontrollpunkt - Befehle wörtlich aus dem Buch.
check() { if eval "$2" >/dev/null 2>&1; then echo "✔ $1"; else echo "✘ $1"; fi; }
check "Unsealer entsiegelt" \
  'kubectl -n unsealer exec bao-unsealer-0 -- bao status'
for p in openbao-0 openbao-1 openbao-2; do
  check "$p: transit + unsealed" \
    '[ "$(kubectl -n openbao exec '"$p"' -- bao status -format=json \
       | jq -r "[.type,.sealed]|join(\",\")")" = "transit,false" ]'
done
check "Keine Migration offen" \
  '[ "$(kubectl -n openbao exec openbao-0 -- bao status -format=json \
     | jq .migration)" = false ]'
check "Autopilot healthy" \
  '[ "$(bao operator raft autopilot state -format=json | jq .Healthy)" = true ]'
