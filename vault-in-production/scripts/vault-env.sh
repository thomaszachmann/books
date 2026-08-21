# Source this:  . ./scripts/vault-env.sh
# Points the CLI at node 1 and exports the root token from init.json.
# zsh has no BASH_SOURCE, so both are handled.
_vip_root="${BASH_SOURCE[0]:-${(%):-%x}}"
_vip_dir="$(cd "$(dirname "$_vip_root")/.." && pwd)"
export VAULT_ADDR="https://127.0.0.1:8210"
export VAULT_CACERT="$_vip_dir/cluster/tls/cert.pem"
if [ -f "$_vip_dir/cluster/init.json" ]; then
  VAULT_TOKEN="$(jq -r .root_token "$_vip_dir/cluster/init.json")"
  export VAULT_TOKEN
fi
unset _vip_root _vip_dir
