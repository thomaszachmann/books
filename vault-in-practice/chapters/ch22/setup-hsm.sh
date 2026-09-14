#!/usr/bin/env bash
# Chapter 22 - an unsealer that unseals itself: OpenBao behind a PKCS#11
# seal, with SoftHSM standing in for the hardware.
#
# Order matters and is the first thing that differs from Vault Enterprise:
# OpenBao does not create the wrapping key for you. The key must exist in
# the HSM BEFORE `operator init`, or init fails half-way and leaves the
# storage in a state you can only wipe. reproduce-errors-hsm.sh shows it.
set -euo pipefail
cd "$(dirname "$0")/../.."

# Three compose files share one project; without this, each one calls
# the others' containers orphans.
export COMPOSE_IGNORE_ORPHANS=1

COMPOSE="docker compose -f docker-compose.yml -f docker-compose.hsm.yml"
HSM=chapters/ch22/hsm
LIB=/usr/lib/softhsm/libsofthsm2.so

# The container runs as uid 100. Git does not track empty directories, so
# create them here, writable - the same trick the Chapter 20 lab uses.
mkdir -p $HSM/tokens $HSM/data
chmod 777 $HSM/tokens $HSM/data

$COMPOSE build openbao-hsm

# 1. A token in the HSM. On real hardware this is the vendor's
#    initialisation procedure; on SoftHSM it is one command. The SO-PIN
#    administers the token, the user PIN is what OpenBao logs in with.
if [ -z "$(ls -A $HSM/tokens 2>/dev/null)" ]; then
  $COMPOSE run --rm --no-deps --entrypoint softhsm2-util openbao-hsm \
    --init-token --free --label openbao --so-pin 0000 --pin 1234
fi

# 2. The wrapping key, generated INSIDE the HSM. Note the attributes
#    pkcs11-tool prints back: "never extractable, local". The key was
#    born in the HSM and cannot leave it. That sentence is the whole
#    reason HSMs exist.
$COMPOSE run --rm --no-deps --entrypoint pkcs11-tool openbao-hsm \
  --module $LIB --token-label openbao --login --pin 1234 \
  --list-objects 2>/dev/null | grep -q "label:.*openbao-unseal" || \
$COMPOSE run --rm --no-deps --entrypoint pkcs11-tool openbao-hsm \
  --module $LIB --token-label openbao --login --pin 1234 \
  --keygen --key-type aes:32 --label openbao-unseal --id 01 2>/dev/null

$COMPOSE run --rm --no-deps --entrypoint pkcs11-tool openbao-hsm \
  --module $LIB --token-label openbao --login --pin 1234 \
  --list-objects 2>/dev/null | grep -E "label|Access"

# 3. Start it. It comes up sealed and uninitialised - the seal type in
#    the banner is the thing to look at.
$COMPOSE up -d openbao-hsm
sleep 5
docker logs --since 8s openbao-hsm 2>&1 | grep -E "Auto Seal|Cgo" | sed 's/^ *//'

export BAO_ADDR="${BAO_HSM_ADDR:-http://127.0.0.1:8400}"

# No bao CLI on this machine? The one in the container will do.
if ! command -v bao >/dev/null 2>&1; then
  bao() { docker exec -i -e BAO_ADDR=http://127.0.0.1:8200 -e BAO_TOKEN="${BAO_TOKEN:-}" openbao-hsm bao "$@"; }
fi

# 4. Initialise. There are no unseal keys in the output - only recovery
#    keys, and Chapter 22 has already shown what those can and cannot do.
if [ ! -f $HSM/init.json ]; then
  bao operator init -recovery-shares=1 -recovery-threshold=1 \
    -format=json > $HSM/init.json
  chmod 600 $HSM/init.json
fi
export BAO_TOKEN
BAO_TOKEN=$(jq -r .root_token $HSM/init.json)
sleep 2
bao status | grep -E "Seal Type|Recovery Seal|Sealed"

# 5. The same three things the Chapter 18 unsealer needed. Nothing about
#    the transit side changes because the seal underneath it did.
bao secrets enable transit 2>/dev/null || true
bao read transit/keys/vault-unseal >/dev/null 2>&1 || \
  bao write -f transit/keys/vault-unseal >/dev/null
bao policy write vault-unseal - <<'POL'
path "transit/encrypt/vault-unseal" {
  capabilities = ["update"]
}
path "transit/decrypt/vault-unseal" {
  capabilities = ["update"]
}
POL
TOKEN=$(bao token create -policy=vault-unseal -period=24h \
  -format=json | jq -r '.auth.client_token')
echo "$TOKEN" > chapters/ch22/.unseal-token-hsm
chmod 600 chapters/ch22/.unseal-token-hsm

echo
echo "The unsealer is running, HSM-sealed, and holds a transit key."
echo "Restart it and nobody has to do anything:"
echo "  docker compose -f docker-compose.yml -f docker-compose.hsm.yml restart openbao-hsm"
echo "next: ./chapters/ch22/migrate-to-hsm-unsealer.sh"
