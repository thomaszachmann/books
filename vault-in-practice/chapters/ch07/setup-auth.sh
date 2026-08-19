#!/usr/bin/env bash
# Chapter 7 - userpass on two mounts, and an AppRole that burns out.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

# The secret the policy grants, in case you start from a clean Vault.
vault secrets enable -path=meridian -version=2 kv >/dev/null 2>&1 || true
vault kv put meridian/tracking \
  db_user=tracking_svc db_password=auth-lab-pw >/dev/null

vault policy write tracking-read chapters/ch07/policies/tracking-read.hcl

# Step 1 - userpass on its default mount.
vault auth enable userpass 2>/dev/null || echo "userpass already enabled"
vault write auth/userpass/users/alice \
  password=lab-password-1 \
  policies=tracking-read \
  ttl=1h >/dev/null

# Step 2 - a second userpass mount, so the login URL matters.
vault auth enable -path=contractors userpass 2>/dev/null \
  || echo "contractors already enabled"
vault write auth/contractors/users/sam \
  password=lab-password-2 policies=default >/dev/null

# Step 3 - AppRole. Two uses per SecretID, so Step 4 can exhaust one.
vault auth enable approle 2>/dev/null || echo "approle already enabled"
vault write auth/approle/role/tracking \
  token_policies="tracking-read" \
  token_ttl=1h token_max_ttl=4h \
  secret_id_ttl=10m secret_id_num_uses=2 >/dev/null

# Step 5 - tuning affects new tokens only.
vault auth tune -default-lease-ttl=30m userpass/

echo
echo "Ready. The three things worth doing by hand:"
echo
echo "  # 1. log in as alice, read the secret the policy allows"
echo "  ROOT=\$VAULT_TOKEN; unset VAULT_TOKEN"
echo "  vault login -method=userpass username=alice password=lab-password-1"
echo "  vault kv get meridian/tracking"
echo "  export VAULT_TOKEN=\$ROOT"
echo
echo "  # 2. the mount trap - this FAILS, read the URL in the error"
echo "  unset VAULT_TOKEN"
echo "  vault login -method=userpass username=sam password=lab-password-2"
echo "  vault login -method=userpass -path=contractors \\"
echo "      username=sam password=lab-password-2"
echo "  export VAULT_TOKEN=\$ROOT"
echo
echo "  # 3. burn out a SecretID - third login fails, issued tokens live on"
echo "  ./chapters/ch07/burn-secret-id.sh"
