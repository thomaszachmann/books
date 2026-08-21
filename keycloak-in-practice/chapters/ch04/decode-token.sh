#!/usr/bin/env bash
# Decode a JWT without a library. Chapter 4 does this by hand first;
# this is the same three steps, kept for the chapters that follow.
#
#   ./decode-token.sh header  < tokens.json
#   ./decode-token.sh payload < tokens.json
#   echo "$TOKEN" | ./decode-token.sh payload -
set -euo pipefail

part="${1:-payload}"
case "$part" in
  header)  field=1 ;;
  payload) field=2 ;;
  *) echo "usage: $0 [header|payload] [-]" >&2; exit 2 ;;
esac

# Base64URL is Base64 with two characters swapped and the padding
# dropped. Put both back before base64 will look at it.
b64url() {
  tr '_-' '/+' | awk '{
    l = length($0) % 4
    if (l == 2) print $0 "=="
    else if (l == 3) print $0 "="
    else print $0
  }'
}

if [ "${2:-}" = "-" ]; then
  token=$(cat)
else
  token=$(jq -r '.access_token // .id_token // .' -)
fi

printf '%s' "$token" | cut -d. -f"$field" | b64url | base64 -d | jq .
