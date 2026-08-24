#!/usr/bin/env bash
# Was trennt die mandanten wirklich, und was nur auf dem papier?
#
# Die frage ist nicht, ob RBAC richtig gesetzt ist - das ist es
# meistens. Die frage ist, was TROTZ korrektem RBAC hinueberreicht.
# Gemessen auf einem cluster mit sauber gesetzten namespace-admins:
#
#   Ein mandant mit ausschliesslich rechten im EIGENEN namespace
#   hat alle vier pods des anderen mandanten verdraengt - per
#   priorityClassName: system-cluster-critical. RBAC war korrekt,
#   PSS stand auf restricted, netzwerk-policies lagen an.
#
# Darum prueft dieses skript nicht die rollen, sondern die vier
# stellen, an denen ein namespace keine grenze ist.
#
#   ./tenancy-check.sh
#   ./tenancy-check.sh > evidence/ch20/mandantentrennung.txt
set -uo pipefail

SUDO="${SUDO:-sudo}"
KC="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"
KB="${KB:-/var/lib/rancher/rke2/bin/kubectl}"
K="$SUDO env KUBECONFIG=$KC $KB"
# Namespaces der plattform selbst sind keine mandanten.
SKIP="${SKIP:-^(kube-|cattle-|default$|local-path|longhorn|cilium)}"

need() { command -v "$1" >/dev/null || { echo "fehlt: $1" >&2; exit 2; }; }
need jq

$K version --request-timeout=10s >/dev/null 2>&1 \
  || { echo "kein erreichbarer cluster ueber $KC" >&2; exit 1; }

MANDANTEN=$($K get namespaces -o json 2>/dev/null \
  | jq -r '.items[].metadata.name' | grep -vE "$SKIP")

echo "== 1. wer kann wen verdraengen? =="
# Der weg, den niemand sperrt: eine system-prioritaet im pod-spec.
# Dagegen hilft nur eine ResourceQuota mit scopeSelector auf
# PriorityClass - eine normale CPU-quota greift zu spaet und nur,
# wenn der angreifer auch viel CPU anfordert.
PCS=$($K get priorityclass -o json 2>/dev/null \
  | jq -r '.items[] | select(.value > 100000) | .metadata.name')
echo "   hochwertige priorityclasses im cluster:"
for p in $PCS; do
  V=$($K get priorityclass "$p" -o jsonpath='{.value}' 2>/dev/null)
  echo "     $p ($V)"
done
echo
printf "   %-22s %-10s %s\n" NAMESPACE QUOTA "SYSTEM-PRIO GESPERRT"
for ns in $MANDANTEN; do
  Q=$($K get resourcequota -n "$ns" --no-headers 2>/dev/null | grep -c .)
  # Sperre = eine quota, die auf PriorityClass eingeschraenkt ist
  # und pods auf 0 setzt.
  BLOCK=$($K get resourcequota -n "$ns" -o json 2>/dev/null | jq -r '
    [.items[] | select(.spec.scopeSelector.matchExpressions[]?
       | .scopeName == "PriorityClass")
     | select((.spec.hard.pods // "1") == "0")] | length')
  printf "   %-22s %-10s %s\n" "$ns" "$Q" \
    "$([ "${BLOCK:-0}" -gt 0 ] && echo ja || echo NEIN)"
done
echo
echo "   NEIN in der letzten spalte heisst: dieser namespace kann"
echo "   die last jedes anderen namespace vom knoten werfen."

echo
echo "== 2. wie viel der API ist ueberhaupt trennbar? =="
NSC=$($K api-resources --namespaced=true  --no-headers 2>/dev/null | grep -c .)
CLS=$($K api-resources --namespaced=false --no-headers 2>/dev/null | grep -c .)
echo "   namespaced:     $NSC arten"
echo "   cluster-weit:   $CLS arten"
[ $((NSC+CLS)) -gt 0 ] && echo "   -> $(( CLS * 100 / (NSC+CLS) ))% ist fuer alle mandanten dasselbe"
echo "   CRDs:           $($K get crd --no-headers 2>/dev/null | grep -c .) (je eine gespeicherte version fuer alle)"

echo
echo "== 3. wer haelt cluster-weite rechte? =="
# Cluster-weite rechte sind der zweite weg ueber die grenze und
# der einzige, den ein audit ueblicherweise anschaut.
$K get clusterrolebindings -o json 2>/dev/null | jq -r '
  .items[] | select(.roleRef.name | test("^(cluster-admin|admin|edit)$"))
  | .metadata.name as $n | .subjects[]?
  | select(.kind == "ServiceAccount")
  | "   \(.namespace)/\(.name) -> \($n)"' \
  | grep -vE "^ +(kube-|cattle-)" | sort -u | head -12 \
  | grep . || echo "   keine ausserhalb der plattform-namespaces"
echo "   (dienstkonten aus kube-* und cattle-* sind ausgeblendet)"

echo
echo "== 4. was gar nicht trennbar ist =="
NODES=$($K get nodes --no-headers 2>/dev/null | grep -c .)
echo "   knoten im cluster: $NODES"
printf "   %-22s %s\n" NAMESPACE "KNOTEN MIT ANDEREN MANDANTEN"
for ns in $MANDANTEN; do
  MINE=$($K get pods -n "$ns" -o json 2>/dev/null \
    | jq -r '.items[].spec.nodeName' | sort -u)
  [ -z "$MINE" ] && continue
  SHARED=0
  for n in $MINE; do
    OTHERS=$($K get pods -A -o json 2>/dev/null | jq -r --arg n "$n" --arg ns "$ns" '
      [.items[] | select(.spec.nodeName == $n)
       | select(.metadata.namespace != $ns)
       | .metadata.namespace] | unique | length')
    [ "${OTHERS:-0}" -gt 0 ] && SHARED=$((SHARED+1))
  done
  printf "   %-22s %s\n" "$ns" "$SHARED"
done
echo
echo "   Geteilte knoten heissen geteilter kernel. Ein ausbruch"
echo "   aus einem container ist ein ausbruch in alle namespaces"
echo "   dieses knotens - dagegen hilft keine quota und keine"
echo "   policy, sondern nur ein eigener knoten oder ein eigener"
echo "   cluster. Das ist die grenze zwischen weicher und harter"
echo "   trennung, und sie gehoert in die entscheidung, nicht in"
echo "   den betrieb."
