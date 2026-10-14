#!/usr/bin/env bash
# Where the time goes - in the order the causes actually occur.
# Chapter 19.
#
# IMPORTANT, about method: a loop around the CLI measures nothing.
# Starting the Go binary costs ~318ms, more than any effect this
# script finds. Hence raw HTTP - and in ONE curl call with a
# repeated URL, so the connection is reused. Otherwise you measure
# a TLS handshake per request instead of Vault.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1

CA=${CA:-cluster/tls/cert.pem}
N=${N:-100}
T=${VAULT_TOKEN:-$(jq -r .root_token cluster/init.json)}

port_of_leader(){
  for p in 8210 8220 8230; do
    if curl -s --cacert "$CA" "https://127.0.0.1:$p/v1/sys/health" \
       2>/dev/null | jq -e '.standby == false' >/dev/null 2>&1
    then echo "$p"; return; fi
  done
  echo 8210
}
# The node to compare with must be an UNSEALED standby. A sealed
# node answers very fast, with an error - in the first attempt the
# "standby" therefore seemed to read faster than the leader, and the
# forwarding metric was missing, because a sealed node does not
# export it at all.
port_of_standby(){
  for p in 8210 8220 8230; do
    [ "$p" = "$1" ] && continue
    if curl -s --cacert "$CA" "https://127.0.0.1:$p/v1/sys/health" \
       2>/dev/null | jq -e '.standby == true and .sealed == false' \
       >/dev/null 2>&1
    then echo "$p"; return; fi
  done
}
L=$(port_of_leader); S=$(port_of_standby "$L")
if [ -z "$S" ]; then
  echo "ABORT: no unsealed standby. Run 'make unseal' and try" \
       "again - otherwise section 2 measures a sealed node and" \
       "reports it as fast." >&2
  exit 1
fi
echo "leader $L, unsealed standby for comparison: $S"

rep(){ local u=$1 n=$2 out=""
       for _ in $(seq 1 "$n"); do out="$out $u"; done; echo "$out"; }

run(){ # $1 label  $2 url  $3.. extra curl args
  local label=$1 url=$2; shift 2
  local best=9999999
  for _ in 1 2 3; do
    s=$(date +%s%N)
    # shellcheck disable=SC2046  # one URL per word, on purpose
    curl -s --cacert "$CA" -H "X-Vault-Token: $T" "$@" \
      $(rep "$url" "$N") >/dev/null
    v=$(( ($(date +%s%N)-s)/1000000 ))
    [ "$v" -lt "$best" ] && best=$v
  done
  printf '  %-30s %6.2f ms/op  (best of 3)\n' \
    "$label" "$(awk -v b="$best" -v n="$N" 'BEGIN{print b/n}')"
}

# A fresh lab has no KV mount. Without one every write below fails
# fast, and a failing write is cheaper than a read - the first run
# of this script reported exactly that.
vault secrets enable -path=secret -version=2 kv >/dev/null 2>&1 || true

echo
echo "== 0. what does the harness itself cost =="
U="https://127.0.0.1:$L/v1/secret/data/perf/a"
curl -s --cacert "$CA" -H "X-Vault-Token: $T" -X POST \
  -d '{"data":{"v":"1"}}' "$U" >/dev/null 2>&1
s=$(date +%s%N)
vault kv get secret/perf/a >/dev/null
echo "  one KV read via the CLI           $(( ($(date +%s%N)-s)/1000000 ))ms"
s=$(date +%s%N)
for _ in $(seq 1 50); do
  curl -s -o /dev/null --cacert "$CA" -H "X-Vault-Token: $T" "$U"
done
echo "  50 reads, a new connection each   $(( ($(date +%s%N)-s)/50000000 ))ms each"
s=$(date +%s%N)
# shellcheck disable=SC2046
curl -s -o /dev/null --cacert "$CA" -H "X-Vault-Token: $T" \
  $(rep "$U" 50) >/dev/null
echo "  50 reads, one connection reused   $(( ($(date +%s%N)-s)/50000000 ))ms each"
curl -s -o /dev/null --cacert "$CA" -H "X-Vault-Token: $T" \
  -w '  one fresh read: connect %{time_connect}s  tls %{time_appconnect}s  total %{time_total}s\n' \
  "$U"

echo
echo "== 1. reads vs writes on the leader =="
curl -s --cacert "$CA" -H "X-Vault-Token: $T" -X POST \
  -d '{"data":{"v":"1"}}' \
  "https://127.0.0.1:$L/v1/secret/data/perf/a" >/dev/null 2>&1
run "sys/health (no storage)" "https://127.0.0.1:$L/v1/sys/health"
run "KV read" "https://127.0.0.1:$L/v1/secret/data/perf/a"
run "KV write" "https://127.0.0.1:$L/v1/secret/data/perf/w" \
    -X POST -d '{"data":{"v":"1"}}'

echo
echo "== 2. does a standby serve reads, or forward them? =="
fwd(){ curl -s --cacert "$CA" \
  "https://127.0.0.1:$S/v1/sys/metrics?format=prometheus" \
  | grep '^vault_ha_rpc_client_forward_count' | awk '{print $2}'; }
before=$(fwd)
# shellcheck disable=SC2046
curl -s --cacert "$CA" -H "X-Vault-Token: $T" \
  $(rep "https://127.0.0.1:$S/v1/secret/data/perf/a" 25) >/dev/null
sleep 3
echo "  forward_count on the standby: ${before:-0} -> $(fwd)  (after 25 reads)"
run "KV read via standby" "https://127.0.0.1:$S/v1/secret/data/perf/a"

echo
echo "== 3. payload size =="
for sz in 100 10000 100000; do
  v=$(head -c "$sz" /dev/zero | tr '\0' 'x')
  run "write ${sz} bytes" \
      "https://127.0.0.1:$L/v1/secret/data/sz$sz" \
      -X POST -d "{\"data\":{\"v\":\"$v\"}}"
done

echo
echo "== 4. policies per token =="
for i in $(seq 1 60); do
  vault policy write "p-$i" - >/dev/null <<POL
path "secret/data/p$i/*" { capabilities = ["read"] }
POL
done
vault policy write perf-read - >/dev/null <<'POL'
path "secret/data/perf/*" { capabilities = ["read"] }
POL
pols=""; for i in $(seq 1 60); do pols="$pols -policy=p-$i"; done
T2=$(vault token create -field=token -policy=perf-read)
# shellcheck disable=SC2086  # one flag per word, on purpose
T62=$(vault token create -field=token -policy=perf-read $pols)
TC=$(vault token create -field=token -policy="p-1,p-2,p-3")
npol(){ VAULT_TOKEN=$1 vault token lookup -format=json \
         | jq -c '.data.policies'; }
echo "  -policy=perf-read             -> $(npol "$T2" | jq length) policies"
echo "  -policy=perf-read -policy=... -> $(npol "$T62" | jq length) policies"
echo "  -policy=\"p-1,p-2,p-3\"         -> $(npol "$TC")"
ROOT_T=$T
# Best of three is too coarse for an effect of a millisecond or two.
# Five runs of 200 reads per token, alternating, and the median.
U="https://127.0.0.1:$L/v1/secret/data/perf/a"
five(){ # five <token>: prints the five totals in ms
  local r=""
  for _ in 1 2 3 4 5; do
    s=$(date +%s%N)
    # shellcheck disable=SC2046  # one URL per word, on purpose
    curl -s -o /dev/null --cacert "$CA" -H "X-Vault-Token: $1" \
      $(rep "$U" 200) >/dev/null
    r="$r $(( ($(date +%s%N)-s)/1000000 ))"
  done; echo "$r"; }
a2=$(five "$T2"); a62=$(five "$T62")
med(){ printf '%s\n' $1 | sort -n | sed -n 3p; }
printf '   2 policies: %s ms   median %s ms/request\n' "$a2" \
  "$(awk -v m="$(med "$a2")" 'BEGIN{printf "%.2f", m/200}')"
printf '  62 policies: %s ms   median %s ms/request\n' "$a62" \
  "$(awk -v m="$(med "$a62")" 'BEGIN{printf "%.2f", m/200}')"
T=$ROOT_T

echo
echo "== 5. the identity store =="
made=0
for _ in 1 2 3 4 5; do
  # One config block per request. Options do not carry across
  # "next", so every block repeats them; without "next" curl sends
  # one body to the last URL and the store stays nearly empty.
  for i in $(seq $((made + 1)) $((made + 600))); do
    printf 'url = "https://127.0.0.1:%s/v1/identity/entity"\n' "$L"
    printf 'cacert = "%s"\nheader = "X-Vault-Token: %s"\n' "$CA" "$T"
    printf 'data = "{\\"name\\":\\"e%s\\"}"\n' "$i"
    printf 'silent\noutput = "/dev/null"\n'
    [ "$i" -lt $((made + 600)) ] && printf 'next\n'
  done | curl -K - >/dev/null
  made=$((made + 600))
  run "KV read, $made entities" "https://127.0.0.1:$L/v1/secret/data/perf/a"
done
s=$(date +%s%N)
n=$(curl -s --cacert "$CA" -H "X-Vault-Token: $T" -X LIST \
      "https://127.0.0.1:$L/v1/identity/entity/id" | jq '.data.keys | length')
echo "  list all $n entities: $(( ($(date +%s%N)-s)/1000000 ))ms (new connection)"
s=$(date +%s%N)
curl -s -o /dev/null --cacert "$CA" -H "X-Vault-Token: $T" \
  "https://127.0.0.1:$L/v1/secret/data/perf/a"
echo "  one KV read:          $(( ($(date +%s%N)-s)/1000000 ))ms (new connection)"

cat <<'TXT'

  The order to search in, not the order of the guesses:
    1 connection reuse in the client
    2 read or write (factor ~8)
    3 does the client talk to a standby (factor ~2, no capacity)
    4 logins per request - every login is a write
    5 policies per token (~24us per policy)
    6 payload (only from ~10 KB)
    7 the disk - last, not first
TXT
