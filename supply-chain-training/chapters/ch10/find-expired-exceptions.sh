#!/usr/bin/env bash
# Findet abgelaufene oder unbefristete Kyverno-PolicyExceptions.
# Exit-Code 1, wenn etwas gefunden wurde (z. B. fuer CronJob-Alarm).
set -euo pipefail
NS="${NS:-policy-exceptions}"
TODAY=$(date -u +%F)

RESULT=$(kubectl get policyexceptions.kyverno.io -n "$NS" -o json \
  | jq -r --arg today "$TODAY" '
    .items[]
    | (.metadata.labels["seclab.example/expires"] // "") as $exp
    | "\(.metadata.namespace)/\(.metadata.name)" as $n
    | if $exp == "" then "OHNE-FRIST \($n)"
      elif $exp <= $today then "ABGELAUFEN \($n) (seit \($exp))"
      else empty end')

if [ -n "$RESULT" ]; then
  echo "$RESULT"
  exit 1
fi
echo "OK: keine abgelaufenen Ausnahmen in $NS (Stand $TODAY)"
