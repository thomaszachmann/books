#!/usr/bin/env bash
# Every namespace that holds a Harbor pull secret.
#
# Run this after a year. The number is the argument for Chapter 19: one
# credential, N copies, each one a place rotation has to visit and each
# one a place it can be forgotten.
set -euo pipefail
HOST="${HARBOR_HOSTNAME:-harbor.meridian.test}"

json="${SECRETS_JSON:-$(kubectl get secrets -A \
  --field-selector type=kubernetes.io/dockerconfigjson -o json)}"

printf '%s' "$json" | jq -r --arg host "$HOST" '
  .items[]
  | select((.data[".dockerconfigjson"] // "") | @base64d | contains($host))
  | "\(.metadata.namespace)\t\(.metadata.name)"' \
| sort | awk '{printf "  %-24s %s\n", $1, $2}'

n=$(printf '%s' "$json" | jq --arg host "$HOST" '
  [ .items[]
    | select((.data[".dockerconfigjson"] // "") | @base64d
      | contains($host)) ] | length')

echo
echo "$n namespace(s) hold a credential for $HOST."
echo "Rotation has to visit every one of them."
