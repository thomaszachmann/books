#!/usr/bin/env bash
# Tag 14, Szenario 3, Störung auslösen - Befehle wörtlich aus dem Buch.
kubectl -n unsealer get statefulset,deployment          # Ressource prüfen
kubectl -n unsealer scale statefulset bao-unsealer --replicas=0
kubectl -n openbao delete pod openbao-2                 # Neustart erzwingen
