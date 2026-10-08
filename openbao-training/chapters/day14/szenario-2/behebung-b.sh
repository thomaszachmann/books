#!/usr/bin/env bash
# Tag 14, Szenario 2, Behebung B - Befehle wörtlich aus dem Buch.
kubectl -n openbao exec -i openbao-0 -- \
  sh -c 'cat > /openbao/data/raft/peers.json' <<'EOF'
[
  { "id": "openbao-0",
    "address": "openbao-0.openbao-internal:8201",
    "non_voter": false }
]
EOF
kubectl -n openbao delete pod openbao-0           # Neustart liest peers.json
kubectl -n openbao logs openbao-0 | grep -i 'raft recovery'
