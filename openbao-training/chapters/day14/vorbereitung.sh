#!/usr/bin/env bash
# Tag 14, Vorbereitung - Befehle wörtlich aus dem Buch.
mkdir -p ~/bao-lab/tag14 && cd ~/bao-lab/tag14
kubectl config use-context kind-bao-lab
kubectl -n openbao port-forward svc/openbao-active 8200:8200 >/dev/null 2>&1 &
export BAO_ADDR=https://127.0.0.1:8200 BAO_CACERT=~/bao-lab/tls/ca.crt
export BAO_TOKEN=$(bao login -no-store -token-only -method=userpass \
  username=admin password=lab-admin-pw)   # Admin aus Tag 13 (Root ist widerrufen)
bao policy write wettkampf - <<'EOF'
# Nur Tag 14: Secret reparieren (Szenario 4, 5, 8), Leak im Audit-Log suchen (6)
path "secret/data/webshop/config" { capabilities = ["create","read","update","delete"] }
path "secret/metadata/webshop/config" { capabilities = ["read"] }
path "secret/undelete/webshop/config" { capabilities = ["update"] }
path "sys/audit-hash/datei" { capabilities = ["update"] }
EOF
bao write auth/userpass/users/wettkampf password=lab-wk-pw \
  token_policies=bao-admin,wettkampf token_ttl=4h          # Lab-Passwort
export BAO_TOKEN=$(bao login -no-store -token-only -method=userpass \
  username=wettkampf password=lab-wk-pw)
bao operator raft snapshot save ~/bao-lab/tag14/vorher.snap     # Sicherheitsnetz
