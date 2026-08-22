#!/usr/bin/env bash
# Die Datei haelt, der Proxy nicht. Beides nebeneinander durch
# denselben Ausfall - das ist die ganze Aussage des Kapitels.
set -uo pipefail

cd "$(dirname "$0")/../.."
. ./scripts/engine.sh

WORK=${WORK:-/tmp/agent}
NODES=${NODES:-"vip-vault-1 vip-vault-2 vip-vault-3"}

file(){ grep -h '^db=' "$WORK/out/config.ini" 2>/dev/null | tr -d '\n'; }
proxy(){ $ENGINE exec -e VAULT_ADDR=http://127.0.0.1:8007 \
           -e VAULT_TOKEN=dummy vault-agent \
           vault kv get -field=db secret/app/config 2>&1 \
         | tail -1 | cut -c1-30; }

echo "before the outage:  file=$(file)  proxy=$(proxy)"
if [ "$(proxy)" != "primary" ]; then
  echo "ABORT: the proxy does not work while Vault is UP, so a" \
       "failure during the outage would prove nothing." >&2
  exit 1
fi

# shellcheck disable=SC2086
$ENGINE stop $NODES >/dev/null
t0=$(date +%s)
for w in 0 25 60 90; do
  [ "$w" -gt 0 ] && sleep "$w"
  printf '[+%03ds] file=%-12s proxy=%s\n' \
    $(( $(date +%s) - t0 )) "$(file)" "$(proxy)"
done

# shellcheck disable=SC2086
$ENGINE start $NODES >/dev/null
echo "(nodes started again - they are SEALED, run 'make unseal')"
