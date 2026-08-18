#!/usr/bin/env bash
# Chapter 18 Lab B - OpenBao in Kubernetes with kubernetes auth.
#
# Compare with chapters/ch16/setup-k8s-auth.sh: the only differences are
# the binary name and the environment variable.
set -euo pipefail

helm repo add openbao https://openbao.github.io/openbao-helm >/dev/null
helm repo update >/dev/null
helm upgrade --install openbao openbao/openbao \
  --namespace openbao --create-namespace \
  --set "server.dev.enabled=true" \
  --wait --timeout 3m

kubectl -n openbao get pods

kubectl -n openbao exec -i openbao-0 -- sh <<'INNER'
set -e
export BAO_TOKEN=root

bao auth enable kubernetes 2>/dev/null || true
bao write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"

bao kv put secret/tracking \
  db_user=tracking_svc db_password=openbao-k8s

bao policy write tracking-read - <<'POL'
path "secret/data/tracking" {
  capabilities = ["read"]
}
POL

bao write auth/kubernetes/role/tracking \
  bound_service_account_names=tracking \
  bound_service_account_namespaces=production \
  token_policies=tracking-read ttl=1h
INNER

echo
echo "Prove it from a pod:"
echo "  kubectl -n production run bao-prover --rm -it --restart=Never \\"
echo "    --overrides='{\"spec\":{\"serviceAccountName\":\"tracking\"}}' \\"
echo "    --image=curlimages/curl -- sh"
echo
echo "  curl -s --request POST --data \"{\\\"jwt\\\": \\\"\$JWT\\\", \\\"role\\\": \\\"tracking\\\"}\" \\"
echo "    http://openbao.openbao.svc:8200/v1/auth/kubernetes/login"
