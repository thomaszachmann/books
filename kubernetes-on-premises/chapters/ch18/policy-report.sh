#!/usr/bin/env bash
# Der Policy-Report als nachweis - und die pruefung, ob er ueberhaupt
# etwas wert ist.
#
# Ein bericht allein belegt nichts. Er belegt nur dann etwas, wenn
# die durchsetzung waehrend des berichtszeitraums auch anlag. Genau
# das ist der teil, der still ausfaellt:
#
#   Kyverno LOESCHT seine eigenen webhooks, wenn der admission-
#   controller heruntergefahren wird - gemessen: nach 3 sekunden.
#   In diesem fenster wird alles zugelassen, ohne fehlermeldung,
#   auch bei failurePolicy: Fail.
#
# Darum berichtet dieses skript zwei dinge nebeneinander: was die
# regeln sagen, und ob die tuer zu war.
#
#   ./policy-report.sh                 lesbar
#   ./policy-report.sh --csv > evidence/ch18/policy-report.csv
set -uo pipefail

SUDO="${SUDO:-sudo}"
KC="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"
K="$SUDO env KUBECONFIG=$KC kubectl"
CSV=0; [ "${1:-}" = "--csv" ] && CSV=1

need() { command -v "$1" >/dev/null || { echo "fehlt: $1" >&2; exit 2; }; }
need kubectl; need jq

$K version --request-timeout=10s >/dev/null 2>&1 \
  || { echo "kein erreichbarer cluster" >&2; exit 1; }

# --- 1. stand der durchsetzung -------------------------------------
# Ohne diese zeilen ist der bericht darunter nicht belastbar.
WH=$($K get validatingwebhookconfigurations -o json 2>/dev/null \
     | jq '[.items[] | select(.metadata.name
           | test("kyverno-resource-validating"))] | length')
READY=$($K get deploy -n kyverno kyverno-admission-controller \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
READY="${READY:-0}"

if [ "$CSV" = "0" ]; then
  echo "== stand der durchsetzung =="
  echo "   admission-controller bereit: $READY"
  echo "   resource-webhook vorhanden:  $WH"
  if [ "$WH" = "0" ] || [ "$READY" = "0" ]; then
    echo "   ^ ACHTUNG: es wird gerade nichts abgefangen. Ein"
    echo "     bericht aus diesem zustand belegt keine kontrolle."
  fi
  echo
  echo "== policies und ihr modus =="
  $K get validatingpolicy -o json 2>/dev/null | jq -r '
    .items[] | "   \(.metadata.name)  \(.spec.validationActions
      | join(","))  failurePolicy=\(.spec.failurePolicy // "Fail")"'
  echo
fi

# --- 2. der bericht -------------------------------------------------
# Kyvernos autogen prueft auch die controller, nicht nur die pods.
# Die zahl der geprueften objekte liegt darum ueber der zahl der pods.
if [ "$CSV" = "1" ]; then
  echo "namespace,kind,name,policy,result"
  $K get policyreport -A -o json 2>/dev/null | jq -r '
    .items[] as $r | $r.results[]
    | [$r.metadata.namespace, $r.scope.kind, $r.scope.name,
       .policy, .result] | @csv'
else
  echo "== befunde je policy =="
  $K get policyreport -A -o json 2>/dev/null | jq -r '
    [.items[].results[]] | group_by(.policy)[]
    | "   \(.[0].policy): \(map(select(.result=="fail"))|length) fail,"
      + " \(map(select(.result=="pass"))|length) pass"'
  echo
  echo "== geprueft wurden =="
  $K get policyreport -A -o json 2>/dev/null | jq -r '
    [.items[].scope.kind] | group_by(.)[]
    | "   \(.[0]): \(length)"'
  echo
  echo "== objekte mit mindestens einem verstoss =="
  $K get policyreport -A -o json 2>/dev/null | jq -r '
    [.items[] | select([.results[] | select(.result=="fail")]
    | length > 0)] | "   \(length)"'
fi

# --- 3. was ein bericht NICHT sagt ----------------------------------
# Admission laeuft beim anlegen. Was schon laeuft, laeuft weiter -
# auch wenn die policy inzwischen auf Deny steht. Der abgleich
# zwischen "verletzt" und "laeuft" ist darum die eigentliche liste.
if [ "$CSV" = "0" ]; then
  echo
  echo "== laufende pods, die eine Deny-policy verletzen =="
  DENY=$($K get validatingpolicy -o json 2>/dev/null \
    | jq -r '.items[] | select(.spec.validationActions[]? == "Deny")
             | .metadata.name')
  if [ -z "$DENY" ]; then
    echo "   (keine policy steht auf Deny)"
  else
    for p in $DENY; do
      $K get policyreport -A -o json 2>/dev/null | jq -r --arg p "$p" '
        .items[] | select(.scope.kind=="Pod") as $r
        | $r.results[] | select(.policy==$p and .result=="fail")
        | "   \($r.metadata.namespace)/\($r.scope.name)  \($p)"'
    done
    echo "   ^ diese laufen trotz Deny. Admission ist eine tuer,"
    echo "     kein waechter - sie prueft beim anlegen, nicht danach."
  fi
fi
