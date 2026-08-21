#!/usr/bin/env bash
# Chapter 7 - every error the chapter prints, on purpose.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env

vault auth enable userpass >/dev/null 2>&1 || true
vault auth enable -path=wwr-contractors userpass >/dev/null 2>&1 || true
vault auth enable approle >/dev/null 2>&1 || true
vault write auth/wwr-contractors/users/sam password=lab-pw policies=default >/dev/null
vault write auth/approle/role/wwr-role token_ttl=1h \
  secret_id_num_uses=1 secret_id_ttl=10m >/dev/null

wwr_case "invalid username or password for a user you just created"
echo "sam exists - on wwr-contractors/, not on userpass/."
VAULT_TOKEN='' wwr_expect "invalid username or password" \
  vault login -method=userpass username=sam password=lab-pw
echo "Read the URL, not the message. With the right mount:"
VAULT_TOKEN='' vault login -method=userpass -path=wwr-contractors \
  username=sam password=lab-pw -format=json >/dev/null \
  && echo "   ok: login succeeds on the correct mount"

wwr_case "403 permission denied or 404 no handler for route on login"
echo "The method is not enabled at that mount. Without a token:"
VAULT_TOKEN='' wwr_expect "permission denied" \
  vault login -method=userpass -path=not-enabled username=sam password=lab-pw
echo "With a token, the message is the informative one:"
wwr_expect "no handler for route" \
  vault write auth/not-enabled/login/sam password=lab-pw
echo "Either way, vault auth list settles it:"
vault auth list | sed -n '1,2p;/wwr-contractors/p'

wwr_case "invalid role or secret ID - a spent SecretID"
RID=$(vault read -field=role_id auth/approle/role/wwr-role/role-id)
SID=$(vault write -f -field=secret_id auth/approle/role/wwr-role/secret-id)
echo "num_uses is 1, so the first login works:"
vault write -f -field=token auth/approle/login \
  role_id="$RID" secret_id="$SID" >/dev/null && echo "   ok: first login"
echo "and the second does not:"
wwr_expect "invalid role or secret ID" vault write auth/approle/login \
  role_id="$RID" secret_id="$SID"

wwr_case "the same message when only the RoleID is wrong"
SID=$(vault write -f -field=secret_id auth/approle/role/wwr-role/secret-id)
echo "A valid SecretID with a RoleID that does not exist:"
wwr_expect "invalid role or secret ID" vault write auth/approle/login \
  role_id="00000000-0000-0000-0000-000000000000" secret_id="$SID"
echo "Vault will not say which half was wrong - that would let an"
echo "attacker enumerate RoleIDs. Verify yours separately:"
echo "  \$ vault read auth/approle/role/wwr-role/role-id"

wwr_case "tuning a mount does not change existing sessions"
# Start from a known value: a previous run may have tuned this mount,
# and then the demonstration shows nothing.
vault auth tune -default-lease-ttl=1h wwr-contractors/ >/dev/null
T=$(VAULT_TOKEN='' vault login -field=token -method=userpass \
      -path=wwr-contractors username=sam password=lab-pw)
ttl() { VAULT_TOKEN=$1 vault token lookup -format=json | jq -r .data.creation_ttl; }
printf '  issued while the mount said 1h : %s s\n' "$(ttl "$T")"
vault auth tune -default-lease-ttl=30m wwr-contractors/ >/dev/null
printf '  the same token after the tune  : %s s\n' "$(ttl "$T")"
NEW=$(VAULT_TOKEN='' vault login -field=token -method=userpass \
      -path=wwr-contractors username=sam password=lab-pw)
printf '  a token issued after the tune  : %s s\n' "$(ttl "$NEW")"
echo "The existing token keeps the lifetime it was given. It always will."
echo "To force the change, revoke the outstanding tokens by accessor."

vault auth disable wwr-contractors >/dev/null 2>&1 || true
wwr_case "after a few bad SecretIDs, the correct one is refused too"
vault auth enable -path=wwr-lock approle >/dev/null 2>&1 || true
vault write auth/wwr-lock/role/r token_ttl=5m secret_id_num_uses=0 >/dev/null
RID=$(vault read -field=role_id auth/wwr-lock/role/r/role-id)
GOOD=$(vault write -f -field=secret_id auth/wwr-lock/role/r/secret-id)
vault write -field=token auth/wwr-lock/login role_id="$RID" secret_id="$GOOD" >/dev/null \
  && echo "  a valid login works to begin with"
for i in 1 2 3 4 5 6; do
  m=$(vault write auth/wwr-lock/login role_id="$RID" secret_id=wrong 2>&1 \
        | grep -oE "invalid role or secret ID|permission denied" | head -1)
  printf '  attempt %s: %s\n' "$i" "$m"
done
echo
echo "Now with the SAME valid SecretID that worked a moment ago:"
vault write auth/wwr-lock/login role_id="$RID" secret_id="$GOOD" 2>&1 \
  | grep -E "Code:|permission denied" | sed 's/^/  /'
echo
echo "The entity is locked out - five failures in fifteen minutes, by"
echo "default, for fifteen minutes. The message stopped describing the"
echo "credential at exactly the moment you supplied a correct one."
echo "Check before you touch a policy:"
vault read -format=json sys/locked-users 2>/dev/null \
  | jq -r '"  locked entries: \(.data.by_namespace[]?.counts // 0)"' | head -1
vault auth disable wwr-lock >/dev/null 2>&1 || true

vault delete auth/approle/role/wwr-role >/dev/null 2>&1 || true
wwr_done
