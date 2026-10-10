#!/usr/bin/env bash
# Lädt große Images einmal vom Host in alle kind-Nodes.
# Spart Pulls bei jedem Pod-Neustart und nach jedem Cluster-Neubau.
# docker save --platform: nötig mit dem containerd-Image-Store (Docker 29),
# sonst bricht "kind load docker-image" mit "content digest ... not found" ab.
set -euo pipefail

CLUSTER=${CLUSTER:-ki-lab}
PLATFORM=$(docker version --format '{{.Server.Os}}/{{.Server.Arch}}')
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

IMAGES=(
  ghcr.io/ggml-org/llama.cpp:server-b11515
)

for img in "${IMAGES[@]}"; do
  docker pull --platform "$PLATFORM" "$img"
  docker save --platform "$PLATFORM" "$img" -o "$TMP/image.tar"
  kind load image-archive "$TMP/image.tar" --name "$CLUSTER"
  rm -f "$TMP/image.tar"
done
