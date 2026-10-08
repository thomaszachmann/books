#!/usr/bin/env bash
# Tag 2, Kontrollpunkt - Befehle wörtlich aus dem Buch.
export BAO_TOKEN=root
W=$(bao token create -field=token -policy=webshop-read -ttl=10m)
c() { [ "$(bao token capabilities $W "$1")" = "$2" ] \
  && echo "✔ $1 = $2" || echo "✘ $1 != $2"; }
c secret/data/webshop/config read
c secret/data/webshop/admin deny
c secret/data/billing/config deny
c secret/metadata/webshop/ "list, read"
bao policy list | grep -qx shop-writer && echo "✔ shop-writer" || echo "✘ shop-writer"
