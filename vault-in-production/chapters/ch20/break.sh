#!/usr/bin/env bash
# Chapter 20, Break it on purpose: the two mistakes that stop an
# HSM-sealed OpenBao before it serves anything. Run after bench.sh,
# which leaves the image and a working token directory behind.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/engine.sh

IMG=localhost/openbao-softhsm:2.6.2
W=${WORK:-/tmp/hsm-bench}
M=${VAULT_MOUNT_OPT:-}
LIB=/usr/lib/softhsm/libsofthsm2.so
NET=hsm-bench

seal() {  # seal <pin> <key label>
  cat > "$W/break.hcl" <<HCL
storage "raft" {
  path    = "/openbao/data"
  node_id = "break"
}
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true
}
api_addr     = "http://bao-break:8200"
cluster_addr = "http://bao-break:8201"
seal "pkcs11" {
  lib         = "$LIB"
  token_label = "openbao"
  pin         = "$1"
  key_label   = "$2"
  mechanism   = "0x1087"
}
HCL
}
start() {  # start <data dir name>: a fresh directory every time
  $ENGINE rm -f bao-break >/dev/null 2>&1
  mkdir -p "$W/$1"; chmod 777 "$W/$1"
  $ENGINE run -d --name bao-break --network "$NET" \
    -v "$W/break.hcl:/cfg.hcl:ro$M" -v "$W/$1:/openbao/data:rw$M" \
    -v "$W/tokens:/var/lib/softhsm/tokens:rw$M" \
    "$IMG" bao server -config=/cfg.hcl >/dev/null
  sleep 5
}
say() { $ENGINE logs bao-break 2>&1 | grep -E '^Error|\[ERROR\]' \
          | head -2 | cut -c1-200 | fold -s -w 64 | sed 's/^/  /'; }

echo "== 1. the wrong PIN"
seal 9999 openbao-unseal; start break-pin
echo "  container: $($ENGINE inspect -f '{{.State.Status}}' bao-break)"; say

echo "== 2. a key label that is not in the HSM, then init"
seal 1234 no-such-key; start break-key
echo "  container: $($ENGINE inspect -f '{{.State.Status}}' bao-break)"; say
$ENGINE exec bench-client curl -s -X PUT \
  -d '{"recovery_shares":1,"recovery_threshold":1}' \
  http://bao-break:8200/v1/sys/init | jq -c . | cut -c1-200
echo "  after init:"
$ENGINE exec bench-client curl -s http://bao-break:8200/v1/sys/seal-status \
  | jq -c '{initialized,sealed,type}'
$ENGINE rm -f bao-break >/dev/null 2>&1
