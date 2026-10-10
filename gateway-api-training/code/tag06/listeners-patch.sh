#!/usr/bin/env bash
# Tag 6: ergänzt das Gateway web um die Listener https-grpc, tcp und udp.
set -euo pipefail
add() { kubectl -n infra patch gateway web --type=json \
  -p "[{\"op\":\"add\",\"path\":\"/spec/listeners/-\",\"value\":$1}]"; }
add '{"name":"https-grpc","protocol":"HTTPS","port":443,
  "hostname":"grpc.gw.localtest.me",
  "tls":{"mode":"Terminate","certificateRefs":[{"name":"grpc-gw-tls"}]},
  "allowedRoutes":{"namespaces":{"from":"All"},"kinds":[{"kind":"GRPCRoute"}]}}'
add '{"name":"tcp","protocol":"TCP","port":9100,
  "allowedRoutes":{"namespaces":{"from":"All"},"kinds":[{"kind":"TCPRoute"}]}}'
add '{"name":"udp","protocol":"UDP","port":9200,
  "allowedRoutes":{"namespaces":{"from":"All"},"kinds":[{"kind":"UDPRoute"}]}}'
