#!/usr/bin/env bash
# Put the CA into every node's trust store.
#
# The pull is performed by the container runtime ON THE NODE, with the
# node's trust store. Making Harbor work from your laptop proves nothing
# about whether the cluster can pull from it - the failure is
# ImagePullBackOff with x509, several layers from its cause.
#
#   ./node-trust.sh kind      [cluster-name]
#   ./node-trust.sh minikube  [profile]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CA="$ROOT/certs/ca.crt"
[ -f "$CA" ] || { echo "missing $CA" >&2; exit 1; }

KIND="${1:?kind or minikube}"
NAME="${2:-harbor-lab}"

case "$KIND" in
  kind)
    command -v kind >/dev/null || { echo "kind not found" >&2; exit 1; }
    for node in $(kind get nodes --name "$NAME"); do
      echo "== $node"
      docker cp "$CA" "$node:/usr/local/share/ca-certificates/ca.crt"
      docker exec "$node" update-ca-certificates
      docker exec "$node" systemctl restart containerd
    done
    ;;
  minikube)
    command -v minikube >/dev/null || { echo "minikube not found" >&2; exit 1; }
    minikube cp "$CA" /usr/local/share/ca-certificates/ca.crt -p "$NAME"
    minikube ssh -p "$NAME" -- sudo update-ca-certificates
    minikube ssh -p "$NAME" -- sudo systemctl restart containerd
    ;;
  *) echo "usage: $0 kind|minikube [name]" >&2; exit 2 ;;
esac

cat <<'TXT'

Done. Delete any pod already in ImagePullBackOff - the backoff does not
retry immediately, and a pod that failed before the trust store changed
will keep failing for a while.

In a real cluster this is a node provisioning concern, not a kubectl
one. See Chapter 17.
TXT
