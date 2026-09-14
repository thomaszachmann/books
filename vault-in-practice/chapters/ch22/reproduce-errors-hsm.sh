#!/usr/bin/env bash
# Chapter 22 - the PKCS#11 failures, on purpose.
#
# Needs the HSM unsealer from the chapter:  ./chapters/ch22/setup-hsm.sh
# Every case restores what it broke. The last one works on a throwaway
# copy, because it cannot be undone.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

# Three compose files share one project; without this, each one calls
# the others' containers orphans.
export COMPOSE_IGNORE_ORPHANS=1
. ./scripts/wwr-lib.sh

COMPOSE="docker compose -f docker-compose.yml -f docker-compose.hsm.yml"
HSM=chapters/ch22/hsm
CFG=$HSM/config/openbao-hsm.hcl
LIB=/usr/lib/softhsm/libsofthsm2.so
export BAO_ADDR="${BAO_HSM_ADDR:-http://127.0.0.1:8400}"
if ! command -v bao >/dev/null 2>&1; then
  bao() { docker exec -i -e BAO_ADDR=http://127.0.0.1:8200 openbao-hsm bao "$@"; }
fi

restart_and_log() {   # restart the unsealer, print what the seal said
  local since; since=$(date -u +%FT%TZ)
  $COMPOSE restart openbao-hsm >/dev/null 2>&1
  sleep 5
  docker logs --since "$since" openbao-hsm 2>&1 | grep -v "HSM distribution" \
    | grep -i -E "error|failed|unsealed" | grep -v "HA lock\|raft-net\|Raft RPC" \
    | sed 's/^[0-9TZ:.-]* */  /' | awk '!seen[$0]++' | head -4
}

# A seal is validated AFTER storage opens. To see the seal's error, the
# throwaway container needs an (empty) data directory too.
scratch_data() { local d; d=$(mktemp -d); chmod 777 "$d"; echo "$d"; }
scratch_rm()   { docker run --rm -v "$1:/t:z" docker.io/library/alpine:3.20 sh -c 'rm -rf /t/*' >/dev/null 2>&1; rmdir "$1" 2>/dev/null; }

wwr_case "which seal is actually in force"
bao status 2>/dev/null | grep -E "Seal Type|Recovery Seal|Sealed" | sed 's/^/  /'
docker logs openbao-hsm 2>&1 | grep "Auto Seal" | tail -1 | sed 's/^ */  /'

wwr_case "the discontinuation warning, and what it does not mean"
docker logs openbao-hsm 2>&1 | grep -m1 "HSM distribution" | sed 's/^[0-9TZ:.-]* //' | fold -s -w 76 | sed 's/^/  /'
echo "  PKCS#11 support is not going away; the way it is shipped is. From"
echo "  2.7 the seal is an external KMS plugin with the same stanza."

wwr_case "CKR_PIN_INCORRECT"
sed -i.bak 's/pin         = "1234"/pin         = "9999"/' $CFG
restart_and_log
mv $CFG.bak $CFG

wwr_case "failed to find token with label"
echo "The token directory is the HSM's state. Start without it mounted -"
echo "or with an empty one after a careless restore - and:"
D=$(scratch_data)
docker run --rm -v "$PWD/$HSM/config:/openbao/config:ro,z" -v "$D:/openbao/data:z" \
  localhost/openbao-softhsm:2.6.2 bao server -config=/openbao/config/openbao-hsm.hcl 2>&1 \
  | grep -v "HSM distribution" | grep -i "error" | sed 's/^/  /' | head -2
scratch_rm "$D"

wwr_case "this build of OpenBao has PKCS#11 disabled"
echo "Same config, the default image instead of the HSM one:"
D=$(scratch_data)
docker run --rm -v "$PWD/$HSM/config:/openbao/config:ro,z" -v "$D:/openbao/data:z" \
  docker.io/openbao/openbao:2.6.2 bao server -config=/openbao/config/openbao-hsm.hcl 2>&1 \
  | grep -i "error" | sed 's/^/  /' | head -2
scratch_rm "$D"

wwr_case "wrong key_label after init: it starts, and that is the problem"
sed -i.bak 's/key_label   = "openbao-unseal"/key_label   = "nope"/' $CFG
restart_and_log
bao status 2>/dev/null | grep -E "Sealed" | sed 's/^/  /'
mv $CFG.bak $CFG
echo "  Sealed false. The stored root key names the key it was wrapped"
echo "  with, and OpenBao decrypts with that one. The configured label"
echo "  is only used to RE-wrap, which fails - as the warning says. The"
echo "  misconfiguration surfaces at the next rotation, not at startup."
$COMPOSE restart openbao-hsm >/dev/null 2>&1; sleep 4

wwr_case "init before the key exists - OpenBao does not create it for you"
echo "On a throwaway token directory and storage, so the real unsealer"
echo "is untouched:"
TMP=$(mktemp -d); mkdir -p "$TMP/tokens" "$TMP/data"; chmod 777 "$TMP/tokens" "$TMP/data"
docker run --rm -v "$TMP/tokens:/var/lib/softhsm/tokens:z" --entrypoint softhsm2-util \
  localhost/openbao-softhsm:2.6.2 --init-token --free --label openbao --so-pin 0000 --pin 1234 >/dev/null
docker run -d --name openbao-hsm-doomed -v "$PWD/$HSM/config:/openbao/config:ro,z" \
  -v "$TMP/tokens:/var/lib/softhsm/tokens:z" -v "$TMP/data:/openbao/data:z" \
  localhost/openbao-softhsm:2.6.2 bao server -config=/openbao/config/openbao-hsm.hcl >/dev/null
sleep 4
printf '$ bao operator init\n'
docker exec -e BAO_ADDR=http://127.0.0.1:8200 openbao-hsm-doomed \
  bao operator init -recovery-shares=1 -recovery-threshold=1 2>&1 | grep '^\*' | sed 's/^/  /'
printf '$ bao operator init   (again, after creating the key)\n'
docker run --rm -v "$TMP/tokens:/var/lib/softhsm/tokens:z" --entrypoint pkcs11-tool \
  localhost/openbao-softhsm:2.6.2 --module $LIB --token-label openbao --login --pin 1234 \
  --keygen --key-type aes:32 --label openbao-unseal --id 01 >/dev/null 2>&1
docker restart openbao-hsm-doomed >/dev/null; sleep 4
docker exec -e BAO_ADDR=http://127.0.0.1:8200 openbao-hsm-doomed \
  bao operator init -recovery-shares=1 -recovery-threshold=1 2>&1 | grep '^\*' | sed 's/^/  /'
docker exec -e BAO_ADDR=http://127.0.0.1:8200 openbao-hsm-doomed bao status 2>&1 \
  | grep -E "Initialized|Sealed" | sed 's/^/  /'
echo "  Initialized, sealed, and no stored key to unseal with: the barrier"
echo "  was written, the wrapped root key was not. There is nothing in"
echo "  this storage worth keeping. Wipe it and initialise again - with"
echo "  the key in place first."
docker rm -f openbao-hsm-doomed >/dev/null 2>&1
docker run --rm -v "$TMP:/t:z" docker.io/library/alpine:3.20 rm -rf /t/tokens /t/data >/dev/null 2>&1
rm -rf "$TMP"

echo; echo "All cases produced on purpose. The unsealer is back to normal."
