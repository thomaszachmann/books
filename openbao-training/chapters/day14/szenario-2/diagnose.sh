#!/usr/bin/env bash
# Tag 14, Szenario 2, Diagnose - Befehle wörtlich aus dem Buch.
kubectl -n openbao exec openbao-0 -- bao status | grep -E 'Sealed|HA (Mode|Cluster)'
kubectl -n openbao logs openbao-0 --tail=20 | grep -E 'election|votesNeeded'
kubectl -n openbao get endpoints openbao-active   # keine Endpoints
