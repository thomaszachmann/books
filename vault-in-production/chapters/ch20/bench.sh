#!/usr/bin/env bash
# What an HSM seal costs, measured. Chapter 20.
#
# Two single-node OpenBao servers, identical except for the seal:
# one Shamir, one PKCS#11 (SoftHSM).
#
#   ./chapters/ch20/bench.sh           # Docker or rootful podman
#
# pkcs11-spy sits between OpenBao and SoftHSM and writes down every
# PKCS#11 call. That count is what carries over to real hardware:
# SoftHSM answers in microseconds inside the process, a network HSM
# answers in a round trip per call.
set -euo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/engine.sh

IMG=localhost/openbao-softhsm:2.6.2
NET=hsm-bench
W=${WORK:-/tmp/hsm-bench}
N=${N:-200}
M=${VAULT_MOUNT_OPT:-}
LIB=/usr/lib/softhsm/libsofthsm2.so
SPY=/usr/lib/pkcs11/pkcs11-spy.so

$ENGINE image exists "$IMG" 2>/dev/null \
  || $ENGINE image inspect "$IMG" >/dev/null 2>&1 \
  || $ENGINE build -t "$IMG" chapters/ch20 >/dev/null

$ENGINE rm -f bao-shamir bao-hsm bench-client >/dev/null 2>&1 || true
$ENGINE network create "$NET" >/dev/null 2>&1 || true
rm -rf "$W" 2>/dev/null || $ENGINE run --rm -v /tmp:/t$M alpine:3.20 \
  rm -rf "/t/${W#/tmp/}"
mkdir -p "$W"/{shamir,hsm,tokens,spy}
chmod 777 "$W"/{shamir,hsm,tokens,spy}

cfg() {  # cfg <name> <seal stanza>
  cat > "$W/$1.hcl" <<HCL
storage "raft" {
  path    = "/openbao/data"
  node_id = "$1"
}
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}
api_addr     = "http://bao-$1:8200"
cluster_addr = "http://bao-$1:8201"
$2
HCL
}
cfg shamir ""
cfg hsm 'seal "pkcs11" {
  lib         = "'$SPY'"
  token_label = "openbao"
  pin         = "1234"
  key_label   = "openbao-unseal"
  mechanism   = "0x1087"
}'

ex() { $ENGINE run --rm -v "$W/tokens:/var/lib/softhsm/tokens$M" \
         --entrypoint "$1" "$IMG" "${@:2}"; }
echo "== the token and the key, created inside the HSM"
ex softhsm2-util --init-token --free --label openbao \
   --so-pin 0000 --pin 1234 >/dev/null
ex pkcs11-tool --module $LIB --token-label openbao --login --pin 1234 \
   --keygen --key-type aes:32 --label openbao-unseal --id 01 \
   2>/dev/null | grep -E "label|Access" | sed 's/^ */  /'

run() {  # run <name> [extra args]
  $ENGINE run -d --name "bao-$1" --network "$NET" --cap-add IPC_LOCK \
    -v "$W/$1.hcl:/cfg.hcl:ro$M" -v "$W/$1:/openbao/data:rw$M" \
    -v "$W/tokens:/var/lib/softhsm/tokens:rw$M" \
    -v "$W/spy:/spy:rw$M" \
    -e PKCS11SPY=$LIB -e PKCS11SPY_OUTPUT=/spy/calls.log \
    "${@:2}" "$IMG" bao server -config=/cfg.hcl >/dev/null
}
run shamir; run hsm
$ENGINE run -d --name bench-client --network "$NET" \
  docker.io/curlimages/curl:8.10.1 sleep 86400 >/dev/null

api() {  # api <node> <method> <path> [json]
  $ENGINE exec bench-client curl -s -X "$2" \
    ${TOK:+-H "X-Vault-Token: $TOK"} ${4:+-d "$4"} \
    "http://bao-$1:8200/v1/$3"
}
ready() {  # seconds until /sys/health says active, unsealed
  local t0; t0=$(date +%s.%N)
  until [ "$($ENGINE exec bench-client curl -s -o /dev/null \
      -w '%{http_code}' "http://bao-$1:8200/v1/sys/health")" = 200 ]
  do sleep 0.2; done
  awk -v a="$t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.1f", b-a}'
}
# pkcs11-spy numbers every call: "12: C_Login". The log lives on the
# host, so it survives restarts and can be cut by line number.
SPYLOG="$W/spy/calls.log"
mark()  { grep -c '^[0-9]*: C_' "$SPYLOG" 2>/dev/null || echo 0; }
since() { grep -o '^[0-9]*: C_[A-Za-z]*' "$SPYLOG" 2>/dev/null \
            | tail -n +"$(( $1 + 1 ))"; }
calls() { since "$1" | wc -l | tr -d ' '; }
sleep 3

echo "== initialise both"
SH=$(api shamir PUT sys/init '{"secret_shares":1,"secret_threshold":1}')
KEY=$(printf '%s' "$SH" | jq -r '.keys_base64[0]')
api shamir PUT sys/unseal "{\"key\":\"$KEY\"}" >/dev/null
c0=$(mark)
HS=$(api hsm PUT sys/init '{"recovery_shares":1,"recovery_threshold":1}')
echo "  PKCS#11 calls during init: $(calls "$c0")"
echo "  shamir ready after $(ready shamir)s, hsm after $(ready hsm)s"

for n in shamir hsm; do
  if [ $n = shamir ]; then TOK=$(printf '%s' "$SH" | jq -r .root_token)
  else TOK=$(printf '%s' "$HS" | jq -r .root_token); fi
  api $n POST sys/mounts/kv '{"type":"kv","options":{"version":"2"}}' \
    >/dev/null
  api $n POST kv/data/probe '{"data":{"v":"x"}}' >/dev/null
  eval "TOK_$n=\$TOK"
done

lat() {  # lat <node> <GET|POST>: median and p95 over N requests,
         # one connection, so the numbers are Vault, not TLS or CLI
  local tok; eval "tok=\$TOK_$1"
  local body=(); [ "$2" = POST ] && body=(-d '{"data":{"v":"y"}}')
  local urls; urls=$(for _ in $(seq 1 "$N"); do
    printf 'url = "http://bao-%s:8200/v1/kv/data/probe"\n' "$1"
  printf 'output = "/dev/null"\n'; done)
  printf '%s\n' "$urls" | $ENGINE exec -i bench-client curl -s -K - \
    -X "$2" -H "X-Vault-Token: $tok" "${body[@]}" \
    -w '%{time_total}\n' \
  | sort -n | awk '{a[NR]=$1} END{printf "median %.2f ms  p95 %.2f ms",
      a[int(NR/2)]*1000, a[int(NR*0.95)]*1000}'
}
echo "== $N requests each, one connection"
c0=$(mark)
for n in shamir hsm; do
  echo "  $n  read   $(lat $n GET)"
  echo "  $n  write  $(lat $n POST)"
done
echo "  PKCS#11 calls during all $((4 * N)) requests: $(calls "$c0")"

echo "== restart to ready, three times each"
for _ in 1 2 3; do
  c0=$(mark)
  $ENGINE restart bao-hsm >/dev/null
  echo "  hsm     $(ready hsm)s, nobody involved," \
       "PKCS#11 calls: $(calls "$c0")"
done
for _ in 1 2 3; do
  $ENGINE restart bao-shamir >/dev/null
  t0=$(date +%s.%N)
  until api shamir GET sys/seal-status >/dev/null 2>&1; do sleep 0.2; done
  api shamir PUT sys/unseal "{\"key\":\"$KEY\"}" >/dev/null
  ready shamir >/dev/null
  echo "  shamir  $(awk -v a="$t0" -v b="$(date +%s.%N)" \
    'BEGIN{printf "%.1f", b-a}')s with the key already in hand" \
    "(the human is not in this number)"
done
echo "== which calls one restart makes"
since "$c0" | awk '{print $2}' | sort | uniq -c | sort -rn | sed 's/^/  /'

echo "== the HSM goes away while the node runs"
# SoftHSM's state is the token directory. Taking it away is the
# closest a software HSM comes to a network HSM going dark.
chmod 000 "$W/tokens"
# shellcheck disable=SC2154  # set by eval above
TOK=$TOK_hsm
echo "  read while the token is gone: $(api hsm GET kv/data/probe \
  | jq -r '.data.data.v // .errors[0]')"
$ENGINE restart bao-hsm >/dev/null; sleep 8
echo "  after a restart: $(api hsm GET sys/seal-status 2>/dev/null \
  | jq -c '{sealed,type}' 2>/dev/null || echo 'no answer')" \
  "- container $($ENGINE inspect -f '{{.State.Status}}' bao-hsm)"
$ENGINE logs --tail 3 bao-hsm 2>&1 | grep -E '^Error' \
  | fold -s -w 64 | sed 's/^/  /'
echo "  exit code $($ENGINE inspect -f '{{.State.ExitCode}}' bao-hsm):" \
     "not sealed and waiting - not running at all"
chmod 777 "$W/tokens" 2>/dev/null || true
echo "Clean up:  $ENGINE rm -f bao-shamir bao-hsm bench-client;" \
     "$ENGINE network rm $NET"
