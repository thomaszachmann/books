#!/usr/bin/env bash
# Segmentierung nachweisen, nicht behaupten.
#
# Eine liste von NetworkPolicies belegt nichts. Sie zeigt, was
# jemand aufgeschrieben hat - nicht, was das netz tut. Der nachweis
# fuer APP.4.4.A18 ist eine gemessene erreichbarkeitsmatrix.
#
# Drei dinge, die dieses skript deshalb nebeneinander stellt:
#
#   1. welche namespaces GAR KEINE policy haben (die luecke)
#   2. welche eine default-deny haben (die absicht)
#   3. wer wen tatsaechlich erreicht (die wirklichkeit)
#
# Punkt 3 braucht einen test-pod je namespace. Ohne --probe wird
# er uebersprungen und das skript berichtet nur 1 und 2 - was der
# uebliche, unzureichende bericht ist.
#
#   ./segmentation-check.sh            nur 1 und 2
#   ./segmentation-check.sh --probe    mit messung
set -uo pipefail

SUDO="${SUDO:-sudo}"
KC="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"
KB="${KB:-/var/lib/rancher/rke2/bin/kubectl}"
K="$SUDO env KUBECONFIG=$KC $KB"
PROBE=0; [ "${1:-}" = "--probe" ] && PROBE=1
# Rocky/RHEL setzen secure_path in sudoers - ohne vollen pfad
# findet sudo das kubectl aus /var/lib/rancher nicht.

need() { command -v "$1" >/dev/null || { echo "fehlt: $1" >&2; exit 2; }; }
need jq

$K version --request-timeout=10s >/dev/null 2>&1 \
  || { echo "kein erreichbarer cluster ueber $KC" >&2; exit 1; }

echo "== womit wird segmentiert? =="
CNI=$($K get pods -n kube-system -o json 2>/dev/null \
  | jq -r '[.items[].metadata.name] | map(select(test("cilium|canal|calico")))
           | if length==0 then "unbekannt" else .[0] end' \
  | sed 's/-[a-z0-9]*$//')
echo "   CNI:                 ${CNI:-unbekannt}"
L7=$($K api-resources 2>/dev/null | grep -c "ciliumnetworkpolicies")
IDS=$($K api-resources 2>/dev/null | grep -c "ciliumidentities")
echo "   L7-policies moeglich: $([ "$L7" -gt 0 ] && echo ja || echo nein)"
echo "   identitaeten sichtbar: $([ "$IDS" -gt 0 ] && echo ja || echo nein)"
if [ "$IDS" = "0" ]; then
  echo "   ^ ohne identitaeten haengen regeln an IP-adressen oder"
  echo "     an labels, die zur laufzeit zu IP-sets werden. Fuer"
  echo "     den nachweis heisst das: die matrix unten ist die"
  echo "     einzige aussage, die nicht altert."
fi

# --- host-firewall: der haeufigste stille stoerfaktor -------------
if systemctl is-active firewalld >/dev/null 2>&1; then
  echo
  echo "== firewalld laeuft =="
  TR=$($SUDO firewall-cmd --zone=trusted --list-sources 2>/dev/null)
  echo "   zone trusted, quellen: ${TR:-<keine>}"
  if [ -z "$TR" ]; then
    echo "   ^ ACHTUNG: ohne pod- und service-CIDR in der zone"
    echo "     trusted scheitern cluster-interne verbindungen mit"
    echo "     einem TIMEOUT, der wie ein policy-fehler aussieht."
    echo "     Nicht firewalld abschalten - die CIDRs eintragen."
  fi
fi

echo
echo "== policies je namespace =="
printf "   %-24s %-6s %-8s %s\n" NAMESPACE PODS POLICIES DEFAULT-DENY
$K get namespaces -o json 2>/dev/null | jq -r '.items[].metadata.name' \
| while read -r ns; do
  PODS=$($K get pods -n "$ns" --no-headers 2>/dev/null | grep -c .)
  [ "$PODS" = "0" ] && continue
  NP=$($K get networkpolicy -n "$ns" --no-headers 2>/dev/null | grep -c .)
  CNP=$($K get ciliumnetworkpolicy -n "$ns" --no-headers 2>/dev/null | grep -c .)
  TOT=$((NP + CNP))
  # Default-deny = eine policy mit leerem podSelector, die einen
  # policyType setzt aber keine passende erlaubnis-regel enthaelt.
  DD=$($K get networkpolicy -n "$ns" -o json 2>/dev/null | jq -r '
    [.items[] | select(.spec.podSelector == {})
     | select(((.spec.ingress // []) | length) == 0
           or ((.spec.egress  // []) | length) == 0)]
    | if length > 0 then "ja" else "nein" end')
  printf "   %-24s %-6s %-8s %s\n" "$ns" "$PODS" "$TOT" "${DD:-nein}"
done

echo
echo "   Namespaces mit pods und 0 policies sind die liste, die"
echo "   in den bericht gehoert. Alles andere ist absicht."

[ "$PROBE" = "0" ] && { echo; echo "   (ohne --probe keine messung)"; exit 0; }

# --- 3. die matrix --------------------------------------------------
# Gemessen wird aus den VORHANDENEN pods, nicht aus einem frisch
# gestarteten. Das ist keine bequemlichkeit, sondern der kern der
# sache: bei identitaetsbasierten regeln haengt die erlaubnis an
# den labels des absenders. Ein probe-pod mit eigenen labels hat
# eine andere identitaet und misst darum etwas anderes - meist
# "alles blockiert", was harmloser aussieht als die wirklichkeit.
echo
echo "== gemessene erreichbarkeit (aus den echten pods) =="
NSL=$($K get namespaces -o json 2>/dev/null | jq -r '.items[].metadata.name' \
      | grep -vE '^kube-|^cattle-')
SVCS=$(for ns in $NSL; do
  $K get svc -n "$ns" -o json 2>/dev/null | jq -r --arg ns "$ns" '
    .items[] | select(.spec.clusterIP != "None")
    | "\($ns)/\(.metadata.name):\(.spec.ports[0].port)"'
done)
[ -z "$SVCS" ] && { echo "   keine dienste zum messen"; exit 0; }

printf "   %-26s -> %-24s %s\n" "VON (pod)" NACH ERGEBNIS
for src in $NSL; do
  # Jeder laufende pod des namespace ist ein eigener absender mit
  # eigenen labels - darum alle durchgehen, nicht nur den ersten.
  $K get pods -n "$src" -o json 2>/dev/null | jq -r '
    .items[] | select(.status.phase=="Running") | .metadata.name' \
  | while read -r pod; do
    for tgt in $SVCS; do
      NST=${tgt%%/*}; REST=${tgt#*/}
      SVC=${REST%%:*}; PORT=${REST##*:}
      [ "$src" = "$NST" ] && continue
      URL="http://$SVC.$NST.svc.cluster.local:$PORT/"
      # curl bevorzugt, wget als rueckfall, sonst ist der pod
      # kein brauchbarer messpunkt und wird als solcher gemeldet.
      R=$($K exec -n "$src" "$pod" -- \
            curl -s -o /dev/null -m 5 -w '%{http_code}' "$URL" \
            2>/dev/null | tail -1)
      if [ -z "$R" ]; then
        $K exec -n "$src" "$pod" -- \
          wget -q -T 5 -O /dev/null "$URL" >/dev/null 2>&1 \
          && R=200 || R=""
      fi
      case "$R" in
        200|30*) V="ERREICHBAR ($R)" ;;
        403)     V="L7 ABGELEHNT (403)" ;;
        000)     V="BLOCKIERT (timeout)" ;;
        "")      V="kein messwerkzeug im pod" ;;
        *)       V="antwort $R" ;;
      esac
      printf "   %-26s -> %-24s %s\n" "$src/$pod" "$NST/$SVC:$PORT" "$V"
    done
  done
done

echo
echo "   Jede antwort - auch 400 oder 403 - heisst: die verbindung"
echo "   STAND. Nur der timeout ist eine blockade auf L3/L4."
echo "   Ein 400 gegen port 443 ist der normale fall, wenn man"
echo "   HTTP gegen einen TLS-port spricht: erreichbar."
echo
echo "   Die zeile, auf die es ankommt, ist meist"
echo "   <irgendein pod> -> default/kubernetes:443. Ist die"
echo "   erreichbar, kann jeder pod die API ansprechen, und die"
echo "   einzige verbliebene grenze ist RBAC (kapitel 17)."
