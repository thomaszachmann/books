# Source this to configure the CLI for the lab. Appendix D.
#
#   source scripts/vault-env.sh
#
# Deliberately NOT executable: a script cannot export into your shell.

_LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

export VAULT_ADDR='https://127.0.0.1:8200'
export VAULT_CACERT="$_LAB_ROOT/tls/vault-cert.pem"

# VAULT_TOKEN outranks ~/.vault-token. Unset it before `vault login`,
# or the login appears to succeed and every later command still fails.
if [ -f "$_LAB_ROOT/init.json" ]; then
  VAULT_TOKEN="$(jq -r '.root_token' "$_LAB_ROOT/init.json")"
  export VAULT_TOKEN
fi

unset _LAB_ROOT

echo "VAULT_ADDR=$VAULT_ADDR"
echo "VAULT_CACERT=$VAULT_CACERT"
echo "VAULT_TOKEN=${VAULT_TOKEN:+<set>}${VAULT_TOKEN:-<unset>}"
