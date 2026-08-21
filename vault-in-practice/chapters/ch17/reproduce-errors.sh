#!/usr/bin/env bash
# Chapter 17 - the injector failures, on purpose.
#
# Needs the cluster and the Agent Injector:
#   ./chapters/ch16/cluster-up.sh
#   ./chapters/ch17/deploy-injector.sh
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env
command -v kubectl >/dev/null || { echo "kubectl required"; exit 1; }
NS="${WWR_NS:-default}"
SA="${WWR_APP_SA:-app}"
ROLE="${WWR_K8S_ROLE:-demo}"
SECRET="${WWR_SECRET_PATH:-secret/data/demo}"
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT

kubectl -n "$NS" get sa "$SA" >/dev/null 2>&1 || kubectl -n "$NS" create sa "$SA" >/dev/null

deploy() {  # deploy <name> <annotations-block-indent-6> [role]
  cat > "$W/$1.yaml" <<YML
apiVersion: apps/v1
kind: Deployment
metadata: { name: $1 }
spec:
  replicas: 1
  selector: { matchLabels: { app: $1 } }
  template:
    metadata:
      labels: { app: $1 }
$2
    spec:
      serviceAccountName: $SA
      containers:
        - name: app
          image: alpine:3.20
          command: ["sh","-c","sleep 3600"]
YML
  kubectl -n "$NS" apply -f "$W/$1.yaml" >/dev/null
}
ANN() { printf '      annotations:\n        vault.hashicorp.com/agent-inject: "true"\n        vault.hashicorp.com/role: "%s"\n        vault.hashicorp.com/agent-inject-secret-db: "%s"\n' "$1" "$SECRET"; }
containers() { kubectl -n "$NS" get pods -l "app=$1" \
  -o jsonpath='{.items[0].spec.containers[*].name}' 2>/dev/null; }
wait_pod() { for _ in $(seq 30); do
  [ -n "$(kubectl -n "$NS" get pods -l "app=$1" -o name 2>/dev/null)" ] && sleep 6 && return 0
  sleep 2; done; }

wwr_case "the pod starts with one container and no secrets"
deploy wwr17-ok "$(ANN "$ROLE")"
wait_pod wwr17-ok
printf '  annotations in the POD TEMPLATE : containers = %s\n' "$(containers wwr17-ok)"
# The same annotations, on the Deployment's own metadata instead.
python3 - "$W/wwr17-bad.yaml" "$ROLE" "$SECRET" <<'PY'
import sys
name,role,secret = "wwr17-bad", sys.argv[2], sys.argv[3]
open(sys.argv[1],"w").write(f"""apiVersion: apps/v1
kind: Deployment
metadata:
  name: {name}
  annotations:
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "{role}"
    vault.hashicorp.com/agent-inject-secret-db: "{secret}"
spec:
  replicas: 1
  selector: {{ matchLabels: {{ app: {name} }} }}
  template:
    metadata:
      labels: {{ app: {name} }}
    spec:
      serviceAccountName: app
      containers:
        - name: app
          image: alpine:3.20
          command: ["sh","-c","sleep 3600"]
""")
PY
kubectl -n "$NS" apply -f "$W/wwr17-bad.yaml" >/dev/null
wait_pod wwr17-bad
printf '  annotations on the DEPLOYMENT   : containers = %s\n' "$(containers wwr17-bad)"
echo
echo "One container, no init container, no error anywhere. The webhook"
echo "reads the POD's annotations, and a Deployment's own metadata is not"
echo "the pod's. Nothing warns you, because from the webhook's point of"
echo "view this pod simply did not ask for anything."

wwr_case "what the injected file actually looks like"
P=$(kubectl -n "$NS" get pods -l app=wwr17-ok -o jsonpath='{.items[0].metadata.name}')
kubectl -n "$NS" exec "$P" -c app -- cat /vault/secrets/db 2>/dev/null | head -2 | sed 's/^/  /'
echo "That is Go's map syntax, not a configuration file. Without an"
echo "agent-inject-template annotation you get the whole response printed,"
echo "which no application can parse."

wwr_case "agent-inject is set but the init container never finishes"
deploy wwr17-badrole "$(ANN "does-not-exist")"
wait_pod wwr17-badrole
BP=$(kubectl -n "$NS" get pods -l app=wwr17-badrole -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
printf '  pod phase        : %s\n' "$(kubectl -n "$NS" get pod "$BP" -o jsonpath='{.status.phase}' 2>/dev/null)"
printf '  init container   : %s\n' "$(kubectl -n "$NS" get pod "$BP" -o jsonpath='{.status.initContainerStatuses[0].state}' 2>/dev/null | head -c 60)"
echo "  its log says:"
kubectl -n "$NS" logs "$BP" -c vault-agent-init 2>/dev/null \
  | grep -iE "invalid role|error|denied" | tail -2 | cut -c1-100 | sed 's/^/    /'
echo
echo "Note the phase: it does not fail, it RETRIES. A pod stuck in Init"
echo "with no events and no restarts is this, and the only place the"
echo "reason appears is that container's log:"
echo "  \$ kubectl logs <pod> -c vault-agent-init"

kubectl -n "$NS" delete deploy wwr17-ok wwr17-bad wwr17-badrole >/dev/null 2>&1
echo
echo "Not reproduced here: VSO, ESO and the CSI driver, which need their"
echo "own operators. deploy-vso.sh, deploy-eso.sh and the CSI steps in"
echo "the chapter install them; the failures then follow the same shape -"
echo "a controller log, not an application error."
wwr_done
