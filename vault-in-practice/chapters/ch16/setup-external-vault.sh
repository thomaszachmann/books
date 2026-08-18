#!/usr/bin/env bash
# Chapter 16 Lab B - the cluster authenticates against the Chapter 2
# Vault container, which lives outside it.
#
# This is the arrangement regulated customers ask for: a Vault that does
# not depend on the cluster it protects, and that is out of reach of
# everybody with cluster-admin.
set -euo pipefail
cd "$(dirname "$0")/../.."

export VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
export VAULT_CACERT="${VAULT_CACERT:-$PWD/tls/vault-cert.pem}"
: "${VAULT_TOKEN:?export VAULT_TOKEN first - see: make env}"

FLAVOUR="${1:-kind}"

# 1. Reviewer ServiceAccount. An outside Vault has no pod identity.
kubectl create namespace vault-auth 2>/dev/null || true
kubectl -n vault-auth create serviceaccount vault-reviewer 2>/dev/null || true
kubectl create clusterrolebinding vault-reviewer \
  --clusterrole=system:auth-delegator \
  --serviceaccount=vault-auth:vault-reviewer 2>/dev/null || true

# 2. Since Kubernetes 1.24 no long-lived token is created automatically.
#    Every tutorial written before then omits this, and it is the most
#    common reason the configuration fails.
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: vault-reviewer-token
  namespace: vault-auth
  annotations:
    kubernetes.io/service-account.name: vault-reviewer
type: kubernetes.io/service-account-token
EOF

echo "waiting for the token controller..."
for i in $(seq 1 20); do
  JWT=$(kubectl -n vault-auth get secret vault-reviewer-token \
    -o jsonpath='{.data.token}' 2>/dev/null | base64 -d || true)
  [ -n "${JWT:-}" ] && break
  sleep 1
done
[ -n "${JWT:-}" ] || { echo "no token appeared" >&2; exit 1; }

kubectl -n vault-auth get secret vault-reviewer-token \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > /tmp/k8s-ca.crt

# 3. The API address Vault must use is not the one you use.
case "$FLAVOUR" in
  kind)
    K8S_HOST="https://vault-lab-control-plane:6443"
    docker network connect kind vault 2>/dev/null || true
    ;;
  minikube)
    K8S_HOST=$(kubectl config view --minify \
      -o jsonpath='{.clusters[0].cluster.server}')
    ;;
esac
echo "kubernetes_host=$K8S_HOST"

vault auth enable -path=k8s-lab kubernetes 2>/dev/null || true
vault write auth/k8s-lab/config \
  kubernetes_host="$K8S_HOST" \
  token_reviewer_jwt="$JWT" \
  kubernetes_ca_cert=@/tmp/k8s-ca.crt

vault policy write tracking-read chapters/ch16/policies/tracking-read.hcl
vault write auth/k8s-lab/role/tracking \
  bound_service_account_names=tracking \
  bound_service_account_namespaces=production \
  token_policies=tracking-read ttl=1h

echo
echo "Ready. From a pod in the production namespace, log in against"
echo "  https://vault:8200/v1/auth/k8s-lab/login"
