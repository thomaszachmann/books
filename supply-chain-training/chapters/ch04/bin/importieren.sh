#!/usr/bin/env bash
# importieren.sh - Import eines freigegebenen Bundles nach reg-ziel
set -euo pipefail

ID="${1:?Aufruf: $0 <bundle-id>}"
S="${SCHLEUSE:-$HOME/seclab/kap04/schleuse}"
ZIEL="${ZIEL_REGISTRY:-localhost:5002}"
D="$S/freigegeben/$ID"; I="$D/inhalt"; F="$D/freigabe.json"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"
  else shasum -a 256 "$@"; fi
}

# 1. Freigabe echt?
openssl dgst -sha256 -verify "$S/vertrauen/freigeber.pub" \
  -signature "$F.sig" "$F" >/dev/null \
  || { echo "Freigabe-Signatur ungültig"; exit 1; }

# 2. Freigabe passt zu diesem Bundle?
SOLL=$(jq -r .bundle_sha256 "$F")
IST=$(sha256 "$D"/*.tar | cut -d' ' -f1)
[ "$SOLL" = "$IST" ] || { echo "Freigabe gehört zu anderem Bundle"; exit 1; }

# 3. Inhalt seit der Prüfung unverändert?
(cd "$I" && sha256 -c --status SHA256SUMS) \
  || { echo "Inhalt nach Prüfung verändert"; exit 1; }

DIGEST=$(jq -r .image_digest "$F")
REPO=$(jq -r .image "$I/begleitschein.json")
TAG=$(jq -r .tag "$I/begleitschein.json")

# 4. Image mit allen Referrern kopieren, dann zusätzliche Tags (z. B. .sig)
oras cp -r --from-oci-layout "$I/oci:$TAG" \
  --to-plain-http "$ZIEL/$REPO:$TAG"
for REF in $(jq -r '.manifests[].annotations["org.opencontainers.image.ref.name"]
               // empty' "$I/oci/index.json"); do
  [ "$REF" = "$TAG" ] && continue
  oras cp --from-oci-layout "$I/oci:$REF" --to-plain-http "$ZIEL/$REPO:$REF"
done

# 5. Digest-Vergleich
ANGEKOMMEN=$(crane digest "$ZIEL/$REPO:$TAG")
if [ "$ANGEKOMMEN" = "$DIGEST" ]; then
  echo "OK: $ZIEL/$REPO@$ANGEKOMMEN ist identisch mit der Freigabe"
else
  echo "FEHLER: erwartet $DIGEST, angekommen $ANGEKOMMEN"; exit 1
fi
