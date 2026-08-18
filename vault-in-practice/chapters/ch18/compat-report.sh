#!/usr/bin/env bash
# Chapter 18 - measure compatibility instead of asserting it.
#
# Probes both systems for the engines and auth methods this book uses and
# prints what each supports. Keep the output with its date and both
# version numbers: that is evidence. "They are compatible" is a claim.
set -uo pipefail
cd "$(dirname "$0")/../.."

VAULT_ROOT="${VAULT_TOKEN:-$(jq -r .root_token init.json 2>/dev/null)}"

probe() {
  local label="$1" bin="$2" addr="$3" token="$4" cacert="${5:-}"
  echo "=== $label ==="
  VAULT_ADDR="$addr" BAO_ADDR="$addr" \
  VAULT_TOKEN="$token" BAO_TOKEN="$token" \
  VAULT_CACERT="$cacert" BAO_CACERT="$cacert" \
    $bin version 2>/dev/null | head -1

  for kind in secrets auth; do
    if [ "$kind" = secrets ]; then
      items="kv transit pki database ssh totp"
    else
      items="userpass approle kubernetes cert jwt ldap"
    fi
    echo "-- $kind --"
    for i in $items; do
      if VAULT_ADDR="$addr" BAO_ADDR="$addr" \
         VAULT_TOKEN="$token" BAO_TOKEN="$token" \
         VAULT_CACERT="$cacert" BAO_CACERT="$cacert" \
           $bin "$kind" enable -path="p-$i" "$i" >/dev/null 2>&1; then
        printf "   yes  %s\n" "$i"
        VAULT_ADDR="$addr" BAO_ADDR="$addr" \
        VAULT_TOKEN="$token" BAO_TOKEN="$token" \
        VAULT_CACERT="$cacert" BAO_CACERT="$cacert" \
          $bin "$kind" disable "p-$i" >/dev/null 2>&1
      else
        printf "   NO   %s\n" "$i"
      fi
    done
  done
  echo
}

echo "compatibility probe - $(date -u '+%Y-%m-%d %H:%M UTC')"
echo

command -v vault >/dev/null && probe "HashiCorp Vault" vault \
  "https://127.0.0.1:8200" "$VAULT_ROOT" "$PWD/tls/vault-cert.pem"

command -v bao >/dev/null && probe "OpenBao" bao \
  "http://127.0.0.1:8300" "root"

echo "Keep this file. When somebody asks whether they are compatible,"
echo "re-run it and diff - the diff answers whether the projects are"
echo "converging or drifting."
