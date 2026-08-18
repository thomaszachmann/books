#!/usr/bin/env bash
# Print how to install what is missing. Deliberately does not install
# anything itself: a script that silently installs software on somebody
# else's laptop is not a teaching tool.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/versions.sh"

cat <<TXT
Harbor in Practice - installing the tools

macOS, with Homebrew:

  brew install --cask docker multipass
  brew install jq kubectl helm kind minikube cosign

Linux, Debian and Ubuntu:

  sudo apt-get install -y docker.io curl jq
  sudo snap install multipass
  # kubectl, helm, kind, minikube, cosign: see Appendix A

Windows:

  winget install Docker.DockerDesktop Canonical.Multipass
  winget install Kubernetes.kubectl Helm.Helm Kubernetes.kind
  winget install Kubernetes.minikube sigstore.cosign

Versions this book is written against:

  Harbor        $HARBOR_VERSION
  Harbor chart  $HARBOR_CHART_VERSION
  Helm          $HELM_VERSION   (note the major version)
  kind          $KIND_VERSION
  minikube      $MINIKUBE_VERSION
  Trivy         $TRIVY_VERSION
  cosign        $COSIGN_VERSION

Newer usually works. Where it does not, ERRATA.md says so.
TXT
