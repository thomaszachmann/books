#!/usr/bin/env bash
# Tag 14, Szenario 8, Behebung - Befehle wörtlich aus dem Buch.
kubectl -n openbao exec $A -- sh -c 'cd /openbao/audit && rmdir audit.log \
  && mv audit.old audit.log && kill -HUP $(pidof bao)'
bao kv get -field=db_user secret/webshop/config
