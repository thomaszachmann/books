#!/usr/bin/env bash
# Tag 14, Szenario 6, Behebung - Befehle wörtlich aus dem Buch.
bao token revoke -accessor $ACC
bao write auth/approle/role/leak-drill/secret-id-accessor/destroy \
  secret_id_accessor=$(jq -r .data.secret_id_accessor leak-sid.json)
bao lease revoke -prefix auth/approle/        # alle AppRole-Tokens, grosser Hammer
BAO_TOKEN=$(cat geleakt.txt) bao kv get -mount=secret webshop/config   # muss 403 sein
