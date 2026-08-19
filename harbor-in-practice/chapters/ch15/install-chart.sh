#!/usr/bin/env bash
# Install the Harbor chart with your own certificate and a real secretKey.
#
# Three defaults this deliberately overrides:
#
#   certSource: auto   generates a certificate signed by a key that
#                      exists nowhere else. Nothing trusts it, and the
#                      symptom is ImagePullBackOff on a pod rather than
#                      a TLS error in a browser.
#   secretKey          ships as "not-a-secure-key" and must be exactly
#                      16 characters.
#   registry PVC 5Gi   a registry-sized default it is not.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$ROOT/scripts/versions.sh"

NS="${NS:-harbor}"
HOST="${HARBOR_HOSTNAME:-harbor.meridian.test}"

# The chart's own version carries no v - that is the Git tag convention.
# helm --version v1.19.2 finds nothing.
CHART_VERSION="${HARBOR_CHART_VERSION#v}"

for f in "$ROOT/certs/harbor.crt" "$ROOT/certs/harbor.key"; do
  [ -f "$f" ] || { echo "missing $f - run chapters/ch02/make-certs.sh" >&2
                   exit 1; }
done

kubectl get namespace "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"

kubectl -n "$NS" get secret harbor-tls >/dev/null 2>&1 || \
  kubectl -n "$NS" create secret tls harbor-tls \
    --cert="$ROOT/certs/harbor.crt" --key="$ROOT/certs/harbor.key"

helm repo add harbor https://helm.goharbor.io >/dev/null 2>&1 || true
helm repo update >/dev/null

echo "installing chart $CHART_VERSION (Harbor $HARBOR_VERSION) into $NS"
helm upgrade --install harbor harbor/harbor -n "$NS" \
  --version "$CHART_VERSION" \
  -f "$ROOT/k8s/values-harbor.yaml" \
  --set "expose.ingress.hosts.core=$HOST" \
  --set "externalURL=https://$HOST" \
  --set "secretKey=$(openssl rand -hex 8)"

cat <<TXT

Installed. Before a pod can pull from this registry, three things must
be true, and only the first two are done:

  1. the name resolves            on the NODE, not on your laptop
  2. the CA is trusted            by the node's container runtime
  3. a credential exists          in the pod's namespace - Chapter 16

Run ./node-trust.sh to do the second one, and expect ImagePullBackOff
until you have.
TXT
