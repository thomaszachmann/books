#!/usr/bin/env bash
# A staged incident and the three sources side by side. Chapter 18.
#
# Two clients, the same work: read one secret forty times. One logs
# in once, the other on every access. Measured: +1 lease against +40.
#
# The point is which source names the culprit. Metrics know no
# client (that would be an unbounded label), the server log talks
# only about Vault itself, and in the audit device display_name is
# the METHOD, not the client.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
. ./scripts/engine.sh

N=${N:-40}
NODE=${NODE:-vip-vault-1}
CA=${CA:-cluster/tls/cert.pem}
LOG=/vault/logs/audit.log

# The audit log belongs to vault:vault with mode 0600 - the calling
# user cannot get at it. In the lab through the container; in
# production it takes a group, an ACL, or a copy someone may read.
alog(){ $ENGINE exec "$NODE" sh -c "cat $LOG"; }

leases(){ curl -s --cacert "$CA" \
  "https://127.0.0.1:8210/v1/sys/metrics?format=prometheus" \
  | grep '^vault_expire_num_leases' | awk '{print $2}'; }

vault audit enable file file_path=/vault/logs/audit.log >/dev/null 2>&1
vault secrets enable -path=secret -version=2 kv >/dev/null 2>&1
vault kv put secret/app/db user=svc pass=Secret123 >/dev/null
vault auth enable approle >/dev/null 2>&1
vault policy write reader - >/dev/null <<'POL'
path "secret/data/app/*" { capabilities = ["read"] }
POL

for r in wellbehaved sloppy; do
  vault write "auth/approle/role/$r" token_policies=reader \
    token_ttl=1h >/dev/null
done
rid(){ vault read -field=role_id "auth/approle/role/$1/role-id"; }
sid(){ vault write -f -field=secret_id \
         "auth/approle/role/$1/secret-id"; }

echo "leases before:                    $(leases)"

T=$(vault write -field=token auth/approle/login \
      role_id="$(rid wellbehaved)" secret_id="$(sid wellbehaved)")
for _ in $(seq 1 "$N"); do
  VAULT_TOKEN=$T vault kv get secret/app/db >/dev/null 2>&1
done
echo "after $N reads, one login:        $(leases)"

RS=$(rid sloppy); SS=$(sid sloppy)
for _ in $(seq 1 "$N"); do
  TS=$(vault write -field=token auth/approle/login \
        role_id="$RS" secret_id="$SS" 2>/dev/null)
  VAULT_TOKEN=$TS vault kv get secret/app/db >/dev/null 2>&1
done
sleep 12
echo "after $N reads, $N logins:        $(leases)"

echo
echo "== source 1: metrics - any client identity? =="
curl -s --cacert "$CA" \
  "https://127.0.0.1:8210/v1/sys/metrics?format=prometheus" \
  | grep -Ei 'sloppy|wellbehaved' | head -3
echo "  (nothing above = metrics do not know who)"

echo "== source 2: server log =="
echo "  lines in the last 10m: $($ENGINE logs --since 10m "$NODE" 2>&1 | wc -l)"
echo "  mentioning either client: $($ENGINE logs --since 10m "$NODE" 2>&1 \
        | grep -Eci 'sloppy|wellbehaved')"

echo "== source 3: audit device =="
echo "  by display_name (the TRAP - this is the auth method):"
alog | grep approle/login \
  | jq -r 'select(.type=="response") | .response.auth.display_name' \
  2>/dev/null | sort | uniq -c | sed 's/^/    /'
echo "  by metadata.role_name:"
alog | grep approle/login \
  | jq -r 'select(.type=="response") | .response.auth.metadata.role_name' \
  2>/dev/null | sort | uniq -c | sed 's/^/    /'
echo "  by entity_id (works across auth methods):"
alog | grep approle/login \
  | jq -r 'select(.type=="response") | .response.auth.entity_id[0:12]' \
  2>/dev/null | sort | uniq -c | sed 's/^/    /'

echo
echo "== searching for a value you already hold =="
hunt(){
  h=$(vault write -field=hash sys/audit-hash/file input="$1")
  # Without this filter there are ALWAYS two hits: our own hash
  # request and its response contain the input.
  n=$(alog | grep -c "$h" || true)
  k=$(alog | grep "$h" \
      | jq -r 'select(.request.path != "sys/audit-hash/file")
               | .request.path' 2>/dev/null | wc -l)
  printf '  %-16s raw hits %s, after excluding our own query %s\n' \
    "$1" "$n" "$k"
}
hunt "Secret123"
hunt "NeverUsed999"
echo "  where the Secret123 hits are, by entry type and operation:"
h=$(vault write -field=hash sys/audit-hash/file input="Secret123")
alog | grep "$h" \
  | jq -r 'select(.request.path != "sys/audit-hash/file")
           | "\(.type) \(.request.operation) \(.request.path)"' \
  2>/dev/null | sort | uniq -c | sed 's/^/    /' 
