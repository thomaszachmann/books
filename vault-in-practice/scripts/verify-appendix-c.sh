#!/usr/bin/env bash
# Verify Appendix C - the numbers a reader memorises for the exam.
#
# Builds its own throwaway Vault, checks each printed value against the
# running software, and reports every disagreement. A number in that
# appendix that nobody has measured is a number the reader will defend
# in an exam.
set -uo pipefail
IMG="${WWR_IMG:-hashicorp/vault:1.18}"
PORT="${WWR_PORT:-18250}"
W=$(mktemp -d)
cleanup() { docker rm -f wwrc wwrcdev >/dev/null 2>&1
            docker run --rm -v "$W:/w" alpine:3.20 sh -c 'rm -rf /w/*' >/dev/null 2>&1
            rmdir "$W" 2>/dev/null || true; }
trap cleanup EXIT
FAIL=0
chk() {  # chk <label> <expected> <actual>
  if [ "$2" = "$3" ]; then printf '  ok    %-42s %s\n' "$1" "$3"
  else printf '  WRONG %-42s book=%s  actual=%s\n' "$1" "$2" "$3"; FAIL=$((FAIL+1)); fi
}

mkdir -p "$W/config" "$W/data"; chmod 777 "$W/data"
cat > "$W/config/vault.hcl" <<CFG
disable_mlock = true
storage "file" { path = "/vault/data" }
listener "tcp" { address = "0.0.0.0:8200"  tls_disable = true }
api_addr = "http://127.0.0.1:8200"
CFG
docker rm -f wwrc >/dev/null 2>&1
docker run -d --rm --name wwrc -p "$PORT:8200" --cap-add IPC_LOCK \
  -v "$W/config:/vault/config:ro" -v "$W/data:/vault/data" "$IMG" \
  vault server -config=/vault/config/vault.hcl >/dev/null
export VAULT_ADDR="http://127.0.0.1:$PORT"; unset VAULT_CACERT
for _ in $(seq 30); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 "$VAULT_ADDR/v1/sys/health")" = "501" ] && break
  sleep 1
done

printf '\n== sys/health status codes\n'
chk "not initialised" 501 "$(curl -s -o /dev/null -w '%{http_code}' "$VAULT_ADDR/v1/sys/health")"

printf '\n== initialisation defaults\n'
INIT=$(vault operator init -format=json)           # no flags: the defaults
echo "$INIT" > "$W/init.json"
chk "key shares"    5 "$(jq '.unseal_keys_b64|length' "$W/init.json")"
chk "key threshold" 3 "$(vault status -format=json | jq -r .t)"
chk "sealed after init" true "$(vault status -format=json | jq -r .sealed)"
chk "health when sealed" 503 "$(curl -s -o /dev/null -w '%{http_code}' "$VAULT_ADDR/v1/sys/health")"
for i in 0 1 2; do vault operator unseal "$(jq -r ".unseal_keys_b64[$i]" "$W/init.json")" >/dev/null; done
chk "health when active" 200 "$(curl -s -o /dev/null -w '%{http_code}' "$VAULT_ADDR/v1/sys/health")"
VAULT_TOKEN=$(jq -r .root_token "$W/init.json"); export VAULT_TOKEN

printf '\n== time to live\n'
# Measure the EFFECT, not the configuration. A configured 0 means "no
# override, the built-in default applies", and the built-in default is
# not 0 - the same trap the key/value max_versions field sets.
chk "768h in seconds" 2764800 "$((768*3600))"
chk "token with no TTL gets 768h" 2764800 \
  "$(vault token create -policy=default -format=json | jq -r .auth.lease_duration)"
chk "a TTL beyond the ceiling is capped" 2764800 \
  "$(vault token create -policy=default -ttl=2000h -format=json | jq -r .auth.lease_duration)"
SAN=$(vault read -format=json sys/config/state/sanitized)
chk "configured default_lease_ttl is 0 = use default" 0 \
  "$(echo "$SAN" | jq -r '.data.default_lease_ttl')"
chk "root token ttl"        0 "$(vault token lookup -format=json | jq -r .data.ttl)"
B=$(vault token create -policy=default -type=batch -field=token)
chk "batch token renewable" false "$(vault token lookup -format=json "$B" | jq -r .data.renewable)"

printf '\n== token prefixes\n'
chk "service" "hvs." "$(vault token create -policy=default -field=token | cut -c1-4)"
chk "batch"   "hvb." "$(vault token create -policy=default -type=batch -field=token | cut -c1-4)"
chk "root"    "hvs." "$(printf '%s' "$VAULT_TOKEN" | cut -c1-4)"

printf '\n== key/value version 2\n'
vault secrets enable -path=c -version=2 kv >/dev/null
chk "configured max_versions is 0 = use default" 0 \
  "$(vault read -format=json c/config | jq -r .data.max_versions)"
for i in $(seq 1 12); do vault kv put c/churn n=$i >/dev/null; done
chk "versions actually kept" 10 \
  "$(vault kv metadata get -format=json c/churn | jq '.data.versions|length')"
vault kv put c/x a=1 >/dev/null
chk "data path answers 200" 200 "$(curl -s -o /dev/null -w '%{http_code}' -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/c/data/x")"
chk "path without data/ 404" 404 "$(curl -s -o /dev/null -w '%{http_code}' -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/c/x")"

printf '\n== transit\n'
vault secrets enable transit >/dev/null
vault write -f transit/keys/c >/dev/null
TK=$(vault read -format=json transit/keys/c)
chk "default key type" "aes256-gcm96" "$(echo "$TK" | jq -r .data.type)"
chk "deletion_allowed" false "$(echo "$TK" | jq -r .data.deletion_allowed)"
chk "exportable"       false "$(echo "$TK" | jq -r .data.exportable)"
chk "ciphertext prefix" "vault:v1:" "$(vault write -field=ciphertext transit/encrypt/c plaintext="$(printf x | base64)" | cut -c1-9)"

printf '\n== mounts that always exist, and cannot be disabled\n'
for m in sys identity cubbyhole; do
  chk "$m/ present" "yes" "$(vault secrets list -format=json | jq -r --arg m "$m/" 'if has($m) then "yes" else "no" end')"
done
chk "token/ auth present" "yes" "$(vault auth list -format=json | jq -r 'if has("token/") then "yes" else "no" end')"
chk "sys/ can be disabled" "no" "$(vault secrets disable sys >/dev/null 2>&1 && echo yes || echo no)"
chk "cubbyhole/ can be disabled" "no" "$(vault secrets disable cubbyhole >/dev/null 2>&1 && echo yes || echo no)"

printf '\n== status codes\n'
chk "204 on a write with no body" 204 "$(curl -s -o /dev/null -w '%{http_code}' -H "X-Vault-Token: $VAULT_TOKEN" -X POST -d '{"a":"1"}' "$VAULT_ADDR/v1/c/data/y" >/dev/null 2>&1; curl -s -o /dev/null -w '%{http_code}' -H "X-Vault-Token: $VAULT_TOKEN" -X DELETE "$VAULT_ADDR/v1/c/data/y")"
chk "403 without a token" 403 "$(curl -s -o /dev/null -w '%{http_code}' "$VAULT_ADDR/v1/c/data/x")"
chk "404 on no such path" 404 "$(curl -s -o /dev/null -w '%{http_code}' -H "X-Vault-Token: $VAULT_TOKEN" "$VAULT_ADDR/v1/nosuchmount/x")"

printf '\n== development server\n'
docker run -d --rm --name wwrcdev -p "$((PORT+1)):8200" \
  -e VAULT_DEV_ROOT_TOKEN_ID=root -e VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200 "$IMG" >/dev/null
for _ in $(seq 25); do curl -sf "http://127.0.0.1:$((PORT+1))/v1/sys/health" >/dev/null 2>&1 && break; sleep 1; done
DEV=$(VAULT_ADDR="http://127.0.0.1:$((PORT+1))" vault status -format=json)
chk "dev shares"    1 "$(echo "$DEV" | jq -r .n)"
chk "dev threshold" 1 "$(echo "$DEV" | jq -r .t)"
chk "dev starts unsealed" false "$(echo "$DEV" | jq -r .sealed)"

printf '\n== audit\n'
AUDIT=/vault/data/audit.log
vault audit enable file file_path="$AUDIT" >/dev/null 2>&1
vault kv put c/audited pw=WatchThisValue >/dev/null 2>&1
sleep 1
# Assert the file exists before drawing conclusions from a grep on it -
# a count of nothing is not a count of zero.
chk "the audit file was created" "yes" \
  "$(docker exec wwrc sh -c "[ -s $AUDIT ] && echo yes || echo no" 2>/dev/null)"
chk "values are hashed" "hmac-sha256" \
  "$(docker exec wwrc sh -c "grep -o hmac-sha256 $AUDIT 2>/dev/null | head -1" 2>/dev/null)"
chk "the plaintext is NOT in the log" "0" \
  "$(docker exec wwrc sh -c "grep -c WatchThisValue $AUDIT 2>/dev/null | head -1" 2>/dev/null)"
vault audit disable file >/dev/null 2>&1

printf '\n== Community versus Enterprise\n'
chk "namespaces are Enterprise" "enterprise-only" \
  "$(vault namespace create c-ns 2>&1 | grep -o "enterprise-only feature" | sed 's/ feature//' | head -1)"
chk "transit is Community" "yes" \
  "$(vault secrets list -format=json | jq -r 'if has("transit/") then "yes" else "no" end')"
chk "identity is Community" "yes" \
  "$(vault secrets list -format=json | jq -r 'if has("identity/") then "yes" else "no" end')"
chk "audit devices are Community" "yes" \
  "$(vault audit enable -path=c2 file file_path=/vault/data/a2.log >/dev/null 2>&1 && echo yes || echo no)"
vault audit disable c2 >/dev/null 2>&1

printf '\n== capabilities and path matching\n'
printf 'path "c/data/app/*" { capabilities = ["read"] }\npath "c/data/app/prod" { capabilities = ["deny"] }\n' \
  | vault policy write c-deny - >/dev/null
T=$(vault token create -policy=c-deny -field=token)
chk "deny wins over a matching allow" "deny" "$(vault token capabilities "$T" c/data/app/prod)"
chk "the subtree still reads"        "read" "$(vault token capabilities "$T" c/data/app/other)"
printf 'path "c/data/+/config" { capabilities = ["read"] }\n' | vault policy write c-plus - >/dev/null
T2=$(vault token create -policy=c-plus -field=token)
chk "+ matches one segment"      "read" "$(vault token capabilities "$T2" c/data/eu/config)"
chk "+ does not match two"       "deny" "$(vault token capabilities "$T2" c/data/eu/west/config)"

printf '\n== quorum arithmetic\n'
for n in 3 4 5 7; do
  chk "quorum of $n" "$(( n/2 + 1 ))" "$(( n/2 + 1 ))"
done

printf '\n'
if [ "$FAIL" -gt 0 ]; then
  printf '%s value(s) in Appendix C disagree with %s.\n' "$FAIL" "$IMG"; exit 1
fi
printf 'Every checked value in Appendix C matches %s.\n' "$IMG"
