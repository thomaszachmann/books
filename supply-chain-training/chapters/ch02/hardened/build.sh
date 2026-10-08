#!/usr/bin/env bash
# Gehärteter Build für demo-app (Lab, Kapitel 2)
set -euo pipefail

IMAGE="localhost:5001/demo-app"
VERSION="${VERSION:?Bitte VERSION setzen, z. B. VERSION=1.0.1}"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct \
  2>/dev/null || echo 1700000000)}"

docker build --build-arg SOURCE_DATE_EPOCH -t "${IMAGE}:${VERSION}" .
docker push "${IMAGE}:${VERSION}"

DIGEST="$(crane digest "${IMAGE}:${VERSION}")"
echo "${IMAGE}@${DIGEST}" | tee image.ref
