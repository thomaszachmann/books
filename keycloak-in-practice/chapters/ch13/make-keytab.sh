#!/usr/bin/env bash
# A service principal for Keycloak, and its keytab. Chapter 13.
#
# Kerberos identifies services, not hosts. HTTP/sso.meridian.test is the
# name the client asks the KDC for a ticket to, so it must match the
# hostname in the URL exactly - not an alias, not an address.
set -euo pipefail

cd "$(dirname "$0")/../.."
dc() { docker compose exec -T dc "$@"; }

SVC=keycloak-svc
SPN=HTTP/sso.meridian.test
PW="${AD_ADMIN_PASSWORD:-Meridian-Lab-2026}"

echo "service account"
dc samba-tool user create "$SVC" "$PW" \
   --use-username-as-cn 2>/dev/null || echo "  exists"

echo "service principal name"
dc samba-tool spn add "$SPN" "$SVC" 2>/dev/null || echo "  exists"

# Without this the account gets RC4 keys only, and a modern JDK refuses
# them: "Encryption type RC4 with HMAC is not supported/enabled". The
# message names an algorithm and not a policy, and it arrives as a
# failed SPNEGO login with no other clue. 24 is AES128 plus AES256.
echo "encryption types"
docker compose exec -T client sh -c "ldapmodify -x \
  -H ldaps://dc.meridian.test \
  -D 'Administrator@MERIDIAN.TEST' -w '$PW'" >/dev/null <<LDIF
dn: CN=$SVC,CN=Users,DC=meridian,DC=test
changetype: modify
replace: msDS-SupportedEncryptionTypes
msDS-SupportedEncryptionTypes: 24
LDIF

# The keys are derived when the password is set, so it has to be set
# again after changing the supported types. Check the result rather than
# trusting it - klist -ke names the algorithms.
dc samba-tool user setpassword "$SVC" --newpassword="$PW" >/dev/null

echo "keytab"
dc rm -f /tmp/keycloak.keytab
dc samba-tool domain exportkeytab /tmp/keycloak.keytab \
   --principal="$SPN"

mkdir -p pki
docker compose cp dc:/tmp/keycloak.keytab pki/keycloak.keytab
chmod 600 pki/keycloak.keytab

echo
echo "what is in it:"
dc klist -ke /tmp/keycloak.keytab 2>/dev/null | tail -3

if dc klist -ke /tmp/keycloak.keytab 2>/dev/null | grep -q arcfour; then
  cat <<'WARN'

  WARNING: this keytab holds RC4 keys. A modern JDK refuses them and
  SPNEGO fails with "Encryption type RC4 with HMAC is not
  supported/enabled" - a message about an algorithm, arriving as a
  failed login with no other clue. The encryption-type step above did
  not take effect.
WARN
fi
echo
cat <<'NEXT'
The keytab holds the service key. Its version - the KVNO - increases
every time that account's password changes, and a keytab exported
before a change stops working without saying so. Re-export after any
password reset on the service account.
NEXT
