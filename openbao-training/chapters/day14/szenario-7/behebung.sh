#!/usr/bin/env bash
# Tag 14, Szenario 7, Behebung - Befehle wörtlich aus dem Buch.
openssl x509 -req -in drill.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 365 -extfile san.ext -out tls.crt && cp drill.key tls.key
kubectl -n openbao create secret generic openbao-tls --from-file=tls.crt \
  --from-file=tls.key --from-file=ca.crt --dry-run=client -o yaml | kubectl apply -f -
sleep 90
for p in $(kubectl -n openbao get pods -l openbao-active!=true -o name) \
         $(kubectl -n openbao get pods -l openbao-active=true -o name); do
  kubectl -n openbao exec "${p#pod/}" -- sh -c 'kill -HUP $(pidof bao)'
  kubectl -n openbao exec "${p#pod/}" -- bao status >/dev/null \
    && echo "✔ $p" || echo "✘ $p"
done
