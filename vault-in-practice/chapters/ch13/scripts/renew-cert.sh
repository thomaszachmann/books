#!/usr/bin/env bash
# Chapter 13 - renew on remaining lifetime, not on a schedule.
#
# A fixed schedule breaks silently the moment the issued lifetime changes.
# Triggering on what is left does not.
set -euo pipefail
cd "$(dirname "$0")/../../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

CN="${1:-api.meridian.internal}"
OUT="${2:-/tmp/${CN}}"
RENEW_BEFORE_SECONDS=$((8 * 3600))

seconds_left() {
  local end
  end=$(openssl x509 -in "$1" -noout -enddate | cut -d= -f2)
  local end_epoch
  end_epoch=$(date -j -f "%b %e %T %Y %Z" "$end" +%s 2>/dev/null \
              || date -d "$end" +%s)
  echo $(( end_epoch - $(date +%s) ))
}

if [ -f "$OUT.crt" ]; then
  LEFT=$(seconds_left "$OUT.crt")
  if [ "$LEFT" -gt "$RENEW_BEFORE_SECONDS" ]; then
    echo "$((LEFT / 3600))h remaining for $CN - not renewing"
    exit 0
  fi
  echo "$((LEFT / 3600))h remaining - renewing"
fi

vault write -format=json pki_int/issue/meridian-24h \
  common_name="$CN" ttl="24h" > "$OUT.json"

jq -r '.data.certificate'  "$OUT.json" > "$OUT.crt"
jq -r '.data.private_key'  "$OUT.json" > "$OUT.key"
jq -r '.data.ca_chain[]'   "$OUT.json" > "$OUT.chain.crt"
chmod 600 "$OUT.key"

echo "issued $CN -> $OUT.crt (valid $(( $(seconds_left "$OUT.crt") / 3600 ))h)"
echo "reload the service here"
