#!/usr/bin/env bash
# Prueft einen RKE2-Offline-Satz, bevor er durch die Schleuse geht.
#
# Der Anlass: "rke2-images.linux-amd64.tar.zst" heisst wie "alle Images"
# und enthaelt core + calico + flannel. Fuer einen Cilium-Cluster fehlen
# darin 11 von 11 Cilium-Images. Die Installation laeuft trotzdem an,
# der Steuerungsteil kommt hoch, und der Knoten bleibt NotReady - auf
# der falschen Seite des Drahtes, wo Nachladen Tage kostet.
#
# Das Skript liest den CNI aus der config.yaml und prueft, ob der Satz
# dazu passt. Kapitel 30.
set -euo pipefail

SATZ="${1:-.}"
CFG="${2:-/etc/rancher/rke2/config.yaml}"

fehler=0
melde() { echo "  $*"; }
mangel() { echo "  MANGEL: $*" >&2; fehler=$((fehler+1)); }

[ -d "$SATZ" ] || { echo "kein verzeichnis: $SATZ" >&2; exit 2; }

echo "=== erwartung aus der konfiguration ==="
if [ -r "$CFG" ]; then
  CNI=$(awk -F: '/^\s*cni:/{gsub(/[" ]/,"",$2); print $2}' "$CFG" | head -1)
  PROFIL=$(awk -F: '/^\s*profile:/{gsub(/[" ]/,"",$2); print $2}' "$CFG" | head -1)
else
  CNI="${CNI:-}"; PROFIL=""
  melde "keine config.yaml lesbar - CNI per umgebungsvariable setzen"
fi
CNI="${CNI:-canal}"
melde "cni:     ${CNI}"
melde "profil:  ${PROFIL:-<keins>}"

echo "=== was im satz liegt ==="
cd "$SATZ"
mapfile -t TARS < <(ls rke2-images*.tar.zst rke2-images*.tar.gz 2>/dev/null || true)
[ "${#TARS[@]}" -gt 0 ] || mangel "keine images-tarballs gefunden"
for t in "${TARS[@]}"; do melde "$(du -h "$t" | cut -f1)  $t"; done
[ -f rke2.linux-amd64.tar.gz ] || mangel "rke2.linux-amd64.tar.gz fehlt"
[ -f install.sh ]              || mangel "install.sh fehlt"
[ -f sha256sum-amd64.txt ]     || mangel "sha256sum-amd64.txt fehlt"

echo "=== deckt der satz den CNI ab ==="
# core wird immer gebraucht. Der CNI-Satz ist ein eigener Tarball -
# ausser bei canal/calico/flannel, die im Sammelbuendel stecken.
hat() { printf '%s\n' "${TARS[@]}" | grep -q "rke2-images-$1\."; }
hat_sammel() { printf '%s\n' "${TARS[@]}" | grep -qE 'rke2-images\.linux'; }

if hat core; then
  melde "core: eigener tarball vorhanden"
elif hat_sammel; then
  melde "core: im sammelbuendel enthalten"
else
  mangel "core fehlt - weder rke2-images-core noch rke2-images"
fi

case "$CNI" in
  cilium|multus|vsphere|harvester)
    if hat "$CNI"; then
      melde "$CNI: eigener tarball vorhanden"
    else
      mangel "$CNI ist NICHT im sammelbuendel. rke2-images-$CNI fehlt."
      mangel "  der cluster installiert und bleibt NotReady."
    fi ;;
  canal|calico|flannel)
    if hat "$CNI" || hat_sammel; then
      melde "$CNI: abgedeckt"
    else
      mangel "$CNI fehlt"
    fi ;;
  *) melde "unbekannter cni '$CNI' - bildliste von hand pruefen" ;;
esac

echo "=== bildlisten gegen die tarball-namen ==="
# Die .txt-Listen sind winzig und gehoeren in den Satz: nur mit ihnen
# laesst sich drinnen nachweisen, was fehlt.
for t in "${TARS[@]}"; do
  b="${t%%.linux-amd64*}"
  if [ -f "$b.linux-amd64.txt" ] || [ -f "$b.txt" ]; then
    l="$b.linux-amd64.txt"; [ -f "$l" ] || l="$b.txt"
    melde "$(printf '%3d' "$(wc -l < "$l")") images  $l"
  else
    mangel "bildliste zu $t fehlt ($b.linux-amd64.txt)"
  fi
done

echo "=== pruefsummen ==="
if [ -f sha256sum-amd64.txt ]; then
  vorhanden=$(ls rke2-images*.tar.* rke2.linux-amd64.tar.gz 2>/dev/null || true)
  if [ -n "$vorhanden" ]; then
    # Nur die Zeilen pruefen, deren Datei auch da ist. Ein pauschales
    # "sha256sum -c" meldet sonst jede nicht geladene Datei als Fehler
    # und die echten Treffer gehen darin unter.
    for f in $vorhanden; do
      z=$(grep -E "  $f\$" sha256sum-amd64.txt || true)
      if [ -z "$z" ]; then mangel "keine pruefsumme fuer $f"; continue; fi
      if printf '%s\n' "$z" | sha256sum -c --status 2>/dev/null; then
        melde "OK  $f"
      else
        mangel "PRUEFSUMME FALSCH: $f"
      fi
    done
  fi
fi

echo "=== ergebnis ==="
if [ "$fehler" -eq 0 ]; then
  melde "satz ist vollstaendig - $(du -sh . | cut -f1) gehen durch die schleuse"
  exit 0
fi
melde "$fehler mangel(-) - NICHT ueberqueren"
exit 1
