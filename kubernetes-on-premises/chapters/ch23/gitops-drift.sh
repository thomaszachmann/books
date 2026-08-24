#!/usr/bin/env bash
# Wer hat hier zuletzt angefasst - und durfte er das?
#
# GitOps verspricht, dass der cluster dem repository entspricht.
# Gemessen wurde: er tut es, aber traege und still.
#
#   von hand geaenderte configmap -> zurueckgesetzt nach 608s
#   geloeschtes objekt            -> wieder da nach 595s
#   im cluster protokolliert      -> NICHTS
#
# Zehn minuten sind das reconcile-intervall. Wer nicht warten will,
# fragt das objekt selbst: metadata.managedFields nennt den letzten
# schreiber. Bei flux ist das "kustomize-controller", bei einem
# menschen "kubectl-edit", "kubectl-create", "kubectl-patch".
#
# Der zweite teil ist unbequemer. Der controller haelt cluster-admin.
# Wer ins repository schreiben darf, hat damit dessen rechte - ohne
# den cluster je anzufassen und ohne im audit-log als mensch zu
# erscheinen.
#
#   ./gitops-drift.sh
#   ./gitops-drift.sh > evidence/ch23/drift.txt
set -uo pipefail

SUDO="${SUDO:-sudo}"
KC="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"
KB="${KB:-/var/lib/rancher/rke2/bin/kubectl}"
K="$SUDO env KUBECONFIG=$KC $KB"
# Manager-namen, die einen menschen an der tastatur bedeuten.
MENSCH="${MENSCH:-kubectl|helm|oc-|dashboard|lens}"
ARTEN="${ARTEN:-configmap,secret,deployment,service,serviceaccount,role,rolebinding}"

need() { command -v "$1" >/dev/null || { echo "fehlt: $1" >&2; exit 2; }; }
need jq

$K version --request-timeout=10s >/dev/null 2>&1 \
  || { echo "kein erreichbarer cluster ueber $KC" >&2; exit 1; }

echo "== 1. was wird ueberhaupt abgeglichen? =="
KS=$($K get kustomizations.kustomize.toolkit.fluxcd.io -A -o json 2>/dev/null)
if [ -z "$KS" ] || [ "$(echo "$KS" | jq -r '.items | length')" = "0" ]; then
  echo "   keine Flux-Kustomizations gefunden."
  echo "   ^ ohne abgleich ist jede aenderung am cluster endgueltig,"
  echo "     und die einzige quelle der wahrheit ist der cluster."
else
  echo "$KS" | jq -r '.items[] |
    "   \(.metadata.namespace)/\(.metadata.name)"
    + "  intervall=\(.spec.interval)"
    + "  prune=\(.spec.prune // false)"
    + "\n     stand: \(.status.lastAppliedRevision // "?")"'
  echo
  echo "   Das intervall ist die obergrenze, wie lange eine drift"
  echo "   bestehen bleibt. Gemessen: 608s bei intervall 10m."
fi

echo
echo "== 2. wer hat zuletzt geschrieben? =="
# Der schnelle drift-nachweis: jedes objekt, dessen letzter
# schreiber nach einem menschen aussieht.
NS=$($K get namespaces -o json 2>/dev/null \
  | jq -r '.items[].metadata.name' | grep -vE '^(kube-|cattle-)')
TREFFER=0
for ns in $NS; do
  ROH=$($K get $ARTEN -n "$ns" --show-managed-fields -o json 2>/dev/null)
  [ -z "$ROH" ] && continue
  AUSGABE=$(echo "$ROH" | jq -r --arg m "$MENSCH" '
    .items[]? | .kind as $k | .metadata.name as $n
    | .metadata.namespace as $ns
    | (.metadata.managedFields // [])
    | map(select(.manager | test($m)))
    | select(length > 0)
    | .[0] as $f
    | "   \($ns)/\($k)/\($n)  <- \($f.manager)  \($f.time // "")"')
  if [ -n "$AUSGABE" ]; then
    printf '%s\n' "$AUSGABE"
    TREFFER=$((TREFFER + $(printf '%s\n' "$AUSGABE" | grep -c .)))
  fi
done
if [ "$TREFFER" = "0" ]; then
  echo "   keine objekte mit menschlichem letztem schreiber"
else
  echo
  echo "   $TREFFER objekte wurden zuletzt von hand angefasst."
  echo "   Steht das objekt in git, wird die aenderung beim naechsten"
  echo "   abgleich verworfen - ohne meldung. Steht es NICHT in git,"
  echo "   bleibt es fuer immer und niemand weiss, warum es da ist."
fi

echo
echo "== 3. APP.4.4.A10: wie privilegiert ist der weg? =="
# Der abgleicher ist ein workload wie jeder andere - nur mit den
# rechten, alles zu aendern. Das ist der punkt der anforderung.
$K get clusterrolebindings -o json 2>/dev/null | jq -r '
  .items[] | select(.roleRef.name == "cluster-admin") | .roleRef.name as $r
  | .subjects[]? | select(.kind == "ServiceAccount")
  | "   \(.namespace)/\(.name) -> \($r)"' | sort -u
echo
echo "   Jede zeile ist ein konto, das alles darf. Fuer die zeilen"
echo "   aus flux-system gilt: wer in den ueberwachten branch"
echo "   schreiben darf, hat diese rechte mittelbar auch."

echo
echo "== 4. wie kommt die aenderung herein? =="
$K get gitrepositories.source.toolkit.fluxcd.io -A -o json 2>/dev/null | jq -r '
  .items[] |
  "   \(.metadata.namespace)/\(.metadata.name)"
  + "\n     url:    \(.spec.url)"
  + "\n     branch: \(.spec.ref.branch // .spec.ref.tag // "?")"
  + "\n     auth:   \(if .spec.secretRef then "secret/\(.spec.secretRef.name)" else "KEINE" end)"
  + "\n     verify: \(if .spec.verify then .spec.verify.mode else "KEINE signaturpruefung" end)"'
echo
echo "   Ohne verify werden commits nicht auf signaturen geprueft."
echo "   Dann ist die identitaet des autors eine behauptung im"
echo "   commit-header, die jeder setzen kann. Kapitel 22 hat"
echo "   dieselbe frage fuer images gestellt."

echo
echo "== 5. die zuschreibung, beide haelften =="
# Der cluster kennt den controller, git kennt den menschen. Nur
# ueber die revision lassen sich beide verbinden.
REV=$($K get kustomizations.kustomize.toolkit.fluxcd.io -A \
  -o jsonpath='{.items[0].status.lastAppliedRevision}' 2>/dev/null)
echo "   cluster sagt:  manager=kustomize-controller"
echo "   cluster sagt:  revision=${REV:-?}"
echo "   git sagt:      autor, zeitpunkt, begruendung, diff"
echo
echo "   Keine der beiden haelften beantwortet 'wer hat das getan'"
echo "   allein. Die revision ist das bindeglied - und sie gehoert"
echo "   deshalb in den nachweis, nicht nur ins log."
