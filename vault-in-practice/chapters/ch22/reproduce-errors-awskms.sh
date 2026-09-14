#!/usr/bin/env bash
# Chapter 22 - the KMS failures, on purpose.
#
# Needs Vault on the awskms seal:
#   ./chapters/ch22/setup-moto.sh && ./chapters/ch22/migrate-to-awskms.sh
# Every case restores what it broke, except the last, which runs on a
# throwaway Vault because there is no restoring it.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

# Three compose files share one project; without this, each one calls
# the others' containers orphans.
export COMPOSE_IGNORE_ORPHANS=1
. ./scripts/wwr-lib.sh
wwr_env

COMPOSE="docker compose -f docker-compose.yml -f docker-compose.awskms.yml"
AWS="$COMPOSE run --rm aws"
CFG=config/vault.hcl

seal_type=$(vault status -format=json 2>/dev/null | jq -r '.type // "shamir"')
wwr_case "which seal is actually in force"
vault status -format=json 2>/dev/null \
  | jq -r '"  seal type          : \(.type)\n  recovery seal type : \(.recovery_seal_type // "-")\n  sealed             : \(.sealed)"'
if [ "$seal_type" != "awskms" ]; then
  echo; echo "Not on awskms - run the chapter's migration first."; exit 1
fi

vault_log() { docker logs --since "${1:-8}s" vault 2>&1 | grep -v "^\s*$" | grep -i -E "error|fail|warn" | grep -v "HA lock" | sed 's/^[0-9TZ:.-]* */  /' | awk '!seen[$0]++' | head -3; }
restart_vault() { docker compose restart vault >/dev/null 2>&1; sleep "${1:-6}"; }

wwr_case "the warning at every start that means nothing"
docker logs --since 1h vault 2>&1 | grep -m1 "no key-id in common" | sed 's/^[0-9TZ:.-]* */  /'
echo "  DescribeKey reports the bare key id; the ciphertext carries the"
echo "  ARN. They never match, Vault tries every healthy seal (there is"
echo "  one), succeeds, and logs this. Benign - and worth recognising,"
echo "  because it looks like the real failures below."

wwr_case "NotFoundException: the alias is not there (wrong key, or wrong region)"
sed -i.bak 's#alias/vault-unseal#alias/does-not-exist#' $CFG
restart_vault 5; vault_log 8
docker inspect vault -f '  vault: {{.State.Status}}'
mv $CFG.bak $CFG
echo "  The process exits. A wrong region produces the same exception with"
echo "  the wrong region in the ARN - read the ARN, not just the message."
docker compose start vault >/dev/null 2>&1; sleep 5

wwr_case "RequestError: send request failed - nothing answers at the endpoint"
echo "The endpoint moved to a port where nothing listens. (Not by stopping"
echo "moto: that would delete the key, which is the last case.)"
sed -i.bak 's#http://moto:5000#http://moto:5001#' $CFG
restart_vault 5; vault_log 8
echo "  Vault exits at once: it validates the seal before it listens."
mv $CFG.bak $CFG
docker compose start vault >/dev/null 2>&1; sleep 6
vault status 2>/dev/null | grep Sealed | sed 's/^/  /'

wwr_case "the KMS is reachable but does not answer"
$COMPOSE pause moto >/dev/null 2>&1
restart_vault 12
docker inspect vault -f '  vault: {{.State.Status}}'
curl -s -m 3 -o /dev/null -w '  health endpoint: HTTP %{http_code}\n' --cacert "$VAULT_CACERT" "$VAULT_ADDR/v1/sys/health" || echo "  health endpoint: no answer"

echo "  No exit and no unseal: Vault is waiting on the KMS call. The"
echo "  process is up, the health endpoint is not. Unpause:"
$COMPOSE unpause moto >/dev/null 2>&1; sleep 8
vault status 2>/dev/null | grep Sealed | sed 's/^/  /'

wwr_case "a key you cannot use: disabled, or pending deletion"
KEY=$(cat chapters/ch22/.kms-key-id)
$AWS kms disable-key --key-id "$KEY" >/dev/null 2>&1
$AWS kms describe-key --key-id "$KEY" --query 'KeyMetadata.KeyState' --output text | sed 's/^/  KeyState: /'
restart_vault 5
vault status 2>/dev/null | grep Sealed | sed 's/^/  /'
$AWS kms enable-key --key-id "$KEY" >/dev/null 2>&1
echo "  Not reproduced: moto does not enforce key state. AWS does. A"
echo "  disabled key returns DisabledException; a key scheduled for"
echo "  deletion returns KMSInvalidStateException - for the whole waiting"
echo "  period, which is the point of the waiting period. Cancel the"
echo "  deletion and Vault starts again; let it expire and read the last"
echo "  case."

wwr_case "rotating to a new CMK is a config change, not a migration"
KEY2=$($AWS kms create-key --query KeyMetadata.KeyId --output text | tr -d '\r')
$AWS kms create-alias --alias-name alias/vault-unseal-next --target-key-id "$KEY2" >/dev/null 2>&1
sed -i.bak 's#alias/vault-unseal"#alias/vault-unseal-next"#' $CFG
restart_vault 6
docker logs --since 8s vault 2>&1 | grep -i "upgrading" | sed 's/^[0-9TZ:.-]* */  /'
echo "  Decrypt needs no key id - the ciphertext names the old key - so"
echo "  Vault reads the root key with the old CMK and re-wraps it under"
echo "  the new one at start. What it needs at that moment: decrypt on"
echo "  the OLD key and encrypt on the new. Revoke the old one the day"
echo "  before, and this is a Vault that never starts."
mv $CFG.bak $CFG
restart_vault 6
docker logs --since 8s vault 2>&1 | grep -i "upgrading" | sed 's/^[0-9TZ:.-]* */  /'
vault status 2>/dev/null | grep Sealed | sed 's/^/  /'

wwr_case "the key is gone - on a throwaway Vault, because there is no way back"
echo "A second moto, so the lab's key is not touched; a second Vault, so"
echo "the lab's Vault is not either."
TMP=$(mktemp -d); mkdir -p "$TMP/config" "$TMP/data"; chmod 777 "$TMP/data"
NET=$(docker inspect vault -f '{{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}}')
docker run -d --name moto-doomed --network "$NET" docker.io/motoserver/moto:5.2.3 >/dev/null
sleep 3
KEY3=$(docker run --rm --network "$NET" -e AWS_ACCESS_KEY_ID=test -e AWS_SECRET_ACCESS_KEY=test \
  -e AWS_DEFAULT_REGION=eu-central-1 -e AWS_ENDPOINT_URL=http://moto-doomed:5000 \
  docker.io/amazon/aws-cli:2.36.44 kms create-key --query KeyMetadata.KeyId --output text | tr -d '\r')
cat > "$TMP/config/vault.hcl" <<CFG2
ui = false
disable_mlock = true
storage "raft" { path = "/vault/data"  node_id = "doomed" }
listener "tcp" { address = "0.0.0.0:8200"  tls_disable = true }
api_addr = "http://127.0.0.1:8200"
cluster_addr = "https://127.0.0.1:8201"
seal "awskms" {
  region = "eu-central-1"  kms_key_id = "$KEY3"  endpoint = "http://moto-doomed:5000"
  access_key = "test"  secret_key = "test"
}
CFG2
docker run -d --name vault-doomed --network "$NET" -v "$TMP/config:/vault/config:ro,z" \
  -v "$TMP/data:/vault/data:z" docker.io/hashicorp/vault:1.18 \
  vault server -config=/vault/config/vault.hcl >/dev/null
sleep 5
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault-doomed \
  vault operator init -recovery-shares=1 -recovery-threshold=1 >/dev/null 2>&1
sleep 4
docker exec -e VAULT_ADDR=http://127.0.0.1:8200 vault-doomed vault status 2>/dev/null | grep -E "^Sealed" | sed 's/^/  before: /'
echo "  Now the key is deleted. On AWS: schedule-key-deletion, then 7 to"
echo "  30 days. Here: moto keeps keys in memory, so a restart is enough."
docker restart moto-doomed >/dev/null; sleep 3
docker restart vault-doomed >/dev/null; sleep 5
docker logs --since 7s vault-doomed 2>&1 | grep -i "error" | sed 's/^/  /' | head -2
docker ps -a --format '  vault-doomed: {{.Status}}' | grep doomed | head -1
echo "  Recovery keys do not help: they are not unseal keys. A snapshot"
echo "  does not help: its root key is wrapped with the same CMK. This"
echo "  Vault, and every backup of it, is now ciphertext with no key."
docker rm -f vault-doomed moto-doomed >/dev/null 2>&1
docker run --rm -v "$TMP:/t:z" docker.io/library/alpine:3.20 rm -rf /t/data >/dev/null 2>&1
rm -rf "$TMP"

wwr_done
