#!/usr/bin/env bash
cd ~/bao-lab/tag05
check() { if eval "$2" >/dev/null 2>&1; then echo "✔ $1"; else echo "✘ $1"; fi; }

check "Transit-Key webshop" "bao read transit/keys/webshop"
RT=$(bao write -field=ciphertext transit/encrypt/webshop \
  plaintext=$(echo -n ok | base64))
check "Encrypt/Decrypt Roundtrip" \
  "bao write -field=plaintext transit/decrypt/webshop ciphertext=$RT \
  | base64 -d | grep -qx ok"
check "Signing-Key ecdsa" \
  "bao read -field=type transit/keys/webshop-sign | grep -q ecdsa-p256"
check "Root-CA" "bao read pki/cert/ca"
check "Kette gültig" "openssl verify -CAfile root_ca.crt -untrusted int.crt api.crt"
check "Rolle webshop" "bao read pki_int/roles/webshop"
check "ACME-Directory" "curl -sf $BAO_ADDR/v1/pki_int/acme/directory"
