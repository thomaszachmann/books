#!/usr/bin/env bash
# Tag 14, Szenario 5, Störung auslösen - Befehle wörtlich aus dem Buch.
bao operator raft snapshot save ~/bao-lab/tag14/restore.snap
helm -n openbao uninstall openbao
for i in 0 1 2; do kubectl -n openbao delete pvc data-openbao-$i audit-openbao-$i \
  --ignore-not-found; done
