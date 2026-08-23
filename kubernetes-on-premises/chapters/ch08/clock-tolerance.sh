#!/usr/bin/env bash
# Wieviel Uhrabweichung uebersteht ein Cluster-Zertifikat?
#
# Die Antwort ist asymmetrisch, und zwar in die unerwartete
# Richtung: eine VORgehende uhr wird fast ein jahr lang toleriert,
# eine NACHgehende nur so lange, wie das zertifikat alt ist.
#
# Grund ist notBefore. "Noch nicht gueltig" ist so toedlich wie
# "abgelaufen", und ein knoten mit leerer RTC-batterie kommt
# nachgehend hoch, nie vorgehend.
#
#   ./clock-tolerance.sh                    gegen den kind-cluster
#   CRT=/etc/kubernetes/pki/apiserver.crt \
#   CA=/etc/kubernetes/pki/ca.crt ./clock-tolerance.sh   lokal
set -uo pipefail

NODE="${NODE:-ch08-control-plane}"
CRT="${CRT:-/etc/kubernetes/pki/apiserver.crt}"
CA="${CA:-/etc/kubernetes/pki/ca.crt}"
ENGINE="${ENGINE:-docker}"

if [ -r "$CRT" ]; then
  vfy() { openssl verify -CAfile "$CA" -attime "$1" "$CRT" 2>&1 | tail -1; }
  dates() { openssl x509 -in "$CRT" -noout -dates; }
else
  vfy() { $ENGINE exec "$NODE" openssl verify -CAfile "$CA" \
            -attime "$1" "$CRT" 2>&1 | tail -1; }
  dates() { $ENGINE exec "$NODE" openssl x509 -in "$CRT" -noout -dates; }
fi

NB="$(dates | awk -F= '/notBefore/{print $2}')"
NA="$(dates | awk -F= '/notAfter/{print $2}')"
NOW="$(date -u +%s)"
NBS="$(date -u -d "$NB" +%s 2>/dev/null || date -u -jf '%b %d %T %Y %Z' "$NB" +%s)"
AGE=$(( (NOW - NBS) / 60 ))

echo "  notBefore: $NB"
echo "  notAfter:  $NA"
echo "  Das Zertifikat ist $AGE Minuten alt."
echo

ok() { echo "$1" | grep -q ': OK' && echo OK || echo SCHEITERT; }

echo "== Uhr geht VOR =="
for s in 3600 86400 2592000; do
  printf '  +%-10s %s\n' "$(( s/3600 ))h" "$(ok "$(vfy $(( NOW + s )))")"
done

echo "== Uhr geht NACH =="
for m in 1 5 10 30 60; do
  printf '  -%-10s %s\n' "${m}min" "$(ok "$(vfy $(( NOW - m*60 )))")"
done

cat <<TXT

  Die Grenze nach unten liegt beim Alter des Zertifikats ($AGE min).
  Bei einem zertifikat, das waehrend des knoten-beitritts ausgestellt
  wird, sind das Sekunden - deshalb steht Zeit VOR dem Cluster.
TXT
