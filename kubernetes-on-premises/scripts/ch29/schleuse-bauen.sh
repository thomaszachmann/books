#!/usr/bin/env bash
# Baut ein Schleusen-Buendel aus einem Image und seiner Signatur und
# versiegelt es.
#
# Warum das ein Skript ist und keine Handvoll Befehle: Beim ersten
# Versuch enthielt das Buendel das Image zweimal. "cosign tree" druckt
# den Image-Digest in der Kopfzeile, und ein "grep -o sha256: | head -1"
# nimmt genau den. Das Buendel versiegelte sauber und war wertlos.
# Deshalb prueft dieses Skript, dass die beiden Digests verschieden
# sind, bevor es irgendetwas packt.
#
# Kapitel 29. Getestet mit skopeo 1.22.2 und cosign v3.1.3.
set -euo pipefail

REF="${1:-}"
ZIEL="${2:-schleuse}"
if [ -z "$REF" ]; then
  echo "aufruf: $0 <registry/repo:tag> [zielverzeichnis]" >&2
  echo "  REG_CREDS=user:pass  REG_INSECURE=1  COSIGN_PUB=..." >&2
  exit 2
fi

for w in skopeo cosign sha256sum; do
  command -v "$w" >/dev/null || { echo "fehlt: $w" >&2; exit 3; }
done

# Registry-Zugang. Zwei Variablen statt roher Flags, weil skopeo je nach
# Unterbefehl andere Namen benutzt: "inspect" will --creds/--tls-verify,
# "copy" will --src-creds/--src-tls-verify. Ein einziges Flag-Wort waere
# an genau dieser Stelle stillschweigend falsch.
#   REG_CREDS=benutzer:passwort
#   REG_INSECURE=1        (registry mit eigener CA)
INSP=(); COPY=(); COSIGN_EXTRA=()
if [ -n "${REG_CREDS:-}" ]; then
  INSP+=(--creds "$REG_CREDS"); COPY+=(--src-creds "$REG_CREDS")
fi
if [ -n "${REG_INSECURE:-}" ]; then
  INSP+=(--tls-verify=false); COPY+=(--src-tls-verify=false)
  COSIGN_EXTRA+=(--allow-insecure-registry)
fi

# Repository ohne Tag. Nicht "${REF%%:*}" - das schneidet am ERSTEN
# Doppelpunkt und macht aus "host:8443/lib/probe:v1" den blossen Host.
# Bei einer Registry mit Portangabe faellt das erst beim Kopieren auf,
# und die Fehlermeldung zeigt auf die Registry statt auf diese Zeile.
REPO="$REF"
case "${REF##*/}" in *:*) REPO="${REF%:*}" ;; esac

echo "== image aufloesen =="
IMG=$(skopeo inspect "${INSP[@]}" --format '{{.Digest}}' "docker://$REF")
echo "  image:     $IMG"

echo "== signatur suchen =="
# Ein Abbruch von cosign tree ist kein "keine signatur" - siehe unten.

BAUM=$(cosign tree "${COSIGN_EXTRA[@]}" "$REF" 2>&1) || {
  echo "  cosign tree ist fehlgeschlagen:" >&2
  echo "$BAUM" | tail -1 | sed 's/^/    /' >&2
  echo "  das ist NICHT dasselbe wie 'keine signatur'." >&2
  echo "  bei TLS-fehlern: REG_INSECURE=1 setzen" >&2
  exit 4
}

# Nur Zeilen mit "referrer" oder ".sig" betrachten - nicht die Kopfzeile,
# in der der Image-Digest selbst steht.
SIG=$(printf '%s\n' "$BAUM" \
      | grep -iE 'referrer|\.sig' \
      | grep -o 'sha256:[0-9a-f]\{64\}' \
      | head -1 || true)

if [ -z "$SIG" ]; then
  echo "  cosign tree lief, meldet aber keine signatur" >&2
  echo "  ohne signatur ist die pruefung aussen pflicht - siehe kap. 29" >&2
  exit 5
fi
echo "  signatur:  $SIG"

# Der Fehler aus dem Kapitel, als Zusicherung.
if [ "$SIG" = "$IMG" ]; then
  echo "  FEHLER: signatur-digest gleich image-digest" >&2
  echo "  das buendel wuerde das image zweimal enthalten" >&2
  exit 6
fi

echo "== packen =="
rm -rf "$ZIEL" && mkdir -p "$ZIEL"
cd "$ZIEL"
skopeo copy "${COPY[@]}" --all "docker://$REPO@$IMG" oci:image:v1 >/dev/null
skopeo copy "${COPY[@]}"       "docker://$REPO@$SIG" oci:signatur:v1 >/dev/null
cosign public-key --key "${COSIGN_KEY:-cosign.key}" > cosign.pub 2>/dev/null \
  || cp "${COSIGN_PUB:-../cosign.pub}" cosign.pub 2>/dev/null \
  || echo "  hinweis: cosign.pub selbst dazulegen" >&2

echo "== versiegeln =="
{
  echo "# schleusen-buendel"
  echo "# ref:            $REF"
  echo "# image-digest:   $IMG"
  echo "# signatur-digest:$SIG"
  sha256sum image/index.json signatur/index.json cosign.pub 2>/dev/null
} > MANIFEST.txt
sed 's/^/  /' MANIFEST.txt

cd ..
tar czf "$ZIEL.tgz" "$ZIEL"
echo "== fertig =="
echo "  $ZIEL.tgz  $(du -h "$ZIEL.tgz" | cut -f1)"
echo
echo "  innen zuerst das siegel pruefen, dann erst importieren:"
echo "    tar xzf $ZIEL.tgz && cd $ZIEL"
echo "    sha256sum -c <(grep -v '^#' MANIFEST.txt)"
