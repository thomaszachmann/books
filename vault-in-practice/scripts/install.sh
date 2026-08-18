#!/usr/bin/env bash
# Install the tools this book needs. Appendix A.
#
# Installs only what is missing. Safe to run repeatedly.
# Docker itself is NOT installed here - it needs a desktop application on
# macOS and Windows, and a decision about rootless mode on Linux. The
# script tells you what to do instead.
set -uo pipefail

MISSING=()
have() { command -v "$1" >/dev/null 2>&1; }

need() {
  if have "$1"; then
    printf "  ok       %-10s %s\n" "$1" \
      "$($1 --version 2>&1 | head -1 | cut -c1-38)"
  else
    printf "  missing  %-10s (%s)\n" "$1" "$2"
    MISSING+=("$1")
  fi
}

echo "Vault in Practice - tool check"
echo
echo "Required from Chapter 1:"
need docker  "install separately, see below"
need vault   "Chapter 1"
echo
echo "Required from Chapter 3:"
need jq      "Chapter 3"
need openssl "Chapter 2"
echo
echo "Required from Chapter 16:"
need kubectl "Chapter 16"
need kind    "Chapter 16"
need minikube "Chapter 16"
need helm    "Chapter 16"
echo

if ! docker compose version >/dev/null 2>&1; then
  echo "  missing  docker compose (v2 plugin)"
else
  echo "  ok       docker compose $(docker compose version --short 2>/dev/null)"
fi
echo

if [ ${#MISSING[@]} -eq 0 ]; then
  echo "Everything present. Start with: make tls && make up"
  exit 0
fi

echo "Missing: ${MISSING[*]}"
echo

OS="$(uname -s)"
case "$OS" in
  Darwin)
    if ! have brew; then
      echo "Install Homebrew first:  https://brew.sh"
      exit 1
    fi
    echo "Install with Homebrew:"
    echo
    for t in "${MISSING[@]}"; do
      case "$t" in
        docker) echo "  # Docker Desktop: https://docker.com/products/docker-desktop" ;;
        vault)  echo "  brew tap hashicorp/tap && brew install hashicorp/tap/vault" ;;
        *)      echo "  brew install $t" ;;
      esac
    done
    ;;
  Linux)
    echo "Install (Debian/Ubuntu shown; adapt for your distribution):"
    echo
    for t in "${MISSING[@]}"; do
      case "$t" in
        docker)
          echo "  curl -fsSL https://get.docker.com | sh"
          echo "  sudo usermod -aG docker \$USER   # then log out and back in"
          ;;
        vault)
          echo "  wget -O- https://apt.releases.hashicorp.com/gpg |"
          echo "    sudo gpg --dearmor -o \\"
          echo "      /usr/share/keyrings/hashicorp.gpg"
          echo "  echo \"deb [signed-by=/usr/share/keyrings/hashicorp.gpg]\" \\"
          echo "    \"https://apt.releases.hashicorp.com \$(lsb_release -cs) main\" |"
          echo "    sudo tee /etc/apt/sources.list.d/hashicorp.list"
          echo "  sudo apt update && sudo apt install vault"
          ;;
        kind)
          echo "  go install sigs.k8s.io/kind@latest   # or download the binary"
          ;;
        helm)
          echo "  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
          ;;
        minikube)
          echo "  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
          echo "  sudo install minikube-linux-amd64 /usr/local/bin/minikube"
          ;;
        *) echo "  sudo apt install $t" ;;
      esac
    done
    ;;
  *)
    echo "On Windows, use winget from PowerShell:"
    echo "  winget install Hashicorp.Vault"
    echo "  winget install jqlang.jq"
    echo "  winget install Kubernetes.kubectl"
    echo "  winget install Kubernetes.kind"
    echo "  winget install Kubernetes.minikube"
    echo "  winget install Helm.Helm"
    echo "  # Docker Desktop with the WSL2 backend, then run the labs"
    echo "  # from inside WSL - not from PowerShell."
    ;;
esac

echo
echo "No local Vault CLI and do not want one? Everything works through"
echo "the container instead:"
echo
echo "  alias vault='docker compose exec -T vault vault'"
echo
echo "See Appendix A for the trade-offs of that approach."
