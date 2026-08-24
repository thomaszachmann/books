#!/usr/bin/env bash
# Was laeuft hier, und woher kommt es?
#
# Ein tag ist kein versprechen. Gemessen: derselbe tag :v1 wurde
# dreimal gepusht und hatte dreimal einen anderen digest. Zwei pods
# auf DEMSELBEN knoten, minuten auseinander, mit demselben tag:
#
#   IfNotPresent -> version 2 (aus dem cache)
#   Always       -> version 3 (aus der registry)
#
# Darum vergleicht dieses skript nicht die manifeste miteinander,
# sondern das MANIFEST mit dem, was der kubelet tatsaechlich
# gestartet hat - status.imageID ist immer ein digest.
#
#   ./image-provenance.sh
#   ./image-provenance.sh --csv > evidence/ch22/herkunft.csv
#   COSIGN_KEY=cosign.pub ./image-provenance.sh   prueft signaturen
set -uo pipefail

SUDO="${SUDO:-sudo}"
KC="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"
KB="${KB:-/var/lib/rancher/rke2/bin/kubectl}"
K="$SUDO env KUBECONFIG=$KC $KB"
COSIGN_KEY="${COSIGN_KEY:-}"
CSV=0; [ "${1:-}" = "--csv" ] && CSV=1

need() { command -v "$1" >/dev/null || { echo "fehlt: $1" >&2; exit 2; }; }
need jq

$K version --request-timeout=10s >/dev/null 2>&1 \
  || { echo "kein erreichbarer cluster ueber $KC" >&2; exit 1; }

# Ein datensatz je laufendem container: was gefordert wurde, was
# laeuft, und mit welcher pull-policy.
DATEN=$($K get pods -A -o json 2>/dev/null | jq -r '
  .items[] | .metadata.namespace as $ns | .metadata.name as $pod
  | (.spec.containers // []) as $spec
  | (.status.containerStatuses // [])[]
  | . as $st
  | ($spec[] | select(.name == $st.name)) as $c
  | [$ns, $pod, $c.name, $c.image,
     ($c.imagePullPolicy // "-"), ($st.imageID // "-")]
  | @tsv')

if [ "$CSV" = "1" ]; then
  echo "namespace,pod,container,gefordert,pullpolicy,laeuft"
  printf '%s\n' "$DATEN" | awk -F'\t' '{print "\""$1"\",\""$2"\",\""$3"\",\""$4"\",\""$5"\",\""$6"\""}'
  exit 0
fi

GESAMT=$(printf '%s\n' "$DATEN" | grep -c .)
PERDIG=$(printf '%s\n' "$DATEN" | awk -F'\t' '$4 ~ /@sha256:/' | grep -c .)
echo "== 1. wie wird referenziert? =="
echo "   container gesamt:  $GESAMT"
echo "   per digest:        $PERDIG"
echo "   per tag:           $((GESAMT - PERDIG))"
if [ "$PERDIG" -lt "$GESAMT" ]; then
  echo "   ^ ein tag sagt nicht, welcher inhalt laeuft. Was laeuft,"
  echo "     steht in status.imageID - und nur dort."
fi

echo
echo "== 2. woher kommen die images? =="
# Die registry ist der erste teil von SYS.1.6.A4. Wer hier mehr als
# eine zeile hat, hat mehr als eine lieferkette.
# Der erste pfadteil ist nur dann eine registry, wenn er einen
# punkt, einen doppelpunkt oder "localhost" enthaelt. Sonst ist es
# ein namespace auf docker.io, das nirgends im manifest steht.
printf '%s\n' "$DATEN" | awk -F'\t' '{
    n = split($4, p, "/")
    if (n > 1 && (p[1] ~ /[.:]/ || p[1] == "localhost")) print p[1]
    else print "docker.io (implizit)"
  }' | sort | uniq -c | sort -rn \
  | awk '{c=$1; $1=""; sub(/^ /,""); printf "   %-34s %s\n", $0, c}'

echo
echo "== 3. pull-policy =="
# IfNotPresent mit einem veraenderlichen tag heisst: der knoten
# behaelt, was er hat. Zwei knoten koennen denselben tag mit
# verschiedenem inhalt fahren, ohne dass irgendwo ein fehler steht.
printf '%s\n' "$DATEN" | awk -F'\t' '{print $5}' | sort | uniq -c \
  | awk '{printf "   %-18s %s\n", $2, $1}'
RISKANT=$(printf '%s\n' "$DATEN" \
  | awk -F'\t' '$4 !~ /@sha256:/ && $5 != "Always"' | grep -c .)
echo "   davon tag OHNE Always: $RISKANT"
[ "$RISKANT" -gt 0 ] && {
  echo "   ^ diese container koennen auf zwei knoten verschiedenen"
  echo "     inhalt fahren. Ein digest loest das, Always nicht ganz."
}

echo
echo "== 4. wird eine signatur verlangt? =="
IVP=$($K get imagevalidatingpolicy --no-headers 2>/dev/null | grep -c .)
echo "   ImageValidatingPolicies: $IVP"
if [ "$IVP" -gt 0 ]; then
  $K get imagevalidatingpolicy -o json 2>/dev/null | jq -r '
    .items[] | "   \(.metadata.name)  \(.spec.validationActions
      | join(","))  failurePolicy=\(.spec.failurePolicy // "Fail")"'
  echo
  echo "   ACHTUNG zur betriebsfolge: bei aktiver pruefung ist die"
  echo "   registry eine harte abhaengigkeit der pod-erzeugung."
  echo "   Gemessen mit angehaltener registry - auch ein image, das"
  echo "   auf dem knoten LIEGT, kann dann nicht gestartet werden:"
  echo "     denied: failed to evaluate policy: connection refused"
  echo "   Das trifft genau im vorfall, wenn knoten neu starten."
else
  echo "   ^ keine. Jedes image darf laufen, egal woher."
fi

# --- optional: signaturen tatsaechlich pruefen ----------------------
if [ -n "$COSIGN_KEY" ] && command -v cosign >/dev/null; then
  echo
  echo "== 5. signaturpruefung gegen $COSIGN_KEY =="
  printf '%s\n' "$DATEN" | awk -F'\t' '{print $6}' | grep '@sha256:' \
    | sort -u | head -20 | while read -r ref; do
      if cosign verify --key "$COSIGN_KEY" \
           ${COSIGN_INSECURE:+--allow-insecure-registry} \
           "$ref" >/dev/null 2>&1; then
        printf '   OK       %s\n' "$(echo "$ref" | cut -c1-58)"
      else
        printf '   KEINE    %s\n' "$(echo "$ref" | cut -c1-58)"
      fi
    done
  echo "   Geprueft wird status.imageID, nicht das manifest - also"
  echo "   das, was laeuft, und nicht das, was gemeint war."
fi
