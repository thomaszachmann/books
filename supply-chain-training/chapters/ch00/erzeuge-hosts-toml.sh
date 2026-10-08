#!/usr/bin/env bash
# Kapitel 0, Schritt 2 - Befehle wörtlich aus dem Buch.
for reg in reg-build reg-ziel; do
  mkdir -p ~/seclab/containerd-certs.d/"${reg}:5000"
  cat > ~/seclab/containerd-certs.d/"${reg}:5000"/hosts.toml <<EOF
server = "http://${reg}:5000"

[host."http://${reg}:5000"]
  capabilities = ["pull", "resolve"]
EOF
done
cat ~/seclab/containerd-certs.d/reg-build:5000/hosts.toml
