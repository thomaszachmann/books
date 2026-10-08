#!/usr/bin/env bash
# Tag 3, Kontrollpunkt - Befehle wörtlich aus dem Buch.
export BAO_TOKEN=root
R=$(bao read -field=role_id auth/approle/role/webshop/role-id)
W=$(bao write -wrap-ttl=2m -field=wrapping_token -f auth/approle/role/webshop/secret-id)
SID=$(BAO_TOKEN=$W bao unwrap -field=secret_id)
T=$(bao write -field=token auth/approle/login role_id=$R secret_id=$SID)
[ -n "$T" ] && echo "✔ AppRole-Login mit Wrapped SecretID" || echo "✘ AppRole-Login"
[ "$(BAO_TOKEN=$T bao kv get -mount=secret -field=db_user webshop/config)" = webshop ] \
  && echo "✔ webshop liest Secret" || echo "✘ Secret lesen"
bao auth list | grep -q '^userpass/' && echo "✔ userpass" || echo "✘ userpass"
[ "$(bao read -field=default_lease_ttl sys/auth/userpass/tune)" = 1800 ] \
  && echo "✔ userpass-TTL 30m" || echo "✘ userpass-TTL"
