#!/usr/bin/env bash
# Tag 14, Szenario 6, Störung auslösen - Befehle wörtlich aus dem Buch.
bao auth list | grep -q approle/ || bao auth enable approle
bao write auth/approle/role/leak-drill token_policies=webshop-read token_ttl=1h
RID=$(bao read -field=role_id auth/approle/role/leak-drill/role-id)
bao write -f -format=json auth/approle/role/leak-drill/secret-id > leak-sid.json
LEAK=$(bao write -field=token auth/approle/login role_id=$RID \
  secret_id=$(jq -r .data.secret_id leak-sid.json))
echo "$LEAK" > geleakt.txt   # "im Slack gepostet"
