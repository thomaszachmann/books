#!/usr/bin/env bash
# Sammelt den maschinell erfassbaren Teil des Nachweisdossiers.
#
# Sammelt NICHT: Entscheidungen, Freigaben, Namen. Diese Zeilen bleiben
# leer und muessen von einem Menschen ausgefuellt werden. Genau das ist
# der Punkt - ein Dossier, das sich vollstaendig erzeugen laesst, ist
# ein Bericht und kein Nachweis.
#
# Kapitel 33.
set -uo pipefail

ZIEL="${1:-evidence}"
K="${KUBECTL:-kubectl}"
STAND=$(date +%Y-%m-%d_%H:%M)

mkdir -p "$ZIEL"
BERICHT="$ZIEL/dossier-$STAND.md"

z() { echo "$*" >> "$BERICHT"; }
zeile() { printf "| %-38s | %-22s | %s |\n" "$1" "$2" "$3" >> "$BERICHT"; }

k() { $K "$@" --no-headers 2>/dev/null | wc -l | tr -d ' '; }

z "# Nachweisdossier - stand $STAND"
z ""
z "Maschinell erhoben. Die Spalte *Nachweis* stammt aus dem Cluster,"
z "die Spalte *verantwortlich* nicht - die traegt ein Mensch nach."
z ""
z "| Kontrolle | Nachweis | verantwortlich |"
z "|---|---|---|"

# --- Identitaet und Zugriff -------------------------------------------
SUPER=$($K get clusterrolebindings -o json 2>/dev/null \
  | python3 -c "
import json,sys
try: d=json.load(sys.stdin)
except Exception: print('?'); raise SystemExit
n=[i['metadata']['name'] for i in d.get('items',[])
   if i.get('roleRef',{}).get('name')=='cluster-admin']
print(len(n))" 2>/dev/null || echo "?")
zeile "ch17 cluster-admin-bindungen" "$SUPER" ""

AP=/etc/rancher/rke2/audit-policy.yaml
if [ -r "$AP" ]; then
  # Der Fund aus Kapitel 17: das CIS-Profil liefert eine Policy, die
  # nichts protokolliert. Die Datei zu zaehlen genuegt deshalb nicht -
  # es zaehlt, ob sie eine andere Stufe als None kennt.
  if grep -qE '^\s*-?\s*level:\s*(Metadata|Request|RequestResponse)' "$AP"; then
    zeile "ch17 audit-policy" "protokolliert" ""
  else
    zeile "ch17 audit-policy" "NUR level=None" ""
  fi
else
  zeile "ch17 audit-policy" "fehlt" ""
fi

LOG=/var/lib/rancher/rke2/server/logs/audit.log
if [ -f "$LOG" ]; then
  zeile "ch25 audit-log" "$(stat -c %s "$LOG") bytes" ""
else
  zeile "ch25 audit-log" "keine datei" ""
fi

# --- Zulassung und Trennung -------------------------------------------
POL=$(( $(k get validatingpolicies -A) + $(k get clusterpolicies -A) ))
zeile "ch18 zulassungsregeln" "$POL" ""
zeile "ch19 networkpolicies" "$(k get netpol -A)" ""
zeile "ch20 resourcequotas" "$(k get resourcequota -A)" ""
zeile "ch20 namespaces" "$(k get ns)" ""

# --- Herkunft ---------------------------------------------------------
IMG=$($K get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' 2>/dev/null)
GES=$(printf '%s\n' "$IMG" | grep -c . || true)
DIG=$(printf '%s\n' "$IMG" | grep -c '@sha256:' || true)
zeile "ch22 container mit digest" "$DIG von $GES" ""

# --- Wiederherstellung ------------------------------------------------
SNAPDIR=/var/lib/rancher/rke2/server/db/snapshots
SN=$(ls "$SNAPDIR" 2>/dev/null | wc -l | tr -d ' ')
if [ "$SN" -gt 0 ]; then
  J=$(ls -t "$SNAPDIR" | head -1)
  A=$(( ( $(date +%s) - $(stat -c %Y "$SNAPDIR/$J") ) / 3600 ))
  zeile "ch26 etcd-snapshots" "$SN, juengster ${A}h alt" ""
else
  zeile "ch26 etcd-snapshots" "KEINE" ""
fi

# --- Abschottung und Veroeffentlichung --------------------------------
if command -v nft >/dev/null 2>&1; then
  # Regelwerk einmal einlesen. "nft | grep -q" liefert unter pipefail
  # einen Fehlschlag, sobald grep frueh aussteigt - siehe Kapitel 32.
  R=$(nft list ruleset 2>/dev/null || true)
  O=$(printf '%s\n' "$R" | grep -c "hook output" || true)
  F=$(printf '%s\n' "$R" | grep -c "hook forward" || true)
  zeile "ch27 nft-haken output/forward" "$O / $F" ""
fi
zeile "ch32 gateways" "$(k get gateway -A)" ""
if command -v firewall-cmd >/dev/null 2>&1; then
  Z=$(firewall-cmd --get-default-zone 2>/dev/null)
  zeile "ch32 offene ports ($Z)" "$(firewall-cmd --zone="$Z" --list-ports 2>/dev/null)" ""
fi

z ""
z "## Was hier NICHT steht"
z ""
z "Diese Zeilen kann kein Skript fuellen. Ohne sie ist das Dossier"
z "ein Bericht ueber einen Cluster, kein Nachweis einer Entscheidung."
z ""
for f in \
  "wer die plattform betreibt" \
  "wer eine ausnahme genehmigt und in welcher frist" \
  "wann der spiegel zuletzt abgeglichen wurde und von wem" \
  "wann die wiederherstellung zuletzt GEUEBT wurde" \
  "wer die schleuse bedient und wer gegenzeichnet" \
  "welche befunde bewusst offen bleiben und warum"; do
  z "- [ ] $f: ____________________"
done

z ""
z "## Gueltigkeit"
z ""
z "Erhoben am $STAND. Ein Neuaufbau der Plattform macht diesen Stand"
z "in Minuten ungueltig - siehe Kapitel 30, wo eine Deinstallation in"
z "63 Sekunden zwoelf Kapitel Kontrollen entfernt hat."
z ""
z "naechste erhebung faellig: ____________"
z "erhoben von:                ____________"

echo "  geschrieben: $BERICHT"
grep -c '^|' "$BERICHT" | sed 's/^/  zeilen im nachweis: /'
grep -c '^- \[ \]' "$BERICHT" | sed 's/^/  offene menschenfelder: /'
