#!/usr/bin/env bash
# Chapter 1 - every error the chapter prints, on purpose.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env

wwr_case "Error making API request ... permission denied"
echo "The token is missing, wrong, or expired - not a policy problem."
VAULT_TOKEN=hvs.definitelynotarealtoken wwr_expect "permission denied" vault token lookup
echo
echo "Which is why the chapter tells you to check what the client uses:"
echo '  $ echo $VAULT_TOKEN'
echo '  $ vault token lookup'

wwr_case "GET /v1/secret/meridian/tracking returns 404"
vault secrets enable -path=secret -version=2 kv >/dev/null 2>&1 || true
vault kv put secret/meridian/tracking a=b >/dev/null
echo "The CLI inserts data/ silently. curl does not:"
printf '$ curl -s -o /dev/null -w "%%{http_code}\\n" -H "X-Vault-Token: ..." \\\n    $VAULT_ADDR/v1/secret/meridian/tracking\n'
code=$(curl -s -o /dev/null -w '%{http_code}' \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        "$VAULT_ADDR/v1/secret/meridian/tracking")
echo "$code"
[ "$code" = "404" ] && echo '   ok: 404' || { echo "   MISMATCH: expected 404, got $code"; WWR_FAILED=$((${WWR_FAILED:-0}+1)); }
echo "With data/, the same secret is there:"
code=$(curl -s -o /dev/null -w '%{http_code}' \
        -H "X-Vault-Token: $VAULT_TOKEN" \
        "$VAULT_ADDR/v1/secret/data/meridian/tracking")
echo "$code"

wwr_case "connection refused"
echo "Nothing is listening on that port."
VAULT_ADDR=http://127.0.0.1:1 wwr_expect "connection refused" vault status

wwr_case "http: server gave HTTP response to HTTPS client"
echo "The scheme in VAULT_ADDR does not match what the server speaks."
VAULT_ADDR="https://${VAULT_ADDR#*://}" wwr_run vault status

echo
echo "Not reproduced here: the mlock error. It needs Vault started"
echo "without IPC_LOCK on a host that enforces it, which the lab"
echo "avoids on purpose - docker-compose.yml grants that capability."
wwr_done
