#!/usr/bin/env bash
# Tag 1, Kontrollpunkt - Befehle wörtlich aus dem Buch.
ok() { "$@" >/dev/null 2>&1 && echo "✔ $*" || echo "✘ $*"; }
ok bao status
ok bao kv get -mount=secret webshop/config
ok bao kv get -mount=team-shop app/flags
[ "$(bao kv metadata get -mount=secret -format=json webshop/config \
  | jq .data.max_versions)" = 5 ] && echo "✔ max_versions=5" || echo "✘ max_versions"
bao secrets list | grep -q '^kv1/' && echo "✔ kv1/" || echo "✘ kv1/"
