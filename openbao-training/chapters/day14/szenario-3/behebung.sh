#!/usr/bin/env bash
# Tag 14, Szenario 3, Behebung - Befehle wörtlich aus dem Buch.
kubectl -n unsealer scale statefulset bao-unsealer --replicas=1
kubectl -n unsealer wait pod/bao-unsealer-0 --for=condition=Ready --timeout=120s
kubectl -n openbao delete pod openbao-2       # falls nach 1 min noch sealed
kubectl -n openbao exec openbao-2 -- bao status | grep Sealed
