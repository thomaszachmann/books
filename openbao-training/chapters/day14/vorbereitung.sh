#!/usr/bin/env bash
# Tag 14, Vorbereitung - Befehle wörtlich aus dem Buch.
mkdir -p ~/bao-lab/tag14 && cd ~/bao-lab/tag14
kubectl config use-context kind-bao-lab
kubectl -n openbao port-forward svc/openbao-active 8200:8200 >/dev/null 2>&1 &
export BAO_ADDR=https://127.0.0.1:8200 BAO_CACERT=~/bao-lab/tls/ca.crt
export BAO_TOKEN=$(bao login -no-store -field=token -method=userpass \
  username=admin password=lab-admin-pw)   # Admin aus Tag 13 (Root ist widerrufen)
bao operator raft snapshot save ~/bao-lab/tag14/vorher.snap     # Sicherheitsnetz
