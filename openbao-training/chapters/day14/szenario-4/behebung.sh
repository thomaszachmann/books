#!/usr/bin/env bash
# Tag 14, Szenario 4, Behebung - Befehle wörtlich aus dem Buch.
V=$(bao kv metadata get -format=json -mount=secret webshop/config \
  | jq '.data.current_version')
bao kv undelete -versions=$V -mount=secret webshop/config
bao kv rollback -version=$((V-1)) -mount=secret webshop/config   # falschen Wert ersetzen
bao kv get -mount=secret -field=db_pass webshop/config
kubectl -n webshop annotate externalsecret --all force-sync=$(date +%s) --overwrite
