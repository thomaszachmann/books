#!/usr/bin/env bash
# Tag 14, Szenario 7, Störung auslösen - Befehle wörtlich aus dem Buch.
cd ~/bao-lab/tls                # openbao.ext aus Tag 7, Drill 4: dieselben SANs
openssl req -newkey rsa:2048 -nodes -keyout drill.key -out drill.csr -subj /CN=openbao
openssl x509 -req -in drill.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -not_before 20260101000000Z -not_after 20260102000000Z \
  -sha256 -extfile openbao.ext -out drill.crt
kubectl -n openbao create secret generic openbao-tls --from-file=tls.crt=drill.crt \
  --from-file=tls.key=drill.key --from-file=ca.crt=ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -
sleep 90   # kubelet aktualisiert das gemountete Secret
for i in 0 1 2; do
  kubectl -n openbao exec openbao-$i -- sh -c 'kill -HUP $(pidof bao)'
done
