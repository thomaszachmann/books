#!/usr/bin/env bash
# Fuenf ergebnisse fuer EIN zertifikat, je nachdem was prueft.
#
# Der punkt: widerruf ist keine eigenschaft des zertifikats. Die
# datei auf der platte ist byte fuer byte dieselbe, ob widerrufen
# oder nicht. Was sich aendert, ist eine liste, die jemand holen muss.
#
# Und die liste laeuft selbst ab. Vaults vorgabe ist 72h bei
# auto_rebuild=false. Im abgeschotteten netz heisst das: wer die
# CRL nicht alle drei tage nachliefert, bringt JEDE pruefung zum
# scheitern - auch die der gueltigen zertifikate.
#
#   ./revocation.sh          gegen die Vault-PKI aus Band 1
set -uo pipefail

W="${W:-/tmp/ch16}"; mkdir -p "$W"
ROLE="${ROLE:-app}"

need() { command -v "$1" >/dev/null || { echo "fehlt: $1" >&2; exit 2; }; }
need vault; need openssl

vault write -format=json "pki/issue/$ROLE" \
  common_name="probe.meridian.test" ttl=24h > "$W/leaf.json" 2>/dev/null \
  || { echo "PKI nicht eingerichtet - siehe kapitel 16" >&2; exit 1; }
jq -r .data.certificate "$W/leaf.json" > "$W/leaf.crt"
jq -r .data.issuing_ca  "$W/leaf.json" > "$W/ca.crt"

v() { openssl verify "$@" 2>&1 | tail -1; }

echo "== 1. ohne pruefung (die vorgabe fast ueberall) =="
printf '   %s\n' "$(v -CAfile "$W/ca.crt" "$W/leaf.crt")"

SER=$(openssl x509 -in "$W/leaf.crt" -noout -serial | cut -d= -f2 \
      | sed 's/../&:/g;s/:$//' | tr 'A-Z' 'a-z')
vault write pki/revoke serial_number="$SER" >/dev/null 2>&1 \
  && echo "== widerrufen: $SER =="

echo "== 2. dieselbe pruefung nach dem widerruf =="
printf '   %s\n' "$(v -CAfile "$W/ca.crt" "$W/leaf.crt")"
echo "   ^ unveraendert OK. Widerruf ist nicht im zertifikat."

curl -sk "${VAULT_ADDR}/v1/pki/crl" -o "$W/crl.der" 2>/dev/null \
  && openssl crl -inform DER -in "$W/crl.der" -out "$W/crl.pem" 2>/dev/null

echo "== 3. mit pruefung, CRL vorhanden =="
printf '   %s\n' "$(v -crl_check -CAfile "$W/ca.crt" -CRLfile "$W/crl.pem" "$W/leaf.crt")"

echo "== 4. mit pruefung, CRL fehlt (der air-gap-fall) =="
printf '   %s\n' "$(v -crl_check -CAfile "$W/ca.crt" "$W/leaf.crt")"

echo "== 5. mit pruefung, CRL abgelaufen, zertifikat GUELTIG =="
NU=$(openssl crl -in "$W/crl.pem" -noout -nextupdate | cut -d= -f2)
echo "   CRL gilt bis: $NU"
if command -v faketime >/dev/null 2>&1; then
  vault write -field=certificate "pki/issue/$ROLE" \
    common_name="gut.meridian.test" ttl=24h > "$W/gut.crt" 2>/dev/null
  # weit genug hinter nextUpdate, aber das zertifikat muss noch gelten:
  # dafuer braucht die rolle ein hoeheres max_ttl - siehe kapitel.
  printf '   +5 tage: %s\n' \
    "$(faketime '+5 days' openssl verify -crl_check -CAfile "$W/ca.crt" \
       -CRLfile "$W/crl.pem" "$W/gut.crt" 2>&1 | tail -1)"
  echo "   Achtung: scheitert das mit 'certificate has expired', ist"
  echo "   das TESTZERTIFIKAT abgelaufen, nicht die CRL. Die rolle"
  echo "   braucht ein max_ttl ueber der verschiebung."
else
  echo "   (faketime fehlt - schritt 5 uebersprungen)"
fi
