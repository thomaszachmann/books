#!/usr/bin/env bash
# Tag 7, Drill 3 - Befehle wörtlich aus dem Buch.
cd ~/bao-lab/tls
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout ca.key -out ca.crt -subj "/CN=bao-lab Root CA" \
  -addext "basicConstraints=critical,CA:TRUE" \
  -addext "keyUsage=critical,keyCertSign,cRLSign"
openssl x509 -in ca.crt -noout -subject -ext basicConstraints
