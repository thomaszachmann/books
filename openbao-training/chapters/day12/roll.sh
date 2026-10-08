#!/usr/bin/env bash
set -euo pipefail
NS=openbao
pf() {
  pkill -f "port-forward svc/openbao-active" || true
  kubectl -n $NS port-forward svc/openbao-active 8200:8200 >/dev/null 2>&1 &
  sleep 3
}
recreate() {
  kubectl -n $NS delete pod "$1"
  sleep 5
  kubectl -n $NS wait --for=condition=Ready pod/"$1" --timeout=300s
}
L=$(kubectl -n $NS get pod -l openbao-active=true -o name); L=${L#pod/}
echo "Leader: $L"
for p in openbao-0 openbao-1 openbao-2; do
  [ "$p" = "$L" ] || recreate "$p"
done
bao operator step-down
sleep 10
recreate "$L"
pf
bao operator raft autopilot state | head -4
