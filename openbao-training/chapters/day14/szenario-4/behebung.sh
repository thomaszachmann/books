#!/usr/bin/env bash
# Tag 14, Szenario 4, Behebung - Befehle wörtlich aus dem Buch.
V=$(bao kv metadata get -format=json secret/webshop/config | jq '.data.current_version')
bao kv undelete -versions=$V secret/webshop/config
bao kv rollback -version=$((V-1)) secret/webshop/config   # falschen Wert ersetzen
bao kv get -field=db_pass secret/webshop/config
kubectl -n webshop annotate externalsecret --all force-sync=$(date +%s) --overwrite
