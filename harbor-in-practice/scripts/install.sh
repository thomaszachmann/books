#!/usr/bin/env bash
# Print how to install what is missing. Deliberately does not install
# anything itself: a script that silently installs software on somebody
# else's laptop is not a teaching tool.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/versions.sh"

cat <<TXT
Harbor in Practice - installing the tools

macOS - a container runtime, three ways:

  brew install --cask docker        Docker Desktop. Paid above 250
                                    employees or \$10M revenue; check
                                    the current terms.
  brew install colima docker \      Colima runs the daemon in a Linux
    docker-compose docker-buildx    VM; 'docker' here is the CLI only.
    && colima start --cpu 4 --memory 8 --disk 60
  brew install --cask orbstack      Faster, commercial for business use.

  Any of the three works. They differ in where a CA root has to go -
  see Appendix A, and note that the trust store that matters is the
  DAEMON's, which on macOS lives inside a VM you did not create.

macOS - everything else:

  brew install --cask multipass
  brew install jq kubectl helm kind minikube cosign

Linux, Debian and Ubuntu:

  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "\$USER"     # log out and back in
  sudo apt-get install -y curl jq

  Docker's own repository rather than docker.io: the distribution
  package lags, and Harbor's installer checks the compose plugin
  version.
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
