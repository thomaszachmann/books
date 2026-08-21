#!/usr/bin/env bash
# The way out of Chapter 20's deadlock, made before it is needed.
#
# A Vault auth method that does not involve Keycloak, for one named
# human, with a policy that can repair things and nothing else. The
# equivalent of Chapter 16's kubeconfig, and held the same way: offline,
# by two people, with its use alerted on.
#
#   ./breakglass.sh create     make it
#   ./breakglass.sh test       prove it works, without using it
set -euo pipefail

cd "$(dirname "$0")/../.."
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=${VAULT_TOKEN:-root}
v() { docker compose exec -T -e VAULT_ADDR -e VAULT_TOKEN vault vault "$@"; }

case "${1:-create}" in
create)
  v policy write breakglass - <<'HCL'
# Enough to repair the identity path and nothing else.
path "sys/mounts"                { capabilities = ["read","list"] }
path "auth/oidc/config"          { capabilities = ["read","update"] }
path "auth/oidc/role/*"          { capabilities = ["read","update"] }
path "identity/group*"           { capabilities = ["read","update","list"] }
path "database/static-creds/*"   { capabilities = ["read"] }
path "sys/leases/revoke/*"       { capabilities = ["update"] }
HCL
  v auth enable userpass 2>/dev/null || echo "  userpass enabled"
  echo -n "password for the break-glass account: "
  read -rs PW; echo
  v write auth/userpass/users/breakglass \
    password="$PW" token_policies=breakglass token_ttl=30m
  cat <<'NEXT'

Created. Now do the part that matters:
  - write the password down, offline, in two places
  - alert on any login through auth/userpass in Chapter 24
  - test it every quarter, with ./breakglass.sh test
An untested break-glass path is a belief, not a control.
NEXT
  ;;
test)
  # Prove it works without spending it: log in, read one thing, revoke.
  echo -n "break-glass password: "
  read -rs PW; echo
  T=$(v write -field=token auth/userpass/login/breakglass \
        password="$PW")
  VAULT_TOKEN=$T v read -format=json sys/mounts >/dev/null \
    && echo "break-glass path works"
  VAULT_TOKEN=$T v token revoke -self
  echo "token revoked; the password is unchanged and still valid"
  ;;
*) echo "usage: $0 [create|test]" >&2; exit 2 ;;
esac
