#!/usr/bin/env bash
# Chapter 18 - every error the chapter prints, on purpose.
#
# Needs both: docker compose up -d vault openbao
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env

BAO_ADDR="${BAO_ADDR:-http://127.0.0.1:8300}"
BAO_TOKEN="${BAO_TOKEN:-root}"
export BAO_ADDR BAO_TOKEN
BAO="${WWR_BAO:-docker compose -f docker-compose.yml exec -T openbao bao}"

wwr_case "bao: command not found"
if command -v bao >/dev/null 2>&1; then
  echo "  bao is on this PATH: $(command -v bao)"
else
  echo "  bao is NOT on this PATH - which is the point:"
  bao status 2>&1 | head -1 | sed 's/^/  /'
fi
echo "The binary is bao, not vault, and it is a separate download."
echo "The container has it, which is why the chapter uses that route:"
$BAO status 2>/dev/null | grep -E "Version|Sealed" | sed 's/^/  /'

wwr_case "commands work but hit the wrong server"
echo "This is the one that wastes an afternoon. Both variables exported,"
echo "pointing at different systems:"
printf '  VAULT_ADDR = %s\n  BAO_ADDR   = %s\n' "$VAULT_ADDR" "$BAO_ADDR"
echo
echo "bao reads VAULT_ADDR too, as a compatibility shim. So this succeeds"
echo "against VAULT, not against OpenBao, and says nothing about it:"
v_cid=$(vault status -format=json 2>/dev/null | jq -r '.cluster_id // "?"')
b_cid=$($BAO status -format=json 2>/dev/null | jq -r '.cluster_id // "?"')
printf '  vault cluster_id : %s\n  bao   cluster_id : %s\n' "$v_cid" "$b_cid"
echo "Different clusters. If those two ever print the same value, your"
echo "bao command is talking to Vault."
echo
echo "The diagnosis is one line:"
echo '  $ env | grep -E "^(VAULT|BAO)_"'

wwr_case "an engine that exists in one is missing in the other"
echo "Probe rather than reason. Same list against both:"
for e in kv transit pki database ssh totp; do
  v=$(vault secrets enable -path="wwr18-$e" "$e" >/dev/null 2>&1 && echo yes || echo NO)
  [ "$v" = yes ] && vault secrets disable "wwr18-$e" >/dev/null 2>&1
  b=$($BAO secrets enable -path="wwr18-$e" "$e" >/dev/null 2>&1 && echo yes || echo NO)
  [ "$b" = yes ] && $BAO secrets disable "wwr18-$e" >/dev/null 2>&1
  printf '  %-9s vault:%-4s openbao:%s\n' "$e" "$v" "$b"
done
echo "Record what YOUR platform uses and check those. Reasoning about"
echo "the projects in general is how people arrive at surprises."

wwr_case "the difference that is easy to miss"
echo "Token prefixes diverged at the fork and never converged:"
printf '  vault   service: %s   batch: %s\n' \
  "$(vault token create -policy=default -field=token | cut -c1-5)" \
  "$(vault token create -policy=default -type=batch -field=token | cut -c1-5)"
printf '  openbao service: %s      batch: %s\n' \
  "$($BAO token create -policy=default -field=token | cut -c1-3)" \
  "$($BAO token create -policy=default -type=batch -field=token | cut -c1-3)"
echo "A secret scanner tuned to hvs\\. will not catch an OpenBao token."

wwr_case "namespaces: the divergence that changes a purchase"
printf '  vault   : %s\n' "$(vault namespace create wwr18-ns 2>&1 | tail -1 | cut -c1-60)"
printf '  openbao : %s\n' "$($BAO namespace create wwr18-ns 2>&1 | grep -E 'uuid|path' | head -1 | cut -c1-60)"
$BAO namespace delete wwr18-ns >/dev/null 2>&1 || true
echo "The usual assumption about a fork is that it lags. Here it does not."

echo
echo "Not reproduced here: Helm chart value drift and an unexpected"
echo "Terraform diff. Both need the thing they warn about - a real"
echo "install and a real state file - and both are read-the-diff advice"
echo "rather than an error message."
wwr_done
