#!/usr/bin/env bash
# Chapter 3, step 3. Verify a Harbor installer against its Sigstore
# bundle before running it as root.
#
#   ./verify-installer.sh [offline|online] [version]
#
# The two --certificate- flags are the whole control. Without them you
# would be checking that somebody signed the file, which is worth
# nothing: anyone can sign anything.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/../../scripts/versions.sh"

KIND="${1:-offline}"
V="${2:-$HARBOR_VERSION}"
BASE="harbor-$KIND-installer-$V.tgz"
URL="https://github.com/goharbor/harbor/releases/download/$V"

IDENTITY='https://github.com/goharbor/harbor/.github/workflows/.*'
ISSUER='https://token.actions.githubusercontent.com'

command -v cosign >/dev/null 2>&1 || {
  echo "cosign not found. See Appendix A." >&2; exit 1; }

WORK="${WORK_DIR:-$PWD}"
cd "$WORK"

[ -f "$BASE" ]               || curl -fLO --progress-bar "$URL/$BASE"
[ -f "$BASE.sigstore.json" ] || curl -fLO "$URL/$BASE.sigstore.json"

echo "== verifying $BASE"
cosign verify-blob \
  --bundle "$BASE.sigstore.json" \
  --certificate-identity-regexp "$IDENTITY" \
  --certificate-oidc-issuer "$ISSUER" \
  "$BASE"

echo
echo "Verified. That is the difference between installing Harbor and"
echo "installing whatever was at that URL."
