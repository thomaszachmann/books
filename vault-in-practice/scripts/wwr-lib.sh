# shellcheck shell=bash
# Shared helpers for the "What Went Wrong" reproduction scripts.
#
# Source this, do not run it:   . ./scripts/wwr-lib.sh
#
# Every chapter's reproduce-errors.sh produces the errors that chapter
# prints, on purpose, so that a reader meets each one once deliberately
# rather than for the first time at an inconvenient moment. The helpers
# exist so that 23 scripts do not each reinvent the same four functions.

# Only a TLS address needs a CA. Setting VAULT_CACERT against an http
# address makes every command fail on a file it never needed to read -
# which is itself an error worth not reproducing by accident.
wwr_env() {
  export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
  case "$VAULT_ADDR" in
    https://*) export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}" ;;
    *)         unset VAULT_CACERT ;;
  esac
  : "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"
}

# A heading, so the output can be read alongside the book.
wwr_case() { printf '\n== %s\n' "$1"; }

# Show the command, run it, print the first lines of what it said.
# Errors are the point here, so a non-zero exit is success.
wwr_run() {
  printf '$ %s\n' "$*"
  "$@" 2>&1 | sed -n '1,8p' | grep -v '^[[:space:]]*$'
}

# The same, but assert the output contains what the book prints. Used by
# CI: if Vault changes the wording, the book is wrong and this goes red.
wwr_expect() {
  local want="$1"; shift
  local out; out=$("$@" 2>&1)
  printf '$ %s\n' "$*"
  printf '%s\n' "$out" | sed -n '1,8p' | grep -v '^[[:space:]]*$'
  if printf '%s' "$out" | grep -qF "$want"; then
    [ -n "${WWR_QUIET:-}" ] || printf '   ok: contains "%s"\n' "$want"
  else
    printf '   MISMATCH: expected "%s"\n' "$want"
    WWR_FAILED=$((${WWR_FAILED:-0} + 1))
  fi
}

# A policy and a token that carries it, under a name we can clean up.
wwr_policy() { printf '%s\n' "$2" | vault policy write "wwr-$1" - >/dev/null; }
wwr_token()  { vault token create -policy="wwr-$1" -field=token; }

# What a token may do on a path, which answers "why" without guessing.
wwr_caps() { printf '  %-34s %s\n' "$2" "$(vault token capabilities "$1" "$2")"; }

wwr_cleanup() {
  for p in $(vault policy list 2>/dev/null | grep '^wwr-' || true); do
    vault policy delete "$p" >/dev/null 2>&1 || true
  done
}

wwr_done() {
  wwr_cleanup
  if [ "${WWR_FAILED:-0}" -gt 0 ]; then
    printf '\n%s case(s) did not match what the book prints.\n' "$WWR_FAILED"
    exit 1
  fi
  printf '\nAll cases produced on purpose. Policies removed.\n'
}
