#!/usr/bin/env bash
ok() { echo "✔ $1"; }; nok() { echo "✘ $1"; }
OLD=$(jq -r .root_token ~/bao-lab/k8s/init.json)
BAO_TOKEN=$OLD bao token lookup >/dev/null 2>&1 \
  && nok "Alt-Root ist noch gültig" || ok "Alt-Root revoked"
bao token lookup -format=json | jq -e '.data.policies | index("bao-admin")' >/dev/null \
  && ok "Arbeite als bao-admin" || nok "Arbeite als bao-admin"
bao operator generate-root -status >/dev/null 2>&1 \
  && nok "Admin darf generate-root" || ok "generate-root nur Break-Glass"
[ "$(jq '.keys_base64 | length' ~/bao-lab/k8s/recovery-neu.json)" = 5 ] \
  && ok "Neue Recovery-Keys" || nok "Neue Recovery-Keys"
bao namespace list | grep -q team-shop && ok "Namespace" || nok "Namespace"
(cd ~/bao-lab/tag13/tofu && tofu plan -detailed-exitcode >/dev/null) \
  && ok "OpenTofu ohne Drift" || nok "OpenTofu ohne Drift"
