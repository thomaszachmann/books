#!/usr/bin/env bash
# Tag 14, Szenario 7, Störung auslösen - Befehle wörtlich aus dem Buch.
cd ~/bao-lab/tls
SAN="DNS:openbao,DNS:openbao-active,DNS:*.openbao-internal"
SAN="$SAN,DNS:*.openbao-internal.openbao.svc.cluster.local,DNS:openbao.openbao.svc"
echo "subjectAltName=$SAN,DNS:localhost,IP:127.0.0.1" > san.ext
openssl req -newkey rsa:2048 -nodes -keyout drill.key -out drill.csr -subj /CN=openbao
openssl x509 -req -in drill.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -not_before 20260101000000Z -not_after 20260102000000Z -extfile san.ext -out drill.crt
kubectl -n openbao create secret generic openbao-tls --from-file=tls.crt=drill.crt \
  --from-file=tls.key=drill.key --from-file=ca.crt=ca.crt \
  --dry-run=client -o yaml | kubectl apply -f -
sleep 90   # kubelet aktualisiert das gemountete Secret
for i in 0 1 2; do
  kubectl -n openbao exec openbao-$i -- sh -c 'kill -HUP $(pidof bao)'
done
