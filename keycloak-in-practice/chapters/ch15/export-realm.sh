#!/usr/bin/env bash
# Copy the meridian realm from the compose Keycloak into a
# KeycloakRealmImport for the Keycloak in the cluster. Chapter 15.
#
#   ./chapters/ch15/export-realm.sh
#   kubectl apply -f k8s/local/meridian-realm-import.json
#
# kc.sh export runs a second, short-lived Keycloak inside the running
# compose container, against the same database, and writes the realm as
# JSON: clients with their secrets, the directory connection with its
# bind password, and the realm's private signing keys. Treat the file
# like a key. It is written to k8s/local/, which .gitignore excludes,
# with mode 600.
#
# Users are skipped: after Chapter 12 every person lives in Active
# Directory, and the cluster's Keycloak imports them from there the first
# time they log in or the directory is synchronised.
#
# Two things do not survive the move and are changed on the way:
#   Kerberos  the keytab is a file in the compose container, and the
#             service principal names sso.meridian.test - a different
#             host. Switched off in the directory connection, and the
#             Kerberos step disabled in every flow. Chapter 15 says what
#             it would take to have it here too.
#   nothing else. The LDAP URL stays ldaps://dc.meridian.test:636,
#             which `make kind-link` makes reachable from the cluster,
#             and the Meridian root reaches the pod through the
#             truststores entry in k8s/base/keycloak.yaml.
set -euo pipefail

cd "$(dirname "$0")/../.."
REALM="${REALM:-meridian}"
OUT="k8s/local/$REALM-realm-import.json"
mkdir -p k8s/local
umask 077

echo "exporting realm $REALM from the compose Keycloak (about a minute)"
docker compose exec -T keycloak /opt/keycloak/bin/kc.sh export \
  --dir /tmp/kip-export --realm "$REALM" --users skip >/dev/null 2>&1 || {
  echo "kc.sh export failed; run it without the redirect to see why:" >&2
  echo "  docker compose exec keycloak /opt/keycloak/bin/kc.sh export --dir /tmp/kip-export --realm $REALM --users skip" >&2
  exit 1
}

docker compose exec -T keycloak cat "/tmp/kip-export/$REALM-realm.json" \
  | jq '
      # The directory connection: no Kerberos in the cluster.
      (.components["org.keycloak.storage.UserStorageProvider"][]?
        | select(.providerId == "ldap") | .config)
        |= (.allowKerberosAuthentication = ["false"]
            | .useKerberosForPasswordAuthentication = ["false"])
      # ...and no SPNEGO challenge in any flow.
      | (.authenticationFlows[].authenticationExecutions[]?
          | select(.authenticator == "auth-spnego") | .requirement)
          |= "DISABLED"
      | {apiVersion: "k8s.keycloak.org/v2alpha1",
         kind: "KeycloakRealmImport",
         metadata: {name: .realm},
         spec: {keycloakCRName: "meridian", realm: .}}' > "$OUT"

# Nothing of it stays behind in the container.
docker compose exec -T keycloak rm -rf /tmp/kip-export

jq -r '"wrote '"$OUT"': realm \(.spec.realm.realm), \(.spec.realm.clients | length) clients, \(.spec.realm.groups | length) groups, \(.spec.realm.components["org.keycloak.storage.UserStorageProvider"] | length) directory connection(s)"' "$OUT"
