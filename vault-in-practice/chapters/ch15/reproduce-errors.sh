#!/usr/bin/env bash
# Chapter 15 - the agent failures, on purpose.
#
# Runs a real agent against your Vault, in a throwaway directory.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env

W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
VBIN="${WWR_VAULT:-vault}"

vault secrets enable -path=wwr15v2 -version=2 kv >/dev/null 2>&1 || true
vault secrets enable -path=wwr15v1 -version=1 kv >/dev/null 2>&1 || true
vault kv put wwr15v2/app db_user=svc db_password=v2secret >/dev/null
vault kv put wwr15v1/app db_user=svc db_password=v1secret >/dev/null
vault auth enable approle >/dev/null 2>&1 || true
vault policy write wwr15 - >/dev/null <<'POL'
path "wwr15v2/data/app" { capabilities = ["read"] }
path "wwr15v1/app"      { capabilities = ["read"] }
POL
vault write auth/approle/role/wwr15 token_policies=wwr15 \
  token_ttl=20m secret_id_num_uses=0 >/dev/null
vault read -field=role_id auth/approle/role/wwr15/role-id > "$W/role_id"
vault write -f -field=secret_id auth/approle/role/wwr15/secret-id > "$W/secret_id"

agent() {  # agent <template-body> [extra-template-config]
  cat > "$W/tpl.ctmpl" <<TPL
$1
TPL
  cat > "$W/agent.hcl" <<CFG
pid_file = "$W/agent.pid"
vault { address = "$VAULT_ADDR" }
auto_auth {
  method "approle" {
    config = {
      role_id_file_path   = "$W/role_id"
      secret_id_file_path = "$W/secret_id"
      remove_secret_id_file_after_reading = false
    }
  }
  sink "file" { config = { path = "$W/token" } }
}
template {
  source      = "$W/tpl.ctmpl"
  destination = "$W/out.txt"
  ${2:-}
}
CFG
  rm -f "$W/out.txt"
  "$VBIN" agent -config="$W/agent.hcl" -log-level=info >"$W/agent.log" 2>&1 &
  local pid=$!
  for _ in $(seq 20); do [ -s "$W/out.txt" ] && break; sleep 1; done
  sleep 1; kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null || true
}

wwr_case "Data.data is not a field of struct, or an empty rendered value"
echo "Version 2 needs .Data.data.<field>. Using version 1 nesting:"
agent '{{ with secret "wwr15v2/data/app" }}{{ .Data.db_password }}{{ end }}'
printf '  rendered: "%s"\n' "$(cat "$W/out.txt" 2>/dev/null)"
grep -oiE "is not a field of struct|can.t evaluate field" "$W/agent.log" | head -1 | sed 's/^/  log: /'
echo "and with the right nesting:"
agent '{{ with secret "wwr15v2/data/app" }}{{ .Data.data.db_password }}{{ end }}'
printf '  rendered: "%s"\n' "$(cat "$W/out.txt" 2>/dev/null)"

wwr_case "the template renders an empty file - or no file at all"
echo "Two different faults look alike from a distance."
echo
echo "A path the token may not READ: the agent never renders, so there is"
echo "no destination file. An application starting from it fails on a"
echo "missing file, which is at least loud:"
agent '{{ with secret "wwr15v2/data/forbidden" }}{{ .Data.data.x }}{{ end }}'
if [ -e "$W/out.txt" ]; then
  printf '  destination: exists, %s bytes\n' "$(wc -c < "$W/out.txt")"
else
  echo "  destination: does not exist"
fi
grep -oiE "permission denied|403" "$W/agent.log" | head -1 | sed 's/^/  log: /'
echo
echo "A MISSING KEY on a readable path is the quiet one - the file is"
echo "written, with the words <no value> where the secret should be:"
agent '{{ with secret "wwr15v2/data/app" }}{{ .Data.data.nosuchfield }}{{ end }}'
printf '  rendered: "%s"\n' "$(cat "$W/out.txt" 2>/dev/null)"
echo
echo "Make the second one loud too:"
agent '{{ with secret "wwr15v2/data/app" }}{{ .Data.data.nosuchfield }}{{ end }}' \
      'error_on_missing_key = true'
if [ -e "$W/out.txt" ]; then
  printf '  with error_on_missing_key: "%s"\n' "$(cat "$W/out.txt")"
else
  echo "  with error_on_missing_key: no file written"
fi
grep -oiE "map has no entry|missing key" "$W/agent.log" | head -1 | sed 's/^/  log: /'

wwr_case "the sink file, and what is actually wrong with it"
agent '{{ with secret "wwr15v2/data/app" }}{{ .Data.data.db_password }}{{ end }}'
mode=$(stat -f '%Lp' "$W/token" 2>/dev/null || stat -c '%a' "$W/token" 2>/dev/null)
printf '  sink mode with no mode set: %s\n' "$mode"
printf '  first characters of the file: %s...\n' "$(cut -c1-10 "$W/token" 2>/dev/null)"
echo
echo "0640 by default, so the file is not world-readable - the usual"
echo "warning is aimed at the wrong half of the problem. What matters is"
echo "WHERE it is: that is a live token, on disk, surviving reboots."
echo "Set mode explicitly anyway, and put the sink on tmpfs:"
echo '  sink "file" { config = { path = "/run/vault/token", mode = 0640 } }'

wwr_case "the application does not notice a rotated secret"
vault write -f -field=secret_id auth/approle/role/wwr15/secret-id > "$W/secret_id"
vault kv put wwr15v2/app db_user=svc db_password=before-rotation >/dev/null
agent '{{ with secret "wwr15v2/data/app" }}{{ .Data.data.db_password }}{{ end }}'
printf '  file after first render : %s\n' "$(cat "$W/out.txt" 2>/dev/null || echo '(none)')"
vault kv put wwr15v2/app db_user=svc db_password=after-rotation >/dev/null
vault write -f -field=secret_id auth/approle/role/wwr15/secret-id > "$W/secret_id"
agent '{{ with secret "wwr15v2/data/app" }}{{ .Data.data.db_password }}{{ end }}'
printf '  file after the rotation : %s\n' "$(cat "$W/out.txt" 2>/dev/null || echo '(none)')"
echo
echo "The file changed. A process that read it at start-up did not, and"
echo "nothing told it to look again. Add command to signal a reload, or"
echo "use exec mode and let the agent own the process lifetime."

# Deliberately LAST. Repeated bad SecretIDs trip Vault's user lockout
# after five attempts, and everything afterwards fails with "permission
# denied" instead of its own error - which is how the first version of
# this script poisoned its own remaining cases. Chapter 7 has the detail.
wwr_case "error authenticating: invalid role or secret ID"
echo "remove_secret_id_file_after_reading defaults to TRUE. The agent"
echo "deletes the file after its first run, so a restart has nothing to"
echo "read - unless something re-supplies it."
cp "$W/secret_id" "$W/secret_id.bak"
printf 'not-a-real-secret-id\n' > "$W/secret_id"
agent '{{ with secret "wwr15v2/data/app" }}{{ .Data.data.db_password }}{{ end }}'
grep -oiE "invalid role or secret ID|error authenticating" "$W/agent.log" | head -1 | sed 's/^/  log: /'
vault write -f -field=secret_id auth/approle/role/wwr15/secret-id > "$W/secret_id"

vault delete auth/approle/role/wwr15 >/dev/null 2>&1 || true
vault secrets disable wwr15v2 >/dev/null 2>&1 || true
vault secrets disable wwr15v1 >/dev/null 2>&1 || true
vault policy delete wwr15 >/dev/null 2>&1 || true
wwr_done
