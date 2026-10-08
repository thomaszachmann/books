#!/usr/bin/env bash
# Tag 14, Szenario 3, Diagnose - Befehle wörtlich aus dem Buch.
kubectl -n openbao get pods
kubectl -n openbao logs openbao-2 --tail=30 | grep -iE 'seal|transit'
kubectl -n unsealer get pods,endpoints
kubectl -n openbao get cm openbao-config -o yaml | grep -A6 'seal "transit"'
