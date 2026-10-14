# shellcheck shell=bash
# Source this, do not run it:  source chapters/kcadm.sh
#
# Chapter 3 types the admin CLI in full so you can see what it is.
# From Chapter 4 the book uses this function instead.
kcadm() {
  docker compose exec -T keycloak \
    /opt/keycloak/bin/kcadm.sh "$@"
}

# The realm's issuer URL. Chapter 4 introduces it; every later chapter
# that talks to the realm over HTTP uses it as $ISS. It lives here
# because shell variables do not survive a new terminal, and the labs
# are not read in one sitting.
# shellcheck disable=SC2034  # used by the shell that sources this
ISS=https://sso.meridian.test/realms/meridian

# Part IV has a second Keycloak, the one the operator runs in the
# cluster (Chapter 15). kcadm above never reaches it: it is
# `docker compose exec`, and compose is sso.meridian.test. For the
# cluster's instance, sso-k8s.meridian.test, use kcadm_k8s - same
# arguments, different server. It runs the CLI inside the pod,
# and logs in with the administrator from the secret keycloak-admin
# (Chapter 15, Step 3) whenever the CLI has not been used for twenty
# minutes, so a restarted pod or an expired CLI session never leaves a
# command failing quietly.
#   kcadm_k8s get realms/meridian --fields displayName
# shellcheck disable=SC2034  # used by the shell that sources this
ISS_K8S=https://sso-k8s.meridian.test:8443/realms/meridian
kcadm_k8s() {
  local user pass
  user=$(kubectl get secret keycloak-admin \
    -o jsonpath='{.data.username}' | base64 -d)
  pass=$(kubectl get secret keycloak-admin \
    -o jsonpath='{.data.password}' | base64 -d)
  # shellcheck disable=SC2016  # expanded by the shell in the pod
  kubectl exec -i meridian-0 -- sh -c '
    c=/tmp/kcadm-k8s.config
    # Log in again unless the CLI used its session in the last 20 min.
    if [ -z "$(find $c -mmin -20 2>/dev/null)" ]; then
      /opt/keycloak/bin/kcadm.sh config credentials --config $c \
        --server http://localhost:8080 --realm master \
        --user "$1" --password "$2" >/dev/null 2>&1 \
        || { echo "kcadm_k8s: login to the cluster Keycloak failed" >&2; exit 1; }
    fi
    shift 2
    exec /opt/keycloak/bin/kcadm.sh "$@" --config $c' kcadm "$user" "$pass" "$@"
}
