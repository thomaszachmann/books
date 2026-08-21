#!/usr/bin/env bash
# Turn a SAML message back into readable XML. Chapter 5.
#
#   ./saml-decode.sh response  < the SAMLResponse form field
#   ./saml-decode.sh request   < the SAMLRequest query parameter
#
# The two are encoded differently, and that difference is the single
# most common reason a SAML message "will not decode":
#   response  base64
#   request   URL-encode( base64( raw DEFLATE( xml ) ) )
set -euo pipefail

kind="${1:-response}"
data=$(cat)

case "$kind" in
  response)
    printf '%s' "$data" | base64 -d
    ;;
  request)
    python3 - "$data" <<'PY'
import base64, sys, urllib.parse, zlib
q = urllib.parse.unquote(sys.argv[1])
# -15 means raw DEFLATE: no zlib header, no checksum. Getting this
# wrong is the usual mistake and the error message never says so.
sys.stdout.write(zlib.decompress(base64.b64decode(q), -15).decode())
PY
    ;;
  *)
    echo "usage: $0 [response|request]" >&2; exit 2 ;;
esac | xmllint --format -
