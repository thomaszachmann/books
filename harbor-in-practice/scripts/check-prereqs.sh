#!/usr/bin/env bash
# Verify the tools the labs need, and say which chapter needs each one.
#
# Every tool gets its own version command. There is no common flag:
# kubectl and helm both reject --version, and a check that treats their
# error message as success is worse than no check at all.
set -uo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/versions.sh"

missing=0

need() {   # command, needed-from, version-args...
  local cmd="$1" from="$2"; shift 2
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf '  MISSING %-11s needed from %s\n' "$cmd" "$from"
    missing=$((missing + 1))
    return
  fi
  local v
  v=$("$cmd" "$@" 2>&1 | head -1 | tr -d '\r\n')
  if printf '%s' "$v" | grep -qiE 'unknown (flag|command)|^error'; then
    printf '  ok?     %-11s installed, version check failed\n' "$cmd"
    return
  fi
  printf '  ok      %-11s %s\n' "$cmd" "${v:0:52}"
}

echo "Harbor in Practice - prerequisites"
echo "Pinned Harbor $HARBOR_VERSION, chart $HARBOR_CHART_VERSION"
echo

need docker    "Chapter 1"  --version
need curl      "Chapter 1"  --version
need jq        "Chapter 4"  --version
need multipass "Chapter 2"  version
need kubectl   "Chapter 15" version --client
need helm      "Chapter 15" version --short
need kind      "Chapter 15" version
need minikube  "Chapter 15" version --short
need cosign    "Chapter 10" version

echo
if [ "$missing" -gt 0 ]; then
  echo "$missing missing. Run 'make install' for how to get them."
  exit 1
fi
echo "All present."
