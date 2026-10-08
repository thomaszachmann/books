#!/usr/bin/env bash
# freigeben.sh - Freigabe eines geprüften Bundles (Vier-Augen-Prinzip)
set -euo pipefail

ID="${1:?Aufruf: $0 <bundle-id>}"
S="${SCHLEUSE:-$HOME/seclab/kap04/schleuse}"
FREIGEBER="${FREIGEBER:?FREIGEBER=<name> setzen}"
KEY="${FREIGEBER_KEY:?FREIGEBER_KEY=<pfad zum privaten Schlüssel> setzen}"
PROT="$S/protokolle/$ID.json"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"
  else shasum -a 256 "$@"; fi
}

[ -d "$S/geprueft/$ID" ] || { echo "Bundle $ID ist nicht im Status geprüft"; exit 1; }
[ "$(jq -r .entscheidung "$PROT")" = "bestanden" ] \
  || { echo "Prüfprotokoll ist nicht bestanden"; exit 1; }

PRUEFER=$(jq -r .pruefer "$PROT")
if [ "$PRUEFER" = "$FREIGEBER" ]; then
  echo "Vier-Augen-Prinzip verletzt: $FREIGEBER hat selbst geprüft"; exit 1
fi

jq . "$PROT"
read -r -p "Bundle $ID freigeben? (ja/nein) " ANTWORT
[ "$ANTWORT" = "ja" ] || { echo "Keine Freigabe."; exit 1; }

F="$S/geprueft/$ID/freigabe.json"
jq -n \
  --arg id "$ID" \
  --arg digest "$(jq -r .image_digest "$PROT")" \
  --arg bundle_sha "$(jq -r .bundle_sha256 "$PROT")" \
  --arg prot_sha "$(sha256 "$PROT" | cut -d' ' -f1)" \
  --arg wer "$FREIGEBER" --arg pruefer "$PRUEFER" \
  --arg zeit "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{id:$id, image_digest:$digest, bundle_sha256:$bundle_sha,
    pruefprotokoll_sha256:$prot_sha, geprueft_von:$pruefer,
    freigegeben_von:$wer, zeitpunkt:$zeit, entscheidung:"freigegeben"}' > "$F"
openssl dgst -sha256 -sign "$KEY" -out "$F.sig" "$F"

jq -c . "$F" >> "$S/protokolle/audit.jsonl"
mkdir -p "$S/freigegeben"
mv "$S/geprueft/$ID" "$S/freigegeben/$ID"
echo "Freigegeben: $S/freigegeben/$ID"
