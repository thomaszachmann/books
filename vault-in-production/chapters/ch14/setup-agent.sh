#!/usr/bin/env bash
# AppRole, a secret and an agent container on the lab network.
# Needs: . ./scripts/vault-env.sh sourced, cluster unsealed.
set -euo pipefail

cd "$(dirname "$0")/../.." || exit 1
. ./scripts/engine.sh

NET=${NET:-vault-in-production_default}
WORK=${WORK:-/tmp/agent}
HERE="chapters/ch14"

vault auth enable approle >/dev/null 2>&1 || true
vault secrets enable -path=secret -version=2 kv >/dev/null 2>&1 || true
vault kv put secret/app/config db=primary tier=gold >/dev/null

vault policy write app-read - >/dev/null <<'POL'
path "secret/data/app/*" { capabilities = ["read"] }
POL

# A short token TTL on purpose: the outage in the lab lasts longer,
# and that is exactly what the file must not mind.
vault write auth/approle/role/app token_policies=app-read \
  token_ttl=2m token_max_ttl=10m >/dev/null

# A second run starts clean. The files in out/ belong to the agent's
# UID, so the old container goes first, then the directory.
$ENGINE rm -f vault-agent >/dev/null 2>&1 || true
rm -rf "$WORK/out"
mkdir -p "$WORK/out" "$WORK/tmpl"
vault read -field=role_id auth/approle/role/app/role-id > "$WORK/role_id"
vault write -f -field=secret_id \
  auth/approle/role/app/secret-id > "$WORK/secret_id"
cp "$HERE/agent.hcl"     "$WORK/agent.hcl"
cp "$HERE/config.ctmpl"  "$WORK/tmpl/config.ctmpl"
chmod -R a+rX "$WORK"
# The agent runs as "vault" (UID 100) and writes token and file here.
chmod 777 "$WORK/out"

# On an SELinux host /tmp is user_tmp_t and the container may not
# read it: "open /agent.hcl: permission denied". VAULT_MOUNT_OPT
# (",z" there, empty elsewhere) relabels every mount, as in
# docker-compose.yml.
M=${VAULT_MOUNT_OPT:-}
$ENGINE rm -f vault-agent >/dev/null 2>&1 || true
$ENGINE run -d --name vault-agent --network "$NET" \
  -v "$WORK/agent.hcl:/agent.hcl:ro$M" \
  -v "$WORK/tmpl:/tmpl:ro$M" \
  -v "$WORK/out:/out:rw$M" \
  -v "$WORK/role_id:/creds/role_id:ro$M" \
  -v "$WORK/secret_id:/creds/secret_id:ro$M" \
  -v "$PWD/cluster/tls/cert.pem:/tls/cert.pem:ro$M" \
  docker.io/hashicorp/vault:1.18.5 vault agent -config=/agent.hcl >/dev/null

for _ in $(seq 1 30); do
  [ -s "$WORK/out/config.ini" ] && break; sleep 2
done
if [ ! -s "$WORK/out/config.ini" ]; then
  echo "the agent rendered nothing within 60s. Its log:" >&2
  $ENGINE logs --tail 5 vault-agent >&2
  exit 1
fi
echo "agent up; rendered:"
sed 's/^/  /' "$WORK/out/config.ini"
