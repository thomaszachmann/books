#!/usr/bin/env bash
# Create a Harbor pull secret in a namespace, without the shell eating
# the robot name.
#
# A robot account is called robot$project+name. In double quotes a shell
# reads $project as a variable: unset, it substitutes nothing and the
# project name silently vanishes; set - and "platform" is not an
# unlikely variable name - it splices in the wrong value. Either way the
# pod reports 401 Unauthorized and says nothing about the cause.
#
#   ./pull-secret.sh apps 'robot$platform+cluster-pull' "$SECRET"
set -euo pipefail

NS="${1:?namespace}"
USER="${2:?robot name, in SINGLE quotes}"
PASS="${3:?robot secret}"
HOST="${HARBOR_HOSTNAME:-harbor.meridian.test}"

case "$USER" in
  *'$'*) ;;   # good: the $ survived, so it was quoted properly
  robot*)
    echo "warning: the name has no \$ in it." >&2
    echo "A Harbor robot is robot\$project+name. If you passed it in" >&2
    echo "double quotes, the shell has already eaten the project." >&2
    echo "Re-run with single quotes." >&2
    ;;
esac

kubectl get namespace "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"

kubectl -n "$NS" create secret docker-registry harbor \
  --docker-server="$HOST" \
  --docker-username="$USER" \
  --docker-password="$PASS" \
  --dry-run=client -o yaml | kubectl apply -f -

echo
echo "stored username, read back from the cluster:"
kubectl -n "$NS" get secret harbor \
  -o jsonpath='{.data.\.dockerconfigjson}' \
  | base64 -d | jq -r '.auths[].username' | sed 's/^/  /'

kubectl -n "$NS" patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"harbor"}]}' >/dev/null

cat <<TXT

Attached to the default service account in $NS, which means every pod
in that namespace can pull. Narrower is spec.imagePullSecrets on the
pod itself.

Secrets do not cross namespaces. The next namespace needs this again,
and so does the one after that - which is what Chapter 19 removes.
TXT
