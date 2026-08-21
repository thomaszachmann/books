#!/usr/bin/env bash
# Chapter 6 - produce every error in "What Went Wrong" on purpose.
#
# The book prints these messages. This script is where they come from, so
# that a reader meets them once here, deliberately, instead of for the
# first time at an inconvenient moment. Each case shows the policy that
# causes it, the command, and the real output.
#
# Nothing here is destructive: it creates policies and tokens under
# names prefixed wwr- and removes them at the end.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

# Only a TLS address needs a CA. Setting VAULT_CACERT against an http
# address makes every command fail on a file it never needed to read.
case "$VAULT_ADDR" in
  https://*) export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}" ;;
  *)         unset VAULT_CACERT ;;
esac

vault secrets enable -path=meridian -version=2 kv >/dev/null 2>&1 || true
vault kv put meridian/tracking db_user=tracking_svc db_password=lab >/dev/null
vault kv put meridian/app/production key=prod >/dev/null

pol() { printf '%s\n' "$2" | vault policy write "wwr-$1" - >/dev/null; }
tok() { vault token create -policy="wwr-$1" -field=token; }
case_() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

# ---------------------------------------------------------------- case 1
case_ "permission denied on a path that clearly exists"
pol missing-data 'path "meridian/tracking" { capabilities = ["read"] }'
T=$(tok missing-data)
echo '$ vault kv get meridian/tracking'
VAULT_TOKEN=$T vault kv get meridian/tracking 2>&1 | sed -n "1,8p" | grep -v "^$"
echo
echo "The policy names the CLI path. Vault checks the API path:"
printf '  %-28s %s\n' "meridian/tracking"      "$(vault token capabilities "$T" meridian/tracking)"
printf '  %-28s %s\n' "meridian/data/tracking" "$(vault token capabilities "$T" meridian/data/tracking)"

# ---------------------------------------------------------------- case 2
case_ "the UI shows nothing, but the CLI works"
pol read-only 'path "meridian/data/tracking" { capabilities = ["read"] }'
T=$(tok read-only)
echo "Perfectly functional for an application:"
printf '  %-30s %s\n' "meridian/data/tracking" "$(vault token capabilities "$T" meridian/data/tracking)"
echo "Invisible in a browser - the tree needs list on metadata:"
printf '  %-30s %s\n' "meridian/metadata"   "$(vault token capabilities "$T" meridian/metadata)"
printf '  %-30s %s\n' "meridian/metadata/*" "$(vault token capabilities "$T" meridian/metadata/tracking)"

# ---------------------------------------------------------------- case 3
case_ "permission denied writing to a path the token can read"
echo '$ vault kv put meridian/tracking x=y      # token has read only'
VAULT_TOKEN=$T vault kv put meridian/tracking x=y 2>&1 | sed -n "1,8p" | grep -v "^$"
echo
echo "read does not imply write, and an existing path needs update:"
printf '  %-30s %s\n' "meridian/data/tracking" "$(vault token capabilities "$T" meridian/data/tracking)"

# ---------------------------------------------------------------- case 4
case_ "a deny that seems to be ignored"
pol exact-deny 'path "meridian/data/app/*" { capabilities = ["read"] }
path "meridian/data/app" { capabilities = ["deny"] }'
T=$(tok exact-deny)
echo "The deny names an exact path, so the subtree is untouched:"
printf '  %-34s %s\n' "meridian/data/app"            "$(vault token capabilities "$T" meridian/data/app)"
printf '  %-34s %s\n' "meridian/data/app/production" "$(vault token capabilities "$T" meridian/data/app/production)"
echo "Use meridian/data/app/* in the deny if you meant the subtree."

# ---------------------------------------------------------------- case 5
case_ "permission denied on sys/seal with a policy that grants update"
pol sealer 'path "sys/seal" { capabilities = ["update"] }'
T=$(tok sealer)
echo '$ vault operator seal'
VAULT_TOKEN=$T vault operator seal 2>&1 | sed -n "1,8p" | grep -v "^$"
echo
echo "sys/seal is root-protected. It needs sudo as well as update:"
printf '  %-14s %s\n' "sys/seal" "$(vault token capabilities "$T" sys/seal)"

# ---------------------------------------------------------------- case 6
case_ "a policy with * in the middle matches nothing"
pol star-middle 'path "meridian/*/config" { capabilities = ["read"] }
path "meridian/+/config2" { capabilities = ["read"] }'
T=$(tok star-middle)
echo "* is only a wildcard at the end. In the middle it is a literal:"
printf '  %-26s %s\n' "meridian/us/config"  "$(vault token capabilities "$T" meridian/us/config)"
printf '  %-26s %s\n' "meridian/us/config2" "$(vault token capabilities "$T" meridian/us/config2)"
echo "+ matches one segment, which is what people mean by * in the middle."

# ------------------------------------------------------------------ tidy
echo
for p in $(vault policy list | grep '^wwr-'); do vault policy delete "$p" >/dev/null; done
echo "Six errors, all deliberate. Policies removed."
