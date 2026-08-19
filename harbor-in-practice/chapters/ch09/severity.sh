#!/usr/bin/env bash
# Harbor's severity threshold, as a library.
#
# The comparison in src/server/middleware/vulnerable/vulnerable.go is
#
#   vulnerable.Severity.Code() >= projectSeverity.Code()
#
# so the threshold is INCLUSIVE, and Harbor's own refusal says so:
# 'Prevent images with vulnerability severity of "high" or higher'.
# A threshold of high blocks high. The difference between "high and
# above" and "above high" is the band most findings land in.
set -euo pipefail

sev_code() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    none)     echo 0 ;;
    unknown)  echo 1 ;;
    low)      echo 2 ;;
    medium)   echo 3 ;;
    high)     echo 4 ;;
    critical) echo 5 ;;
    *) echo "unknown severity: $1" >&2; return 2 ;;
  esac
}

# would_block <finding severity> <project threshold>
would_block() {
  local f t
  f=$(sev_code "$1") || return 2
  t=$(sev_code "$2") || return 2
  [ "$t" -gt 0 ] && [ "$f" -ge "$t" ]
}

if [ "${BASH_SOURCE[0]:-}" = "$0" ]; then
  printf '%-12s' 'finding:'
  for t in low medium high critical none; do printf '%-10s' "$t"; done
  echo
  for f in low medium high critical; do
    printf '%-12s' "$f"
    for t in low medium high critical none; do
      if would_block "$f" "$t"; then printf '%-10s' block
      else printf '%-10s' '-'; fi
    done
    echo
  done
  echo
  echo "A threshold of none disables the check entirely."
fi
