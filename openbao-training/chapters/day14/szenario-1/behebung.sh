#!/usr/bin/env bash
# Tag 14, Szenario 1, Behebung - Befehle wörtlich aus dem Buch.
docker start bao-lab-worker2
kubectl -n openbao wait pod/openbao-1 --for=condition=Ready --timeout=180s
bao operator raft autopilot state | grep 'Failure Tolerance'   # wieder 1
