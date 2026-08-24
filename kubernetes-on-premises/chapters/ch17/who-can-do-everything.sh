#!/usr/bin/env bash
# Wer darf in diesem cluster alles, und wuerde man es hinterher sehen?
#
# Das skript beantwortet die drei fragen, die ein pruefer stellt:
#   1. Wer sind die administratoren?      -> abschnitt 1 und 2
#   2. Kann man einem den zugang nehmen?  -> abschnitt 3
#   3. Sieht man, wer was getan hat?      -> abschnitt 4
#
# Der grund fuer das skript ist, dass die drei antworten bei einem
# frisch installierten cluster lauten: eine kennung, die jeder
# benutzt; nein; und nein.
#
# Nichts davon veraendert den cluster. Der nachweis in abschnitt 2
# laeuft ueber impersonation (--as), nicht ueber das loeschen der
# bindung - das ergebnis ist dasselbe und man kann es im betrieb
# ausfuehren.
#
#   ./who-can-do-everything.sh
#   ./who-can-do-everything.sh > evidence/ch17/identitaet.txt
set -uo pipefail

KC="${KUBECONFIG:-/etc/rancher/rke2/rke2.yaml}"
AUDIT="${AUDIT:-/var/lib/rancher/rke2/server/logs/audit.log}"
POLICY="${POLICY:-/etc/rancher/rke2/audit-policy.yaml}"
SUDO="${SUDO:-sudo}"
WAIT="${WAIT:-60}"          # sekunden fuer die wachstumsmessung
K="$SUDO env KUBECONFIG=$KC kubectl"

need() { command -v "$1" >/dev/null || { echo "fehlt: $1" >&2; exit 2; }; }
need kubectl; need openssl

$K version --request-timeout=10s >/dev/null 2>&1 \
  || { echo "kein erreichbarer cluster ueber $KC" >&2; exit 1; }

echo "== 1. die kennung, mit der man gerade arbeitet =="
$K auth whoami 2>/dev/null | sed 's/^/   /' \
  || echo "   (auth whoami braucht k8s 1.28+)"

# Das mitgelieferte kubeconfig traegt ein client-zertifikat. Subject
# und laufzeit sind die eigentliche antwort auf "wer bin ich".
CRT=$($SUDO grep -m1 client-certificate-data "$KC" 2>/dev/null \
      | awk '{print $2}' | base64 -d 2>/dev/null)
if [ -n "$CRT" ]; then
  SUB=$(printf '%s' "$CRT" | openssl x509 -noout -subject 2>/dev/null)
  NA=$(printf '%s' "$CRT" | openssl x509 -noout -enddate 2>/dev/null \
       | cut -d= -f2)
  echo "   zertifikat $SUB"
  echo "   gueltig bis $NA"
  END=$(date -d "$NA" +%s 2>/dev/null) && NOW=$(date +%s) \
    && echo "   das sind noch $(( (END-NOW)/86400 )) tage"

  # Kapitel 16: ohne diese erweiterungen gibt es keinen widerruf.
  EXT=$(printf '%s' "$CRT" | openssl x509 -noout -text 2>/dev/null \
        | grep -ciE 'CRL Distribution|Authority Information Access')
  echo "   widerrufs-erweiterungen: $EXT"
  [ "$EXT" = "0" ] && echo "   ^ null heisst: dieser zugang ist nicht" \
    && echo "     entziehbar, solange die CA dieselbe bleibt."
fi

echo
echo "== 2. gilt fuer diese kennung ueberhaupt RBAC? =="
# system:masters ist im apiserver fest verdrahtet und wird VOR RBAC
# ausgewertet. Der beweis per impersonation: ein frei erfundener
# benutzer darf nichts - derselbe benutzer in dieser gruppe darf alles.
FREMD="niemand-$$"
A=$($K auth can-i '*' '*' --all-namespaces \
      --as="$FREMD" 2>/dev/null)
B=$($K auth can-i '*' '*' --all-namespaces \
      --as="$FREMD" --as-group=system:masters 2>/dev/null)
echo "   $FREMD                        darf alles: ${A:-nein}"
echo "   $FREMD + system:masters       darf alles: ${B:-nein}"
if [ "$B" = "yes" ]; then
  echo "   ^ die gruppe genuegt. Kein rolebinding noetig, und"
  echo "     keines kann es zuruecknehmen: RBAC wird uebersprungen."
fi

echo
echo "== 3. wer haelt sonst noch cluster-admin? =="
ALL=$($K get clusterrolebindings -o json 2>/dev/null \
  | jq -r '.items[]
      | select(.roleRef.name=="cluster-admin")
      | .subjects[]? | "\(.kind)/\(.namespace // "-")/\(.name)"' \
  2>/dev/null | sort -u)
N=$(printf '%s\n' "$ALL" | grep -c . )
SA=$(printf '%s\n' "$ALL" | grep -c '^ServiceAccount/' )
echo "   $N traeger, davon $SA dienstkonten"
printf '%s\n' "$ALL" | sed 's/^/     /'
echo "   Dienstkonten sind hier nicht der befund - die gehoeren zur"
echo "   distribution. Der befund ist, ob ein MENSCH darunter ist."

echo
echo "== 4. wuerde man es hinterher sehen? =="
LVL=$($SUDO grep -c 'level: None' "$POLICY" 2>/dev/null || echo 0)
RULES=$($SUDO grep -c '^\s*-\s*level:' "$POLICY" 2>/dev/null || echo 0)
echo "   audit-policy: $RULES regeln, davon $LVL auf 'None'"
if [ "$RULES" != "0" ] && [ "$RULES" = "$LVL" ]; then
  echo "   ^ JEDE regel ist None. Der flag ist gesetzt, die pruefung"
  echo "     gilt als erfuellt, und aufgezeichnet wird nichts."
fi

if $SUDO test -f "$AUDIT"; then
  S1=$($SUDO stat -c %s "$AUDIT" 2>/dev/null || echo 0)
  echo "   audit.log: $S1 bytes"
  echo "   ... messe $WAIT sekunden wachstum"
  sleep "$WAIT"
  S2=$($SUDO stat -c %s "$AUDIT" 2>/dev/null || echo 0)
  D=$((S2-S1))
  echo "   +$D bytes in ${WAIT}s"
  if [ "$D" -gt 0 ]; then
    PT=$(( D * 86400 / WAIT / 1024 / 1024 ))
    echo "   das sind rund $PT MB pro tag im leerlauf"
    # rke2-vorgabe: maxsize 100 MB, maxbackup 10 -> 1100 MB deckel
    [ "$PT" -gt 0 ] && echo "   bei 1100 MB deckel reicht das $((1100/PT)) tage"
  else
    echo "   ^ null. Es wird nichts aufgezeichnet."
  fi

  echo
  echo "   wen nennt das log als urheber? (top 5 schreibzugriffe)"
  $SUDO cat "$AUDIT" 2>/dev/null | jq -r '
      select(.verb|test("create|update|patch|delete"))
      | .user.username' 2>/dev/null \
    | sort | uniq -c | sort -rn | head -5 | sed 's/^/     /'
  echo "   Steht hier eine kennung, die mehrere menschen benutzen,"
  echo "   beantwortet das log 'was' und nicht 'wer'."
else
  echo "   kein audit.log unter $AUDIT"
fi
