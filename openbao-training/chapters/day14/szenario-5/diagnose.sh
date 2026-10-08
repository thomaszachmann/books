#!/usr/bin/env bash
# Tag 14, Szenario 5, Diagnose - Befehle wörtlich aus dem Buch.
tar -tzf ~/bao-lab/tag14/restore.snap      # meta.json state.bin SHA256SUMS ...
kubectl -n unsealer get pods               # Unsealer + Key autounseal muessen leben
