#!/usr/bin/env bash
# Tag 14, Szenario 1, Störung auslösen - Befehle wörtlich aus dem Buch.
A=$(kubectl -n openbao get pods -l openbao-active=true \
  -o jsonpath='{.items[0].metadata.name}'); echo "Active: $A"
kubectl -n openbao delete pod "$A"
# Runde 2: ganzer Worker
kubectl -n openbao get pod openbao-1 -o wide      # Spalte NODE merken
docker stop bao-lab-worker2                      # Node von openbao-1 einsetzen
