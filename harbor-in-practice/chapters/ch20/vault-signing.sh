#!/usr/bin/env bash
# Cosign's Vault reference, checked before you spend an hour on it.
#
# What follows hashivault:// is a key NAME, not a path: word characters,
# hyphens and dots, no slash. The mount point is supplied separately in
# TRANSIT_SECRET_ENGINE_PATH, which defaults to transit. Putting the
# mount in the reference produces an error about the reference, which
# sends people looking in the wrong place.
#
#   ./vault-signing.sh ref hashivault://harbor-signing
#   ./vault-signing.sh env
#   ./vault-signing.sh version 'vault:v2:MEUCIQD...'
set -euo pipefail

# From sigstore's hashivault provider: the scheme accepts both products,
# and the key name may not contain a slash.
REF_RE='^(hashivault|openbao)://[A-Za-z0-9_]([A-Za-z0-9_.-]*[A-Za-z0-9_])?$'

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

cmd_ref() {
  REF="${1:?a reference, for example hashivault://harbor-signing}"
  if ! printf '%s' "$REF" | grep -Eq "$REF_RE"; then
    echo "not a valid cosign Vault reference: $REF" >&2
    case "$REF" in
      *://*/*)
        echo "  the part after the scheme is a key name, not a path." >&2
        echo "  put the mount in TRANSIT_SECRET_ENGINE_PATH instead." >&2 ;;
      *://*) echo "  the scheme must be hashivault:// or openbao://" >&2 ;;
      *)     echo "  no scheme. try hashivault://$REF" >&2 ;;
    esac
    return 1
  fi
  KEY="${REF#*://}"
  MOUNT="${TRANSIT_SECRET_ENGINE_PATH:-transit}"
  echo "reference ok"
  echo "  key    $KEY"
  echo "  mount  $MOUNT${TRANSIT_SECRET_ENGINE_PATH:+ (from TRANSIT_SECRET_ENGINE_PATH)}"
  echo "  signs  ${MOUNT}/sign/${KEY}"
  echo "  public ${MOUNT}/keys/${KEY}"
}

cmd_env() {
  fail=0
  if [ -n "${VAULT_ADDR:-}${BAO_ADDR:-}" ]; then
    echo "ok      address  ${VAULT_ADDR:-$BAO_ADDR}"
  else
    echo "MISSING address  set VAULT_ADDR or BAO_ADDR"; fail=1
  fi
  if [ -n "${VAULT_TOKEN:-}${BAO_TOKEN:-}" ]; then
    echo "ok      token    set"
  else
    echo "absent  token    VAULT_TOKEN and BAO_TOKEN unset;"
    echo "                 cosign will try a token helper before failing"
  fi
  echo "ok      mount    ${TRANSIT_SECRET_ENGINE_PATH:-transit (default)}"
  exit "$fail"
}

# Vault prefixes what it signs with the key version. Old signatures keep
# their own version and keep verifying, which is what makes rotating a
# signing key possible at all.
cmd_version() {
  SIG="${1:?a signature, or - to read stdin}"
  [ "$SIG" = - ] && SIG="$(cat)"
  case "$SIG" in
    vault:v*:*)
      V="${SIG#vault:v}"; V="${V%%:*}"
      echo "key version $V"
      ;;
    *)
      echo "no vault: prefix - not produced by the transit engine" >&2
      return 1
      ;;
  esac
}

case "${1:-}" in
  ref)     shift; cmd_ref "$@" ;;
  env)     shift; cmd_env "$@" ;;
  version) shift; cmd_version "$@" ;;
  ''|-h|--help) usage 0 ;;
  *) echo "unknown command: $1" >&2; usage 1 ;;
esac
