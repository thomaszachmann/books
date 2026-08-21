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

echo "keytab"
dc rm -f /tmp/keycloak.keytab
dc samba-tool domain exportkeytab /tmp/keycloak.keytab \
   --principal="$SPN"

mkdir -p pki
docker compose cp dc:/tmp/keycloak.keytab pki/keycloak.keytab
chmod 600 pki/keycloak.keytab

echo
echo "what is in it:"
docker compose exec -T client klist -k /keytab 2>/dev/null \
  || echo "  (mount it into the client to inspect: see compose.yaml)"
echo
cat <<'NEXT'
The keytab holds the service key. Its version - the KVNO - increases
every time that account's password changes, and a keytab exported
before a change stops working without saying so. Re-export after any
password reset on the service account.
NEXT
