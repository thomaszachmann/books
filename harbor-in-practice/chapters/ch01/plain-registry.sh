#!/usr/bin/env bash
# Chapter 1, steps 2 to 5. Start the reference registry, push an image,
# and read back the digest the registry assigned.
set -euo pipefail

REG=localhost:5000
REPO=meridian/tracking
TAG=2.4.1

OCI='application/vnd.oci.image.manifest.v1+json'
V2='application/vnd.docker.distribution.manifest.v2+json'

echo "== step 2: start a registry"
# REGISTRY_STORAGE_DELETE_ENABLED is not the default. The reference
# registry ships config-example.yml, which has no delete section; only
# config-dev.yml turns deletion on. Without this variable the DELETE in
# step 8 returns 405 UNSUPPORTED rather than 202 - which is worth
# knowing in its own right, and is why the book now sets it explicitly.
docker rm -f plain-registry >/dev/null 2>&1 || true
docker run -d --rm --name plain-registry -p 5000:5000 \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  registry:2
until curl -sf "http://$REG/v2/" >/dev/null; do sleep 1; done
echo "registry up on $REG"

echo
echo "== step 3: push something"
docker pull -q alpine:3.20
docker tag alpine:3.20 "$REG/$REPO:$TAG"
docker push "$REG/$REPO:$TAG"

echo
echo "== step 4: ask the registry what it has"
curl -s "http://$REG/v2/_catalog"; echo
curl -s "http://$REG/v2/$REPO/tags/list"; echo

echo
echo "== step 5: read the digest back"
curl -sI -H "Accept: $OCI" -H "Accept: $V2" \
  "http://$REG/v2/$REPO/manifests/$TAG" \
  | grep -i docker-content-digest

echo
echo "Write that digest down. Now run ./move-tag.sh"
