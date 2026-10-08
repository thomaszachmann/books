#!/usr/bin/env bash
# quarantaene-pruefen.sh - technische Prüfung eines Transfer-Bundles
set -euo pipefail

NAME="${1:?Aufruf: $0 <bundle.tar>}"
S="${SCHLEUSE:-$HOME/seclab/kap04/schleuse}"
MAX_CRITICAL="${MAX_CRITICAL:-0}"
MAX_HIGH="${MAX_HIGH:-5}"
PRUEFER="${PRUEFER:-$(whoami)}"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"
  else shasum -a 256 "$@"; fi
}

ID="${NAME%.tar}_$(date -u +%Y%m%dT%H%M%SZ)"
Q="$S/quarantaene/$ID"      # Arbeitsordner dieses Bundles
I="$Q/inhalt"               # entpackter Inhalt
PROT="$S/protokolle/$ID.json"
mkdir -p "$Q" "$S/protokolle" "$S/geprueft" "$S/abgelehnt"

R_HASH="offen"; R_SIG="offen"; R_DATEIEN="offen"; R_DIGEST="offen"
R_SCAN="offen"; CRIT=-1; HIGH=-1; SECRETS=-1; DIGEST=""; BUNDLE_SHA=""

abschluss() {
  local ent="$1" grund="$2" ziel
  if [ "$ent" = "bestanden" ]; then ziel="$S/geprueft/$ID"
  else ziel="$S/abgelehnt/$ID"; fi
  jq -n \
    --arg id "$ID" --arg bundle "$NAME" --arg sha "$BUNDLE_SHA" \
    --arg digest "$DIGEST" --arg pruefer "$PRUEFER" \
    --arg zeit "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg hash "$R_HASH" --arg sig "$R_SIG" --arg dat "$R_DATEIEN" \
    --arg dig "$R_DIGEST" --arg scan "$R_SCAN" \
    --argjson crit "$CRIT" --argjson high "$HIGH" --argjson sec "$SECRETS" \
    --argjson maxc "$MAX_CRITICAL" --argjson maxh "$MAX_HIGH" \
    --arg ent "$ent" --arg grund "$grund" \
    '{id:$id, bundle:$bundle, bundle_sha256:$sha, image_digest:$digest,
      pruefer:$pruefer, zeitpunkt:$zeit,
      pruefungen:{transport_hash:$hash, absender_signatur:$sig,
        dateien:$dat, digest_abgleich:$dig,
        scan:{ergebnis:$scan, critical:$crit, high:$high, secrets:$sec,
              schwelle:{critical:$maxc, high:$maxh}}},
      entscheidung:$ent, grund:$grund}' > "$PROT"
  jq -c . "$PROT" >> "$S/protokolle/audit.jsonl"
  mv "$Q" "$ziel"
  echo "$ent: $grund"
  echo "Protokoll: $PROT"
}
ablehnen() { abschluss "abgelehnt" "$1"; exit 1; }

# 0. Aus dem Eingang in die Quarantäne holen
mv "$S/eingang/$NAME" "$S/eingang/$NAME.sha256" "$Q/"

# 1. Transport-Integrität des Archivs
if (cd "$Q" && sha256 -c --status "$NAME.sha256"); then R_HASH="ok"
else R_HASH="fehler"; ablehnen "Archiv-Hash stimmt nicht"; fi
BUNDLE_SHA=$(sha256 "$Q/$NAME" | cut -d' ' -f1)

# 2. Archiv-Hygiene: keine absoluten Pfade, kein .., keine Links
if tar -tf "$Q/$NAME" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
  ablehnen "unsichere Pfade im Archiv"; fi
if tar -tvf "$Q/$NAME" | grep -q '^[lh]'; then
  ablehnen "Links im Archiv sind nicht erlaubt"; fi
mkdir -p "$I" && tar -xf "$Q/$NAME" -C "$I"

# 3. Herkunft: Signatur des Absenders über die Hashliste
if openssl dgst -sha256 -verify "$S/vertrauen/absender.pub" \
     -signature "$I/SHA256SUMS.sig" "$I/SHA256SUMS" >/dev/null 2>&1
then R_SIG="ok"; else R_SIG="fehler"; ablehnen "Absender-Signatur ungültig"; fi

# 4. Inhalts-Integrität: alle Hashes, keine fremden Dateien
if ! (cd "$I" && sha256 -c --status SHA256SUMS); then
  R_DATEIEN="fehler"; ablehnen "Datei-Hash stimmt nicht"; fi
GELISTET=$(awk '{print $2}' "$I/SHA256SUMS" | sort)
VORHANDEN=$(cd "$I" && find . -type f ! -name 'SHA256SUMS*' | sort)
if [ "$GELISTET" != "$VORHANDEN" ]; then
  R_DATEIEN="fehler"; ablehnen "fehlende oder zusätzliche Dateien"; fi
R_DATEIEN="ok"

# 5. Konsistenz: Digest im Begleitschein = Image im OCI-Layout
DIGEST=$(jq -r '.digest' "$I/begleitschein.json")
TAG=$(jq -r '.tag' "$I/begleitschein.json")
IDX=$(jq -r --arg t "$TAG" '.manifests[]
  | select(.annotations["org.opencontainers.image.ref.name"]==$t)
  | .digest' "$I/oci/index.json")
if [ "$DIGEST" = "$IDX" ]; then R_DIGEST="ok"
else R_DIGEST="fehler"; ablehnen "Digest passt nicht zum Begleitschein"; fi

# 6. Inhalt: Schwachstellen und Secrets (nur das Image, ohne Referrer)
oras cp --from-oci-layout "$I/oci:$TAG" \
  --to-oci-layout "$Q/scan:$TAG" >/dev/null \
  || ablehnen "Image nicht aus OCI-Layout lesbar"
trivy image --input "$Q/scan" --scanners vuln,secret --ignore-unfixed \
  --quiet --format json --output "$Q/trivy.json" \
  || ablehnen "Scan fehlgeschlagen"
CRIT=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL")]
  | length' "$Q/trivy.json")
HIGH=$(jq '[.Results[]?.Vulnerabilities[]? | select(.Severity=="HIGH")]
  | length' "$Q/trivy.json")
SECRETS=$(jq '[.Results[]?.Secrets[]?] | length' "$Q/trivy.json")
if [ "$CRIT" -gt "$MAX_CRITICAL" ] || [ "$HIGH" -gt "$MAX_HIGH" ] \
   || [ "$SECRETS" -gt 0 ]; then
  R_SCAN="fehler"
  ablehnen "Schwelle überschritten (critical=$CRIT high=$HIGH secrets=$SECRETS)"
fi
R_SCAN="ok"

# 7. Optional: Image-Signatur prüfen (siehe Kapitel 5)
# 8. Optional: Malware-Scan, z. B. clamscan -r --no-summary "$I"

abschluss "bestanden" "alle technischen Prüfungen ok"
