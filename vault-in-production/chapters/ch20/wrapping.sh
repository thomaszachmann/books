#!/usr/bin/env bash
# Secret Zero: was Response Wrapping leistet und was nicht.
#
# Die wichtigste Messung ist die letzte: abgelaufen, abgefangen
# und blanker Unsinn liefern dem Client EXAKT dieselbe Meldung.
# Wer darauf mit "wird der TTL gewesen sein" reagiert, hat die
# einzige Sicherheitseigenschaft des Verfahrens wieder abgeschafft.
set -uo pipefail

cd "$(dirname "$0")/../.."

CA=${CA:-cluster/tls/cert.pem}
ROLE=${ROLE:-app}
ADDR=${VAULT_ADDR:-https://127.0.0.1:8210}
T=${VAULT_TOKEN:-$(jq -r .root_token cluster/init.json)}

vault auth enable approle >/dev/null 2>&1 || true
vault policy write app - >/dev/null 2>&1 <<'POL'
path "secret/data/app/*" { capabilities = ["read"] }
POL
vault write "auth/approle/role/$ROLE" token_policies=app \
  token_ttl=1h >/dev/null 2>&1

wrap(){ vault write -f -wrap-ttl="${1:-300s}" -format=json \
        "auth/approle/role/$ROLE/secret-id"; }
err(){ grep '^\*' || true; }
accessor_state(){
  curl -s --cacert "$CA" -H "X-Vault-Token: $T" -X POST \
    -d "{\"accessor\":\"$1\"}" \
    "$ADDR/v1/auth/token/lookup-accessor" \
  | jq -r 'if .errors == null
           then "  open, ttl " + (.data.ttl|tostring) + "s, path " + .data.path
           else "  consumed: " + (.errors|join("; ")) end'
}

echo "== 1. what actually travels =="
R=$(wrap 120s)
echo "$R" | jq '{data, wrap_ttl: .wrap_info.ttl,
                 creation_path: .wrap_info.creation_path}'
echo "  data is null -> the secret is NOT in transit"

W=$(echo "$R" | jq -r .wrap_info.token)
WA=$(echo "$R" | jq -r .wrap_info.accessor)

echo
echo "== 2. inspect without consuming =="
vault write -format=json sys/wrapping/lookup token="$W" \
  | jq '{creation_path: .data.creation_path,
         creation_ttl: .data.creation_ttl}'
echo "  a consumer that does not check creation_path is"
echo "  trusting the envelope it was handed"

echo
echo "== 3. the sender's delivery receipt =="
echo "before unwrap:"; accessor_state "$WA"
vault unwrap "$W" >/dev/null 2>&1
echo "after unwrap: "; accessor_state "$WA"

echo
echo "== 4. it opens exactly once =="
vault unwrap "$W" 2>&1 | err | sed 's/^/  /'

echo
echo "== 5. interception: not prevented, only made loud =="
W2=$(wrap 300s | jq -r .wrap_info.token)
echo "  attacker gets: $(vault unwrap -format=json "$W2" 2>/dev/null \
    | jq -r '.data.secret_id[0:18]')"
echo "  application then sees:"
vault unwrap "$W2" 2>&1 | err | sed 's/^/    /'

echo
echo "== 6. three situations, one message =="
WE=$(wrap 5s | jq -r .wrap_info.token); sleep 8
printf '  expired:     '; vault unwrap "$WE" 2>&1 | err | tr -d '\n'; echo
W3=$(wrap 300s | jq -r .wrap_info.token)
vault unwrap "$W3" >/dev/null 2>&1
printf '  intercepted: '; vault unwrap "$W3" 2>&1 | err | tr -d '\n'; echo
printf '  nonsense:    '; vault unwrap "hvs.NEVERVALID123" 2>&1 | err | tr -d '\n'; echo
echo
echo "  Identisch. Also muss die Antwort in allen drei Faellen"
echo "  dieselbe sein: secret_id als kompromittiert behandeln,"
echo "  neu ausstellen, im Audit-Log nachsehen (Kapitel 18)."
