#!/usr/bin/env bash
# Prueft ein RKE2-Aufstiegsfenster, bevor es aufgeht.
#
# Beantwortet die vier Fragen aus Kapitel 31, die sonst erst im Fenster
# auffallen:
#   - wieviel des buendels ist ueberhaupt neu
#   - reicht die platte fuer noch eine generation
#   - liegt ruecksprungmaterial da, und von welcher version
#   - liegen verwaiste tarballs herum
#
# Laeuft ohne Netz, wenn die .txt-bildlisten im satz liegen.
#
# WARNUNG zum alten satz: darin duerfen nur die bildlisten des
# LAUFENDEN standes liegen. Beim schreiben von Kapitel 31 lagen dort
# versehentlich auch die listen der zielversion, und der vergleich
# meldete "unveraendert: 25, neu: 0" - also genau das ergebnis, das
# einen aufstieg als ueberfluessig erscheinen laesst. Ein pruefer, der
# faelschlich "nichts aendert sich" sagt, ist schlimmer als keiner.
#
# Kapitel 31.
set -euo pipefail

SATZ="${1:-}"
ALTSATZ="${2:-}"
IMGDIR="${IMGDIR:-/var/lib/rancher/rke2/agent/images}"
PRO_GENERATION_GB="${PRO_GENERATION_GB:-3}"

if [ -z "$SATZ" ]; then
  echo "aufruf: $0 <neuer-satz> [alter-satz]" >&2
  echo "  erwartet darin die .tar.zst und die .txt-bildlisten" >&2
  echo "  der alte satz ist optional und liefert den anteil, der" >&2
  echo "  sich wirklich aendert" >&2
  exit 2
fi
[ -d "$SATZ" ] || { echo "kein verzeichnis: $SATZ" >&2; exit 2; }

warn=0
melde() { echo "  $*"; }
mangel() { echo "  ACHTUNG: $*"; warn=$((warn+1)); }

echo "=== versionen ==="
# rke2 liegt in /usr/local/bin und steht bei sudo nicht immer im PATH.
# Ohne den festen Pfad bricht das Skript unter "set -e" wortlos ab -
# genau die Sorte Fehler, die im Wartungsfenster Zeit kostet.
RKE2=$(command -v rke2 || echo /usr/local/bin/rke2)
JETZT=$("$RKE2" --version 2>/dev/null | awk '/^rke2 version/{print $3}' || true)
ZIEL=$(grep -hoP 'v\d+\.\d+\.\d+-rke2r\d+' "$SATZ"/rke2-images-core*.txt 2>/dev/null | head -1 || true)
ZIEL="${ZIEL/-rke2r/+rke2r}"
melde "installiert: ${JETZT:-unbekannt}"
melde "ziel:        ${ZIEL:-unbekannt (bildliste fehlt)}"
if [ -n "$JETZT" ] && [ "$JETZT" = "$ZIEL" ]; then
  mangel "ziel ist die laufende version - nichts zu tun"
fi

echo "=== wieviel ist wirklich neu ==="
# Die .txt-listen des LAUFENDEN standes liegen im alten satz. Ohne ihn
# laesst sich der anteil nicht bestimmen - das ist kein fehler, aber
# die zahl fehlt dann im fensterprotokoll.
#
# Der alte satz wird uebergeben und nicht geraten: ein glob ueber
# nachbarverzeichnisse findet irgendwann das falsche und rechnet still
# mit ihm weiter.
NEU=$(cat "$SATZ"/rke2-images-*.txt 2>/dev/null | sort -u || true)
if [ -n "$ALTSATZ" ] && [ -d "$ALTSATZ" ] && [ -n "$NEU" ]; then
  A=$(cat "$ALTSATZ"/rke2-images-*.txt 2>/dev/null | sort -u)
  gleich=$(comm -12 <(echo "$A") <(echo "$NEU") | wc -l)
  neu=$(comm -13 <(echo "$A") <(echo "$NEU") | wc -l)
  ges=$(echo "$NEU" | wc -l)
  melde "images im ziel:  $ges"
  melde "unveraendert:    $gleich"
  melde "neu:             $neu"
  # "alles unveraendert" heisst fast immer, dass der alte satz die
  # listen der zielversion enthaelt - nicht, dass sich nichts aendert.
  if [ "$neu" -eq 0 ] && [ "$JETZT" != "$ZIEL" ]; then
    mangel "0 neue images bei verschiedenen versionen - alten satz pruefen"
  fi
  comm -13 <(echo "$A") <(echo "$NEU") | sed 's|.*/||' | head -6 | sed 's/^/    /'
elif [ -n "$ALTSATZ" ]; then
  mangel "alter satz '$ALTSATZ' hat keine bildlisten"
else
  melde "kein alter satz uebergeben - anteil unbestimmt"
fi
GR=$(du -sm "$SATZ" 2>/dev/null | cut -f1)
melde "buendel:         ${GR:-?} MB"

echo "=== platte ==="
FREI=$(df -BG --output=avail "$IMGDIR" 2>/dev/null | tail -1 | tr -dc '0-9')
melde "frei:            ${FREI:-?} GB"
melde "pro generation:  ~${PRO_GENERATION_GB} GB (gemessen in kap. 31)"
if [ -n "${FREI:-}" ] && [ "$FREI" -lt $((PRO_GENERATION_GB * 2)) ]; then
  mangel "weniger als zwei generationen frei"
fi

echo "=== ruecksprungmaterial ==="
# Der Kern der Sache: die tarball-namen tragen keine version. Nach dem
# aufstieg sieht die ablage genauso aus wie vorher, und niemand kann
# sagen, welcher stand da liegt. Deshalb digest statt name.
if [ -d "$IMGDIR" ]; then
  for f in "$IMGDIR"/*.tar.zst "$IMGDIR"/*.tar.gz; do
    [ -e "$f" ] || continue
    printf "  %6s  %s  sha256:%s\n" \
      "$(du -h "$f" | cut -f1)" \
      "$(date -r "$f" +%d.%m.%H:%M)" \
      "$(sha256sum "$f" | cut -c1-12)"
  done
  melde "^ dateinamen tragen keine version. digest notieren."
  # Verwaiste: alles, was nicht core/<cni> ist.
  CNI=$(awk -F: '/^\s*cni:/{gsub(/[" ]/,"",$2); print $2}' \
        /etc/rancher/rke2/config.yaml 2>/dev/null | head -1)
  for f in "$IMGDIR"/*.tar.zst; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    case "$b" in
      rke2-images-core.*) ;;
      rke2-images-${CNI}.*) ;;
      *) mangel "verwaist? $b ($(du -h "$f"|cut -f1)) - wird bei jedem start gelesen" ;;
    esac
  done
else
  mangel "images-ablage nicht gefunden: $IMGDIR"
fi

echo "=== etcd-snapshot ==="
SNAP=$(ls -t /var/lib/rancher/rke2/server/db/snapshots/* 2>/dev/null | head -1 || true)
if [ -n "$SNAP" ]; then
  melde "juengster: $(basename "$SNAP") vom $(date -r "$SNAP" +%d.%m.%Y\ %H:%M)"
  ALTER=$(( ( $(date +%s) - $(stat -c %Y "$SNAP") ) / 3600 ))
  [ "$ALTER" -gt 24 ] && mangel "snapshot ist ${ALTER} h alt"
  melde "liegt er auch AUSSERHALB dieser maschine? -> von hand bestaetigen"
else
  mangel "kein etcd-snapshot vorhanden"
fi

echo "=== ergebnis ==="
if [ "$warn" -eq 0 ]; then
  melde "fenster kann aufgehen"
  melde "erwartete zeiten (kap. 31): api ~16 s, knoten ~302 s, Ready ~322 s"
  exit 0
fi
melde "$warn punkt(e) klaeren, bevor das fenster aufgeht"
exit 1
