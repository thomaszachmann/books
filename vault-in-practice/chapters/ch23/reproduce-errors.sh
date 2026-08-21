#!/usr/bin/env bash
# Chapter 23 - every error the chapter prints, on purpose.
#
# The fail-closed case actually takes Vault down and brings it back. That
# is the point of the chapter, and it is why this runs on a lab.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env

LOGDIR="${WWR_LOGDIR:-$PWD/logs}"
mkdir -p "$LOGDIR" 2>/dev/null || true

wwr_case "vault audit disable returns permission denied"
wwr_policy auditor 'path "sys/audit/*" { capabilities = ["create","update","delete","sudo"] }
path "sys/audit"   { capabilities = ["read","sudo"] }'
wwr_policy noaudit 'path "sys/audit/*" { capabilities = ["create","update","delete"] }'
T=$(wwr_token noaudit)
echo "A policy with delete but without sudo:"
wwr_caps "$T" sys/audit/file
vault audit enable -path=wwr-file file file_path=/vault/logs/wwr.log >/dev/null 2>&1 || true
VAULT_TOKEN=$T wwr_expect "permission denied" vault audit disable wwr-file
echo "sys/audit/* is root-protected. sudo is not optional there."

wwr_case "the audit log contains plaintext values"
vault audit enable -path=wwr-raw file \
  file_path=/vault/logs/wwr-raw.log log_raw=true >/dev/null 2>&1 || true
vault secrets enable -path=wwr23 -version=2 kv >/dev/null 2>&1 || true
vault kv put wwr23/secret password=PlaintextInTheLog >/dev/null
echo "With log_raw=true, the value is in the file, unhashed:"
docker_log="/vault/logs/wwr-raw.log"
if grep -q "PlaintextInTheLog" "$LOGDIR/wwr-raw.log" 2>/dev/null; then
  grep -o "PlaintextInTheLog" "$LOGDIR/wwr-raw.log" | head -1 | sed 's/^/  found: /'
else
  echo "  (log not readable from here - inside the container it is $docker_log)"
fi
echo "Compare with the hashed device, where the same write appears as:"
vault kv put wwr23/secret password=PlaintextInTheLog >/dev/null
grep -o 'hmac-sha256:[a-f0-9]\{16\}' "$LOGDIR/wwr.log" 2>/dev/null | head -1 | sed 's/^/  /'
echo "Treat a log_raw file as a secret, because it is one."
vault audit disable wwr-raw >/dev/null 2>&1 || true

wwr_case "metrics endpoint returns 403"
code() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$@"; }
T=$(wwr_token noaudit)
printf '  no token at all          : HTTP %s\n' "$(code "$VAULT_ADDR/v1/sys/metrics")"
printf '  a token without the policy: HTTP %s\n' \
  "$(code -H "X-Vault-Token: $T" "$VAULT_ADDR/v1/sys/metrics")"
wwr_policy metrics 'path "sys/metrics" { capabilities = ["read"] }'
M=$(wwr_token metrics)
printf '  with read on sys/metrics  : HTTP %s\n' \
  "$(code -H "X-Vault-Token: $M" "$VAULT_ADDR/v1/sys/metrics")"
echo
echo "It needs read on sys/metrics, or unauthenticated_metrics_access on"
echo "the listener - which belongs on a management network, not the one"
echo "your applications use."
echo
echo "Note: a DEVELOPMENT server answers 200 to all three. If you test"
echo "this on 'vault server -dev' you will conclude the control does not"
echo "exist. It does; the development server simply does not enforce it."

wwr_case "every request returns 500 and Vault is healthy"
echo "This is the fail-closed behaviour, and it is the most important"
echo "sentence in the chapter: Vault stops rather than acting unaudited."
echo
echo "Point a device at a path that cannot be written:"
vault audit enable -path=wwr-dead file file_path=/proc/wwr-nope >/dev/null 2>&1 \
  && echo "  device enabled" || echo "  Vault refused to enable it - it tests the path first"
echo
echo "Vault checks on enable, which is why the outage arrives later:"
echo "when the disk fills, or a rotation removes the file. The lab drill"
echo "for that is ./chapters/ch23/fail-closed-drill.sh, which does take"
echo "Vault down and bring it back."

wwr_case "the disk filled up overnight"
sz=$(wc -c < "$LOGDIR/wwr.log" 2>/dev/null || echo 0)
printf '  audit log after this short run: %s bytes\n' "$sz"
echo "Vault does not rotate it. Every request and every response, as JSON,"
echo "one object per line, for as long as the device is enabled."
echo "logrotate with copytruncate, or syslog. Not a cron job that moves"
echo "the file - Vault holds the descriptor and would write into nothing."

vault audit disable wwr-file >/dev/null 2>&1 || true
vault secrets disable wwr23 >/dev/null 2>&1 || true
echo
echo "Not reproduced here: version skew on an upgraded node, and a"
echo "restore that fails on a seal mismatch. Both need a second Vault at"
echo "a different version or with a different seal - Chapter 22's lab."
wwr_done
