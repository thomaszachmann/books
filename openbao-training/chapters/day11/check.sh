#!/usr/bin/env bash
ok() { echo "✔ $1"; }; nok() { echo "✘ $1"; }
JWT=$(kubectl -n webshop create token webshop --audience=openbao --duration=10m)
bao write -field=token auth/kubernetes/login role=webshop jwt="$JWT" >/dev/null 2>&1 \
  && ok "Kubernetes-Login" || nok "Kubernetes-Login"
[ "$(kubectl -n webshop get externalsecret webshop-config \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" = "True" ] \
  && ok "ExternalSecret synchron" || nok "ExternalSecret synchron"
kubectl -n webshop get secret webshop-config >/dev/null 2>&1 \
  && ok "K8s-Secret vorhanden" || nok "K8s-Secret vorhanden"
kubectl -n webshop exec webshop-agent -c app -- test -s /vault/secrets/db.env \
  && ok "Injector-Datei gerendert" || nok "Injector-Datei gerendert"
