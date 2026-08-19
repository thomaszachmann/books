#!/usr/bin/env bash
# Decode a JWT payload. Reads the token on stdin or as $1.
#
# JWT segments are base64URL and unpadded: '-' and '_' stand in for '+'
# and '/' so the token survives a URL, and the '=' padding is stripped.
# GNU base64 refuses both, so this is not one command however much it
# looks like it should be. Hiding the error with 2>/dev/null is worse
# than the error: some implementations then emit truncated but plausible
# JSON, and you go looking for a problem with the token.
set -euo pipefail

TOKEN="${1:-$(cat)}"
payload="$(printf '%s' "$TOKEN" | cut -d. -f2 | tr '_-' '/+')"

case $(( ${#payload} % 4 )) in
  2) payload="$payload==" ;;
  3) payload="$payload="  ;;
  1) echo "not a valid base64url segment" >&2; exit 1 ;;
esac

printf '%s' "$payload" | base64 -d
