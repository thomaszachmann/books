#!/usr/bin/env bash
# Jeder Trivy-Ignore braucht eine passende Ausnahme im Register.
set -euo pipefail
IGNORE="${1:-.trivyignore.yaml}"
REGISTER="${2:-exceptions.yaml}"

REPORT=$(jq -n -r \
  --argjson t "$(yq -o=json '.vulnerabilities // []' "$IGNORE")" \
  --argjson e "$(yq -o=json '.exceptions // []' "$REGISTER")" '
  ($e | map({key: .id, value: .}) | from_entries) as $byid
  | $t[]
  | . as $v
  | ($v.statement // "" | capture("(?<id>EXC-[0-9]{4}-[0-9]{3})").id // "")
      as $exc
  | $byid[$exc] as $x
  | if $x == null then
      "FEHLER \($v.id): keine passende Ausnahme im Register"
    elif ([$x.reference] + ($x.findings // []) | index($v.id)) == null then
      "FEHLER \($v.id): nicht in \($exc) aufgefuehrt"
    elif ($v.expired_at | tostring) != $x.expires then
      "FEHLER \($v.id): expired_at \($v.expired_at) passt nicht zu \($x.expires)"
    else
      "OK \($v.id) -> \($exc)"
    end
')

echo "$REPORT"
if grep -q '^FEHLER' <<<"$REPORT"; then exit 1; fi
