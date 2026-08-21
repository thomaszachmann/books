#!/usr/bin/env bash
# Chapter 22 - the auto-unseal failures, on purpose.
#
# Needs the unsealer from the chapter:
#   ./chapters/ch22/setup-unsealer.sh && ./chapters/ch22/migrate-to-autounseal.sh
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env

st() { vault status -format=json 2>/dev/null; }
seal_type=$(st | jq -r '.type // "shamir"')

wwr_case "which seal is actually in force"
st | jq -r '"  seal type          : \(.type)\n  recovery seal type : \(.recovery_seal_type // "-")\n  sealed             : \(.sealed)"'
if [ "$seal_type" != "transit" ]; then
  echo
  echo "This Vault is not using auto-unseal, so the cases below cannot"
  echo "run. Do the chapter's migration first:"
  echo "  ./chapters/ch22/setup-unsealer.sh"
  echo "  ./chapters/ch22/migrate-to-autounseal.sh"
  wwr_done
fi

wwr_case "recovery keys cannot be used to unseal"
echo "The chapter's point is that recovery keys are not unseal keys. What"
echo "actually happens when you try is worth seeing, because it is not an"
echo "error:"
code=$(curl -s -o /tmp/wwr22 -w '%{http_code}' --max-time 5 \
        -X PUT -d '{"key":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="}' \
        "$VAULT_ADDR/v1/sys/unseal" 2>/dev/null)
printf '  PUT /v1/sys/unseal with nonsense: HTTP %s\n' "$code"
jq -c '{type, sealed, progress}' < /tmp/wwr22 2>/dev/null | sed 's/^/  /'
echo
echo "HTTP 200, sealed false, progress 0. The endpoint is a no-op on a"
echo "transit-sealed Vault and reports success either way. An operator"
echo "trying to 'unseal manually' during an incident gets no indication"
echo "that nothing happened - which is the failure mode to know about."
echo "Recovery keys serve generate-root and rekey. Nothing else."

wwr_case "the seal token, and the failure that arrives months later"
echo "The seal configuration holds a token for the unsealer. If it is not"
echo "periodic it expires, and the next RESTART fails - possibly long"
echo "after the change that caused it."
if [ -n "${WWR_SEAL_TOKEN:-}" ]; then
  BAO_ADDR="${BAO_ADDR:-http://127.0.0.1:8300}" \
  BAO_TOKEN="$WWR_SEAL_TOKEN" ${WWR_BAO:-bao} token lookup -format=json 2>/dev/null \
    | jq -r '"  period : \(.data.period // 0) s\n  ttl    : \(.data.ttl) s\n  renewable: \(.data.renewable)"'
  echo "period greater than zero is what you want. A renewable token with"
  echo "no period still stops renewing at its max_ttl."
else
  echo "  (set WWR_SEAL_TOKEN to inspect it - the chapter's"
  echo "   setup-unsealer.sh prints it)"
fi

wwr_case "Error sealing with permission denied and invalid token"
wwr_policy sealer 'path "sys/seal" { capabilities = ["update"] }'
T=$(wwr_token sealer)
wwr_caps "$T" sys/seal
echo "update looks right and is not enough - sys/seal needs sudo:"
VAULT_TOKEN=$T wwr_expect "permission denied" vault operator seal
echo
echo "And with no token at all, the message names both halves:"
EMPTY=$(mktemp -d)
VAULT_TOKEN='' HOME="$EMPTY" vault operator seal 2>&1 | sed -n '1,8p' | grep -v '^$' | sed 's/^/  /'
rmdir "$EMPTY" 2>/dev/null || true

wwr_case "after moving to auto-unseal, the audit log shows no unseal events"
echo "There is nothing to record. Unsealing is no longer an operation"
echo "somebody performs against Vault - it happens inside startup, before"
echo "the audit devices exist. If your evidence for 'who restarted Vault'"
echo "was the unseal entries, it is gone, and the answer now lives in"
echo "whatever restarts the process."

echo
echo "Not reproduced here: a Vault that is sealed WHILE the KMS is"
echo "unreachable. Auto-unseal keeps re-unsealing as soon as the KMS"
echo "answers, so the state is hard to hold open on a laptop - and"
echo "producing it by breaking the network reliably enough to script is"
echo "more machinery than the lesson is worth. The lesson: the KMS is"
echo "now part of Vault's availability. Chapter 10 of this book's"
echo "sequel measures that."
wwr_done
