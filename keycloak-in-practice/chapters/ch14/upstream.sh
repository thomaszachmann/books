#!/usr/bin/env bash
# A second realm that plays the part of the corporate identity provider.
# Chapter 14.
#
# Why a realm and not a second product: Chapter 6 demonstrated that two
# realms are two identity providers that happen to share a hostname -
# different keys, different issuer, no shared users. That is exactly what
# an upstream IdP is from Keycloak's point of view, and it costs no
# container. Where real ADFS or Entra ID differ, the chapter says so.
set -euo pipefail

cd "$(dirname "$0")/../.."
kc() { docker compose exec -T keycloak /opt/keycloak/bin/kcadm.sh "$@"; }

UP=meridian-corp
SECRET=upstream-secret-change-me

echo "realm $UP"
kc create realms -s realm="$UP" -s enabled=true \
   -s displayName="Meridian Corporate IdP" 2>/dev/null \
  || echo "  exists"

echo "client for Keycloak to use"
kc create clients -r "$UP" \
   -s clientId=keycloak-broker \
   -s enabled=true -s publicClient=false \
   -s "secret=$SECRET" \
   -s standardFlowEnabled=true \
   -s 'redirectUris=["https://sso.meridian.test/realms/meridian/broker/corp/endpoint"]' \
   2>/dev/null || echo "  exists"

echo "a person who exists only upstream"
kc create users -r "$UP" -s username=jonas -s enabled=true \
   -s firstName=Jonas -s lastName=Feld \
   -s email=jonas@meridian.test -s emailVerified=true \
   2>/dev/null || echo "  exists"
kc set-password -r "$UP" --username jonas \
   --new-password 'Upstream-2026' 2>/dev/null || true

cat <<NEXT

Upstream ready.
  realm    $UP
  client   keycloak-broker
  secret   $SECRET
  user     jonas / Upstream-2026

The redirect URI above is not decorative. Keycloak's brokering endpoint
is /realms/<realm>/broker/<alias>/endpoint, and the alias is chosen when
the identity provider is created. Choose it first, register it upstream,
then create it - in that order, or the first login fails at the far end
where you cannot see the log.
NEXT
