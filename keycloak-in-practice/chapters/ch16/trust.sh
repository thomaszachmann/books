#!/usr/bin/env bash
# Put the Chapter 2 root into the control plane node's trust store.
# Chapter 16.
#
# The API server is an OIDC *validator*: it fetches the discovery
# document and the JWKS itself, over TLS, from inside the cluster. If it
# does not trust the issuer's certificate it cannot do that, and the
# failure appears as "authentication failed" on the client - which names
# neither TLS nor the issuer.
#
# In a managed cluster you cannot do this. That is not a gap in the lab;
# it is the reason Chapter 16 treats trust as a design question.
set -euo pipefail

cd "$(dirname "$0")/../.."
NODE="${1:-meridian-control-plane}"

docker cp pki/ca.crt "$NODE:/usr/local/share/ca-certificates/meridian.crt"
docker exec "$NODE" update-ca-certificates
echo "root installed on $NODE"

# The API server reads the trust store at start, so it has to be
# restarted. On kubeadm the static pod restarts when its manifest is
# touched.
docker exec "$NODE" sh -c \
  'touch /etc/kubernetes/manifests/kube-apiserver.yaml'
echo "api server restarting - give it thirty seconds"
