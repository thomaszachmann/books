#!/usr/bin/env bash
# Wo liegen die geheimnisse wirklich?
#
# Die uebliche antwort - "wir haben verschluesselung at rest" -
# beantwortet drei fragen nicht, und alle drei sind messbar:
#
#   1. WAS ist verschluesselt? Die vorgabe deckt nur "secrets".
#      ConfigMaps liegen im klartext in etcd. Gemessen: eine
#      configmap war in der snapshot-datei UND im write-ahead-log
#      zu finden - und nach dem loeschen immer noch in beiden.
#
#   2. WO liegt der schluessel? Auf derselben platte wie etcd.
#      Gegen einen gestohlenen datentraeger hilft das, gegen
#      einen kompromittierten knoten nicht.
#
#   3. WER darf lesen? Verschluesselung at rest ist keine
#      zugriffskontrolle. Die API gibt klartext heraus.
#
#   ./secret-exposure.sh
#   ./secret-exposure.sh --marker GEHEIM-123   sucht eine markierung
set -uo pipefail

SUDO="${SUDO:-sudo}"
KC="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"
KB="${KB:-/var/lib/rancher/rke2/bin/kubectl}"
K="$SUDO env KUBECONFIG=$KC $KB"
DB="${DB:-/var/lib/rancher/rke2/server/db}"
CFG="${CFG:-/var/lib/rancher/rke2/server/cred/encryption-config.json}"
MARKER=""
[ "${1:-}" = "--marker" ] && MARKER="${2:-}"

need() { command -v "$1" >/dev/null || { echo "fehlt: $1" >&2; exit 2; }; }
need jq

echo "== 1. was ist ueberhaupt verschluesselt? =="
if $SUDO test -f "$CFG"; then
  $SUDO cat "$CFG" | jq -r '
    .resources[] |
    "   ressourcen: \(.resources | join(", "))\n   provider:   "
    + (.providers | map(keys[0]) | join(" -> "))'
  FIRST=$($SUDO cat "$CFG" | jq -r '.resources[0].providers[0] | keys[0]')
  if [ "$FIRST" = "identity" ]; then
    echo "   ^ identity steht VORNE: es wird nichts verschluesselt."
  fi
  COVERS=$($SUDO cat "$CFG" | jq -r '[.resources[].resources[]] | join(" ")')
  case "$COVERS" in
    *configmaps*) ;;
    *) echo "   ^ ConfigMaps sind NICHT dabei - deren inhalt liegt"
       echo "     im klartext in etcd und in jedem backup." ;;
  esac
else
  echo "   keine encryption-config unter $CFG"
  echo "   ^ ohne sie liegt ALLES im klartext in etcd."
fi

echo
echo "== 2. wo liegt der schluessel? =="
if $SUDO test -f "$CFG"; then
  echo "   datei:  $CFG"
  $SUDO ls -l "$CFG" | awk '{print "   rechte: "$1" "$3":"$4}'
  # Derselbe datentraeger wie etcd? Dann schuetzt die
  # verschluesselung nur gegen den verlust des datentraegers.
  A=$($SUDO df --output=source "$CFG" 2>/dev/null | tail -1)
  B=$($SUDO df --output=source "$DB" 2>/dev/null | tail -1)
  echo "   dateisystem schluessel: ${A:-?}"
  echo "   dateisystem etcd:       ${B:-?}"
  if [ -n "$A" ] && [ "$A" = "$B" ]; then
    echo "   ^ dasselbe. Wer die etcd-dateien hat, hat den"
    echo "     schluessel auch. Geschuetzt ist damit der"
    echo "     gestohlene datentraeger, nicht der knoten."
  fi
fi

echo
echo "== 3. was steht im klartext in etcd? =="
# ConfigMaps mit verdaechtigen schluesselnamen sind der haeufigste
# fund. Gesucht wird im NAMEN, nicht im wert - der wert gehoert
# nicht in eine ausgabe, die in die nachweismappe wandert.
echo "   ConfigMaps mit verdaechtigen feldnamen:"
$K get configmap -A -o json 2>/dev/null | jq -r '
  .items[] | .metadata.namespace as $ns | .metadata.name as $n
  | (.data // {}) | keys[]
  | select(test("(?i)pass|secret|token|key|credential|pwd"))
  | "     \($ns)/\($n)  feld: \(.)"' | head -20
$K get configmap -A -o json 2>/dev/null | jq -r '
  [.items[] | (.data // {}) | keys[]
   | select(test("(?i)pass|secret|token|key|credential|pwd"))]
  | if length == 0 then "     (keine)" else "     -> \(length) treffer" end'

if [ -n "$MARKER" ]; then
  echo
  echo "   suche nach der markierung \"$MARKER\" in den etcd-dateien:"
  HITS=$($SUDO grep -rl "$MARKER" "$DB" 2>/dev/null)
  if [ -z "$HITS" ]; then
    echo "     nicht gefunden - verschluesselt oder nie gespeichert"
  else
    printf '     %s\n' $HITS
    echo "     ^ im klartext auf der platte. Auch das write-ahead-log"
    echo "       zaehlt: dort bleibt es nach dem loeschen stehen."
  fi
fi

echo
echo "== 4. wer darf die secrets lesen? =="
# Verschluesselung at rest aendert daran nichts - die API liefert
# klartext an jeden, der get secrets darf.
echo "   secrets gesamt: $($K get secrets -A --no-headers 2>/dev/null | grep -c .)"
echo "   rollen mit lesezugriff auf secrets:"
$K get clusterroles -o json 2>/dev/null | jq -r '
  .items[] | select([.rules[]?
    | select((.resources // []) | index("secrets"))
    | select((.verbs // []) | (index("get") or index("list")
             or index("*")))] | length > 0)
  | "     \(.metadata.name)"' | grep -vE "system:(controller|kube-)" \
  | head -10
echo
echo "   Eine rolle mit list auf secrets in einem namespace liest"
echo "   JEDES secret dieses namespace - auch die, die zu einem"
echo "   anderen workload gehoeren. Kapitel 20 zeigt, warum der"
echo "   namespace dabei die einzige grenze ist."
