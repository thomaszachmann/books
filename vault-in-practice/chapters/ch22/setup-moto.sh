#!/usr/bin/env bash
# Chapter 22 - a KMS key for Vault to unseal with, in a KMS that is not
# Amazon's. Everything Vault does against it is the real API; only the
# endpoint differs, and `endpoint` is a documented seal parameter.
set -euo pipefail
cd "$(dirname "$0")/../.."

# Three compose files share one project; without this, each one calls
# the others' containers orphans.
export COMPOSE_IGNORE_ORPHANS=1

COMPOSE="docker compose -f docker-compose.yml -f docker-compose.awskms.yml"
AWS="$COMPOSE run --rm aws"

$COMPOSE up -d moto
for _ in $(seq 1 30); do
  curl -sf http://127.0.0.1:5000/moto-api/ >/dev/null 2>&1 && break
  sleep 1
done

# A symmetric key and an alias. Vault is configured with the ALIAS, so a
# future key rotation is a change on the AWS side, not in vault.hcl.
if KEY=$($AWS kms describe-key --key-id alias/vault-unseal \
           --query KeyMetadata.KeyId --output text 2>/dev/null | tr -d '\r') && [ -n "$KEY" ]; then
  echo "alias/vault-unseal already exists."
else
  KEY=$($AWS kms create-key --description "Vault auto-unseal (lab)" \
          --query KeyMetadata.KeyId --output text | tr -d '\r')
  $AWS kms create-alias --alias-name alias/vault-unseal --target-key-id "$KEY"
fi
echo "$KEY" > chapters/ch22/.kms-key-id

$AWS kms describe-key --key-id alias/vault-unseal \
  --query 'KeyMetadata.[KeyId,KeyState,KeySpec]' --output text

echo
echo "Key $KEY is alias/vault-unseal in region eu-central-1 of account"
echo "123456789012 - moto's fixed account id. Nothing here is a secret."
echo "next: ./chapters/ch22/migrate-to-awskms.sh"
