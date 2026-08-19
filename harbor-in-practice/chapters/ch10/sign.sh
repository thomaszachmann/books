#!/usr/bin/env bash
# Sign an artifact with cosign, creating a key pair if there is none.
#
#   COSIGN_PASSWORD=lab ./sign.sh harbor.meridian.test/platform/signed:1.0
#
# The key this produces is a lab key: it lives in a file, it can be
# copied, and nothing stops anyone else generating one that Harbor will
# accept just as readily. Chapter 20 replaces it with a Vault transit
# key that never leaves Vault. Read Chapter 10 step 4 before using this
# pattern anywhere real.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REF="${1:?an image reference}"
: "${COSIGN_PASSWORD:?set COSIGN_PASSWORD - cosign will not prompt in a script}"

command -v cosign >/dev/null || { echo "cosign not found" >&2; exit 1; }

cd "$HERE"
if [ ! -f cosign.key ]; then
  echo "== generating a key pair in $HERE"
  cosign generate-key-pair
fi

cosign sign --yes --key cosign.key "$REF"

cat <<TXT

Signed. In Harbor this is now a second artifact in the same repository,
with the image as its subject:

  ./chapters/ch10/signed-artifacts.sh <project>

What Harbor's policy checks is that such an artifact exists. It does not
check who made it. Verification is:

  cosign verify --key $HERE/cosign.pub $REF

and it belongs in admission control, not on your laptop.
TXT
