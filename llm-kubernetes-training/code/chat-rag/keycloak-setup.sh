#!/usr/bin/env bash
# Realm ki-lab, Client open-webui, Gruppen-Claim, Gruppen und zwei Lab-Benutzer
set -euo pipefail
KC="kubectl -n keycloak exec deploy/keycloak -- /opt/keycloak/bin/kcadm.sh"
ADMIN_PW=$(kubectl -n keycloak get secret keycloak-admin \
  -o jsonpath='{.data.password}' | base64 -d)

$KC config credentials --server http://localhost:8080 --realm master \
  --user admin --password "$ADMIN_PW"
$KC create realms -s realm=ki-lab -s enabled=true

R1=https://chat.lab.internal/oauth/oidc/callback
R2=https://chat.lab.internal/oauth/oidc/login/callback
# directAccessGrants nur fürs Lab (Token per curl prüfen), danach abschalten
$KC create clients -r ki-lab -s clientId=open-webui -s enabled=true \
  -s publicClient=false -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=true \
  -s "redirectUris=[\"$R1\",\"$R2\"]" \
  -s 'webOrigins=["https://chat.lab.internal"]'
CID=$($KC get clients -r ki-lab -q clientId=open-webui --fields id \
  --format csv --noquotes)

# Gruppen als flache Liste im Claim "groups" (ID-Token, Access-Token, Userinfo)
$KC create "clients/$CID/protocol-mappers/models" -r ki-lab \
  -s name=groups -s protocol=openid-connect \
  -s protocolMapper=oidc-group-membership-mapper \
  -s 'config."claim.name"=groups' -s 'config."full.path"=false' \
  -s 'config."id.token.claim"=true' -s 'config."access.token.claim"=true' \
  -s 'config."userinfo.token.claim"=true'

for g in ki-users ki-admins team-plattform; do
  $KC create groups -r ki-lab -s name="$g"
done

add_user() {  # $1=user $2=Lab-Passwort $3...=Gruppen
  local u=$1 pw=$2; shift 2
  $KC create users -r ki-lab -s username="$u" -s enabled=true \
    -s email="$u@lab.internal" -s emailVerified=true \
    -s firstName="$u" -s lastName=Lab
  $KC set-password -r ki-lab --username "$u" --new-password "$pw"
  local uid gid
  uid=$($KC get users -r ki-lab -q username="$u" -q exact=true --fields id \
    --format csv --noquotes)
  for g in "$@"; do
    gid=$($KC get groups -r ki-lab -q search="$g" -q exact=true --fields id \
      --format csv --noquotes)
    $KC update "users/$uid/groups/$gid" -r ki-lab -s realm=ki-lab \
      -s userId="$uid" -s groupId="$gid" -n
  done
}
add_user anna lab-anna-1234 ki-admins team-plattform   # Lab-Passwort
add_user ben  lab-ben-1234  ki-users  team-plattform   # Lab-Passwort
add_user gast lab-gast-1234                            # ohne Gruppe

$KC get "clients/$CID/client-secret" -r ki-lab --fields value \
  --format csv --noquotes
