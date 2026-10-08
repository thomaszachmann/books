#!/usr/bin/env bash
# Tag 14, Szenario 8, Störung auslösen - Befehle wörtlich aus dem Buch.
A=$(kubectl -n openbao get pods -l openbao-active=true \
  -o jsonpath='{.items[0].metadata.name}')
kubectl -n openbao exec $A -- sh -c 'cd /openbao/audit && mv audit.log audit.old \
  && mkdir audit.log && kill -HUP $(pidof bao)'     # Pfad aus Tag 12
