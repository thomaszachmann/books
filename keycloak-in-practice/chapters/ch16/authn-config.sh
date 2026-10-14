#!/usr/bin/env bash
# Write the API server's structured authentication configuration.
# Chapters 15 and 16.
#
#   ./chapters/ch16/authn-config.sh                 no issuers (Chapter 15)
#   ./chapters/ch16/authn-config.sh <issuer-url>... one entry per issuer
#
# The file lives in k8s/kind/authn/, which k8s/kind/cluster.yaml mounts
# into the control-plane node. The API server watches it and reloads it
# by itself, so a change here takes effect within about a minute with no
# restart - and a broken file is refused, logged, and the previous
# configuration stays in force.
#
# Three things decide whether an entry works at all:
#   url                   must be reachable FROM THE API SERVER
#   certificateAuthority  the root that signed the issuer's certificate,
#                         inline - the node's own trust store is never
#                         touched
#   audiences             must contain the client id, and the ID token's
#                         aud must match - Chapter 8's argument again
set -euo pipefail

cd "$(dirname "$0")/../.."
OUT=k8s/kind/authn/config.yaml
mkdir -p "$(dirname "$OUT")"

if [ "$#" -gt 0 ] && [ ! -f pki/ca.crt ]; then
  echo "pki/ca.crt is missing - Chapter 2, make pki" >&2
  exit 1
fi

{
  cat <<'HEAD'
# Written by chapters/ch16/authn-config.sh. Edit the script's arguments,
# not this file; the next run replaces it.
apiVersion: apiserver.config.k8s.io/v1
kind: AuthenticationConfiguration
HEAD
  if [ "$#" -eq 0 ]; then
    echo "jwt: []"
  else
    echo "jwt:"
    for url in "$@"; do
      cat <<ENTRY
  - issuer:
      url: $url
      audiences:
        - kubernetes
      certificateAuthority: |
$(sed 's/^/        /' pki/ca.crt)
    claimMappings:
      username:
        claim: preferred_username
        prefix: "oidc:"
      groups:
        claim: groups
        prefix: "oidc:"
    claimValidationRules:
      - claim: typ
        requiredValue: ID
ENTRY
    done
  fi
} > "$OUT.tmp"

# The same root as a file, for checking the issuer from the node by hand
# (Chapter 16, On the Wire). The API server reads the inline copy.
[ -f pki/ca.crt ] && cp pki/ca.crt k8s/kind/authn/ca.crt

# Replace in one step, so the API server never reads half a file.
mv "$OUT.tmp" "$OUT"
if [ "$#" -eq 0 ]; then
  echo "$OUT: no issuers"
else
  echo "$OUT: $*"
fi
