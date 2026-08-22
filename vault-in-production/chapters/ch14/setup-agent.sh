#!/usr/bin/env bash
# AppRole, ein Geheimnis und ein Agent-Container auf dem
# Labor-Netz. Voraussetzung: . ./scripts/vault-env.sh eingelesen,
# Cluster entsiegelt.
set -euo pipefail

cd "$(dirname "$0")/../.."
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

# Kurze Token-TTL mit Absicht: der Ausfall im Labor dauert
# laenger, und genau das soll der Datei nichts ausmachen.
vault write auth/approle/role/app token_policies=app-read \
  token_ttl=2m token_max_ttl=10m >/dev/null

mkdir -p "$WORK/out" "$WORK/tmpl"
vault read -field=role_id auth/approle/role/app/role-id > "$WORK/role_id"
vault write -f -field=secret_id \
  auth/approle/role/app/secret-id > "$WORK/secret_id"
cp "$HERE/agent.hcl"     "$WORK/agent.hcl"
cp "$HERE/config.ctmpl"  "$WORK/tmpl/config.ctmpl"
chmod -R a+rX "$WORK"

$ENGINE rm -f vault-agent >/dev/null 2>&1 || true
$ENGINE run -d --name vault-agent --network "$NET" \
  -v "$WORK/agent.hcl:/agent.hcl:ro" \
  -v "$WORK/tmpl:/tmpl:ro" \
  -v "$WORK/out:/out" \
  -v "$WORK/role_id:/creds/role_id:ro" \
  -v "$WORK/secret_id:/creds/secret_id:ro" \
  -v "$PWD/cluster/tls/cert.pem:/tls/cert.pem:ro" \
  hashicorp/vault:1.18 vault agent -config=/agent.hcl >/dev/null

for _ in $(seq 1 30); do
  [ -s "$WORK/out/config.ini" ] && break; sleep 2
done
echo "agent up; rendered:"
sed 's/^/  /' "$WORK/out/config.ini"
