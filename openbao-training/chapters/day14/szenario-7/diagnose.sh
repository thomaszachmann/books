#!/usr/bin/env bash
# Tag 14, Szenario 7, Diagnose - Befehle wörtlich aus dem Buch.
openssl s_client -connect 127.0.0.1:8200 -CAfile ca.crt </dev/null 2>/dev/null \
  | grep 'Verify return code'
openssl s_client -connect 127.0.0.1:8200 </dev/null 2>/dev/null \
  | openssl x509 -noout -enddate
kubectl -n openbao exec openbao-1 -- bao status 2>&1 | head -2
