#!/usr/bin/env bash
# Verify the tools the book needs are installed.
set -uo pipefail

ok=0; missing=0

# Not every tool understands --version. kubectl, minikube and helm do not,
# and printing their error message as a version number is worse than
# printing nothing.
version_of() {
  case "$1" in
    vault)    vault version ;;
    openssl)  openssl version ;;
    kubectl)  kubectl version --client ;;
    minikube) minikube version ;;
    helm)     helm version --short ;;
    kind)     kind --version ;;
    *)        "$1" --version ;;
  esac 2>&1 | head -1
}

check() {
  local cmd="$1" chapter="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf "  ok       %-10s %s\n" "$cmd" "$(version_of "$cmd" | cut -c1-40)"
    ok=$((ok+1))
  else
    printf "  MISSING  %-10s needed from %s\n" "$cmd" "$chapter"
    missing=$((missing+1))
  fi
}

echo "Vault in Practice - prerequisite check"
echo
echo "Required from Chapter 1:"
check docker  "Chapter 1"
check vault   "Chapter 1"
echo
echo "Required from Chapter 3:"
check jq      "Chapter 3"
check openssl "Chapter 2"
echo
echo "Required from Chapter 16 (Kubernetes):"
check kubectl "Chapter 16"
check kind    "Chapter 16"
check minikube "Chapter 16"
check helm    "Chapter 16"
echo
if ! docker compose version >/dev/null 2>&1; then
  echo "  MISSING  docker compose (v2 plugin)"
  missing=$((missing+1))
else
  echo "  ok       docker compose $(docker compose version --short)"
  ok=$((ok+1))
fi
echo
echo "$ok present, $missing missing."
[ "$missing" -eq 0 ] && echo "Ready." || \
  echo "Install what is missing before the chapter that needs it."
