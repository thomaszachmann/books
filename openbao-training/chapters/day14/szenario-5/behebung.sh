#!/usr/bin/env bash
# Tag 14, Szenario 5, Behebung - Befehle wörtlich aus dem Buch.
helm -n openbao install openbao openbao/openbao --version 0.30.2 \
  -f ~/bao-lab/k8s/values.yaml
kubectl -n openbao exec openbao-0 -- bao operator init \
  -recovery-shares=5 -recovery-threshold=3 -format=json > ~/bao-lab/tag14/temp-init.json
kubectl -n openbao port-forward svc/openbao-active 8200:8200 >/dev/null 2>&1 &
BAO_TOKEN=$(jq -r .root_token ~/bao-lab/tag14/temp-init.json) \
  bao operator raft snapshot restore -force ~/bao-lab/tag14/restore.snap
