#!/usr/bin/env bash
# Tag 14, Szenario 2, Störung auslösen - Befehle wörtlich aus dem Buch.
kubectl -n openbao scale statefulset openbao --replicas=1
