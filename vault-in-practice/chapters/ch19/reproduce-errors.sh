#!/usr/bin/env bash
# Chapter 19 - the SSH certificate failures, on purpose.
#
# Needs the sshd container:  docker compose up -d sshd
# and the CA from setup-ssh-ca.sh.
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env

MOUNT="${WWR_SSH_MOUNT:-ssh-client-signer}"
ROLE="${WWR_SSH_ROLE:-wwr19}"
PORT="${WWR_SSH_PORT:-2222}"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
SSH="ssh -p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
     -o BatchMode=yes -o ConnectTimeout=5"

ssh-keygen -t ed25519 -f "$W/id" -N "" -q
sign() {  # sign <role> <principal> [ttl]
  vault write -field=signed_key "$MOUNT/sign/$1" \
    public_key=@"$W/id.pub" valid_principals="$2" ${3:+ttl="$3"} 2>&1
}

wwr_case "Permission denied (publickey) - the principal does not match"
sign "$ROLE" ubuntu > "$W/id-cert.pub" 2>/dev/null
echo "A certificate for the principal 'ubuntu' works:"
$SSH -i "$W/id" ubuntu@127.0.0.1 'echo "  logged in as $(whoami)"' 2>&1 | tail -1
echo
echo "The same key, signed for a different principal:"
if sign "$ROLE" nobody > "$W/id-cert.pub" 2>"$W/err"; then
  $SSH -i "$W/id" ubuntu@127.0.0.1 'echo in' 2>&1 | grep -iE "permission denied|publickey" | head -1 | sed 's/^/  /'
else
  echo "  the role refused to sign it:"
  grep -oE 'principal ".*" not in allowed_users list|not in allowed_users' "$W/err" | head -1 | sed 's/^/  /'
  echo "  which is the control doing its job one step earlier."
fi

wwr_case "the signed key file contains an error message"
echo "vault write -field=signed_key writes whatever it gets. When the"
echo "command fails, the FILE gets the error and ssh gets nonsense:"
sign "$ROLE" nobody > "$W/id-cert.pub" 2>&1 || true
head -c 90 "$W/id-cert.pub" | sed 's/^/  /'; echo
echo
echo "ssh then reports something that has nothing to do with the cause:"
$SSH -i "$W/id" ubuntu@127.0.0.1 'echo in' 2>&1 | grep -viE "^Warning|known hosts" | head -2 | sed 's/^/  /'
echo "Always check the first bytes of a signed key. It starts ssh-rsa-cert"
echo "or ssh-ed25519-cert. Anything else is a message, not a key."

wwr_case "the certificate expired"
sign "$ROLE" ubuntu 30s > "$W/id-cert.pub" 2>/dev/null
ssh-keygen -Lf "$W/id-cert.pub" 2>/dev/null | grep -A1 -E "Valid:|Principals:" | sed 's/^/  /'
echo "ssh-keygen -Lf is the first command to run on any certificate that"
echo "does not work. It answers principals, extensions and validity at once."

wwr_case "the certificate has no permit-pty"
vault write "$MOUNT/roles/wwr19-nopty" - >/dev/null 2>&1 <<'ROLE'
{ "algorithm_signer":"rsa-sha2-256", "allow_user_certificates": true,
  "allowed_users": "ubuntu", "default_user": "ubuntu",
  "key_type": "ca", "default_extensions": {}, "ttl": "30m" }
ROLE
if sign wwr19-nopty ubuntu > "$W/id-cert.pub" 2>/dev/null; then
  echo "Extensions on this certificate:"
  ssh-keygen -Lf "$W/id-cert.pub" 2>/dev/null | sed -n '/Extensions/,/^$/p' | head -4 | sed 's/^/  /'
  echo "A command still runs:"
  $SSH -i "$W/id" ubuntu@127.0.0.1 'echo "  non-interactive: ok"' 2>&1 | tail -1
  echo "An interactive shell does not open - and the authentication"
  echo "succeeded, which is what makes it confusing."
fi
vault delete "$MOUNT/roles/wwr19-nopty" >/dev/null 2>&1 || true

wwr_case "ssh_exchange_identification: Connection closed"
echo "The container is still installing openssh. There is nothing to fix"
echo "but time - and the way to see it is the server's own log:"
echo '  $ docker compose logs sshd --tail 5'
echo
echo "Not reproduced: AWS credentials that work but cannot be revoked."
echo "That needs an AWS account, and the failure is IAM's, not Vault's."
wwr_done
