#!/usr/bin/env bash
# Register Harbor as a client of the meridian realm. Chapter 17, Step 2.
#
#   ./chapters/ch17/harbor-client.sh
#   HARBOR_URL=https://harbor.example.test ./chapters/ch17/harbor-client.sh
#
# This is the Keycloak half. The Harbor half is Book Two's
# chapters/ch07/set-oidc.sh (harbor-in-practice), which takes exactly
# what this script prints:
#
#   OIDC_ENDPOINT=https://sso.meridian.test/realms/meridian \
#   OIDC_CLIENT_ID=harbor OIDC_CLIENT_SECRET=<printed below> \
#     ./chapters/ch07/set-oidc.sh
#
# Three details decide whether Harbor's login works:
#   redirect URI  Harbor's callback is /c/oidc/callback - not
#                 /oidc/callback, not /login
#   groups        Harbor asks for the scopes openid,profile,email,groups;
#                 `groups` is an optional scope in this realm, attached
#                 here as a default so the claim is always there
#   the secret    Harbor is a server and keeps one. Keycloak generates
#                 it; this script prints it once, to your terminal only
set -euo pipefail

cd "$(dirname "$0")/../.."
# shellcheck source=chapters/kcadm.sh
source chapters/kcadm.sh

HARBOR_URL="${HARBOR_URL:-https://harbor.meridian.test}"
REALM="${REALM:-meridian}"

if [ -n "$(kcadm get clients -r "$REALM" -q clientId=harbor --fields id --format csv --noquotes)" ]; then
  echo "client harbor exists already; not changing it" >&2
else
  kcadm create clients -r "$REALM" \
    -s clientId=harbor -s enabled=true \
    -s publicClient=false \
    -s standardFlowEnabled=true -s directAccessGrantsEnabled=false \
    -s "redirectUris=[\"$HARBOR_URL/c/oidc/callback\"]" \
    -s "attributes={\"post.logout.redirect.uris\":\"$HARBOR_URL/*\"}" >/dev/null 2>&1
  echo "client harbor created, redirect $HARBOR_URL/c/oidc/callback"
fi

HID=$(kcadm get clients -r "$REALM" -q clientId=harbor --fields id --format csv --noquotes)
GROUPS_SCOPE=$(kcadm get client-scopes -r "$REALM" | jq -r '.[] | select(.name=="groups") | .id')
kcadm update "clients/$HID/default-client-scopes/$GROUPS_SCOPE" -r "$REALM" >/dev/null

echo "default scopes: $(kcadm get "clients/$HID/default-client-scopes" -r "$REALM" | jq -r '[.[].name] | sort | join(" ")')"
echo
echo "For Book Two's set-oidc.sh:"
echo "  OIDC_ENDPOINT=https://sso.meridian.test/realms/$REALM"
echo "  OIDC_CLIENT_ID=harbor"
echo "  OIDC_CLIENT_SECRET=$(kcadm get "clients/$HID/client-secret" -r "$REALM" | jq -r .value)"
