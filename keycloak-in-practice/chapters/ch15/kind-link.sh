#!/usr/bin/env bash
# Make the book's names work inside the kind cluster. Chapter 15.
# Run it as `make kind-link`; it is idempotent.
#
# Three names have to mean the same thing inside the cluster as on your
# laptop, and none of them may go through a port on your laptop:
#
#   sso.meridian.test      the compose Keycloak   (port 443)
#   dc.meridian.test       the compose directory  (LDAPS 636)
#   sso-k8s.meridian.test  the Keycloak in the cluster, via the ingress
#                          on the node            (port 8443)
#
# The first two: the compose containers join Docker's `kind` network,
# the one the cluster's node sits on, under their public names as
# network aliases - the way kind documents a local registry. The node
# and every pod (through CoreDNS, which forwards to Docker's resolver)
# then find them directly.
#
# The third is the node itself. CoreDNS answers it for pods by
# rewriting it to the node's container name; the API server, which runs
# on the node and does not use CoreDNS, gets a line in the node's
# /etc/hosts.
#
# `docker compose up` that recreates keycloak or dc drops them from the
# network, and a restart of the node container rewrites its /etc/hosts.
# Run this again after either; `make up` and `make ad-up` do it for you
# once the cluster exists.
set -euo pipefail

cd "$(dirname "$0")/../.."
NET=kind
NODE="${KIND_NODE:-meridian-control-plane}"

if ! docker network inspect "$NET" >/dev/null 2>&1; then
  echo "no Docker network '$NET' yet - create the cluster first (Chapter 15)"
  exit 1
fi

link() {
  local svc="$1" alias="$2" cid aliases
  cid=$(docker compose ps -q "$svc" 2>/dev/null || true)
  if [ -z "$cid" ]; then
    echo "  skip    $svc is not running"
    return
  fi
  aliases=$(docker inspect -f \
    "{{with index .NetworkSettings.Networks \"$NET\"}}{{json .Aliases}}{{else}}none{{end}}" "$cid")
  if [ "$aliases" = none ]; then
    docker network connect --alias "$alias" "$NET" "$cid"
    echo "  linked  $alias -> $svc"
  elif printf '%s' "$aliases" | grep -q "\"$alias\""; then
    echo "  ok      $alias -> $svc"
  else
    # On the network without the name: reconnect with it.
    docker network disconnect "$NET" "$cid"
    docker network connect --alias "$alias" "$NET" "$cid"
    echo "  linked  $alias -> $svc (reconnected)"
  fi
}

echo "Compose containers on the '$NET' network"
link keycloak sso.meridian.test
link dc dc.meridian.test

if ! docker inspect "$NODE" >/dev/null 2>&1; then
  echo "no node $NODE - skipping sso-k8s.meridian.test"
  exit 0
fi

echo "sso-k8s.meridian.test inside the cluster"
# Pods: one rewrite line in CoreDNS. The node's container name is what
# Docker's resolver knows, so no address is written down anywhere.
if kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}' \
     | grep -q 'sso-k8s.meridian.test'; then
  echo "  ok      CoreDNS rewrites it to $NODE"
else
  kubectl -n kube-system get configmap coredns -o json \
    | jq --arg node "$NODE" '.data.Corefile |= sub("ready\n"; "ready\n    rewrite name exact sso-k8s.meridian.test \($node)\n")' \
    | kubectl replace -f - >/dev/null
  kubectl -n kube-system rollout restart deployment coredns >/dev/null
  echo "  added   CoreDNS rewrite sso-k8s.meridian.test -> $NODE"
fi

# The API server: the node's hosts file, with the node's own address.
docker exec "$NODE" sh -c '
  grep -q " sso-k8s.meridian.test$" /etc/hosts && { echo "  ok      node /etc/hosts"; exit 0; }
  ip=$(getent ahostsv4 "$(hostname)" | head -1 | cut -d" " -f1)
  echo "$ip sso-k8s.meridian.test" >> /etc/hosts
  echo "  added   node /etc/hosts: $ip sso-k8s.meridian.test"'
