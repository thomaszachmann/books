#!/usr/bin/env bash
# Tag 14, Szenario 1, Diagnose - Befehle wörtlich aus dem Buch.
kubectl get nodes
kubectl -n openbao get pods -o wide -L openbao-active
bao operator raft list-peers
bao operator raft autopilot state | grep -E 'Healthy|Failure Tolerance'
