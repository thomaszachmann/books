#!/usr/bin/env bash
check() { if eval "$2" >/dev/null 2>&1; then echo "✔ $1"; else echo "✘ $1"; fi; }

check "Database Engine gemountet" "bao secrets list | grep -q '^database/'"
check "Config webshop-db lesbar" "bao read database/config/webshop-db"
check "Rolle webshop-ro existiert" "bao read database/roles/webshop-ro"
check "Static Role webshop-app existiert" "bao read database/static-roles/webshop-app"
U=$(bao read -field=username database/creds/webshop-ro)
check "Dynamischer User in Postgres" \
  "docker exec bao-pg psql -U postgres -tAc '\du' | grep -q '$U'"
check "Policy webshop-db existiert" "bao policy read webshop-db"
bao lease revoke -prefix database/creds/webshop-ro >/dev/null
