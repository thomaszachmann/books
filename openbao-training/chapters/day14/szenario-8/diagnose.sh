#!/usr/bin/env bash
# Tag 14, Szenario 8, Diagnose - Befehle wörtlich aus dem Buch.
kubectl -n openbao logs $A --tail=20 | grep -i audit
kubectl -n openbao exec $A -- df -h /openbao/audit
bao audit list -detailed
