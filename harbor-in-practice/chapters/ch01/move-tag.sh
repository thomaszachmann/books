#!/usr/bin/env bash
# Chapter 1, step 6. Push entirely different software under exactly the
# same tag, and watch nothing object.
#
# This is Meridian's production question reproduced on your laptop.
set -euo pipefail

REG=localhost:5000
REPO=meridian/tracking
TAG=2.4.1

OCI='application/vnd.oci.image.manifest.v1+json'
V2='application/vnd.docker.distribution.manifest.v2+json'

digest() {
  curl -sI -H "Accept: $OCI" -H "Accept: $V2" \
    "http://$REG/v2/$REPO/manifests/$TAG" \
    | awk -F': ' '/[Dd]ocker-[Cc]ontent-[Dd]igest/ {print $2}' \
    | tr -d '\r'
}

before=$(digest)
echo "before: $before"

docker pull -q busybox:1.36
docker tag busybox:1.36 "$REG/$REPO:$TAG"
docker push "$REG/$REPO:$TAG" >/dev/null
echo "pushed busybox under the same tag"

after=$(digest)
echo "after:  $after"

echo
if [ "$before" = "$after" ]; then
  echo "Digests match. That is not expected - did the push fail?"
  exit 1
fi

cat <<'TXT'
The tag did not change. The software did.

No warning was printed, no permission was required, and nothing
anywhere recorded that it happened.

A tag is a label. A digest is the identity.

The old image is still there. Pull it by digest:
TXT
echo "  docker pull $REG/$REPO@$before"
