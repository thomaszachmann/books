#!/usr/bin/env bash
# Chapter 16 Lab A - kubernetes auth, Vault inside the cluster.
#
# No reviewer JWT and no CA file: Vault is a pod, so it uses its own
# ServiceAccount token and the CA Kubernetes already mounted for it.
set -euo pipefail
cd "$(dirname "$0")"

kubectl -n vault exec -i vault-0 -- sh <<'INNER'
set -e
export VAULT_TOKEN=root

vault auth enable kubernetes 2>/dev/null || true
vault write auth/kubernetes/config \
  kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"

vault kv put secret/tracking \
  db_user=tracking_svc db_password=k8s-lab-pw

vault policy write tracking-read - <<'POL'
path "secret/data/tracking" {
  capabilities = ["read"]
}
POL

# Both bounds together are the identity. Binding only the name lets
# anybody who can create a namespace mint this identity.
vault write auth/kubernetes/role/tracking \
  bound_service_account_names=tracking \
  bound_service_account_namespaces=production \
  token_policies=tracking-read \
  ttl=1h
INNER

kubectl create namespace production 2>/dev/null || true
kubectl -n production create serviceaccount tracking 2>/dev/null || true

echo
echo "Ready. Prove it from a pod:"
echo "  kubectl -n production run prover --rm -it --restart=Never \\"
echo "    --overrides='{\"spec\":{\"serviceAccountName\":\"tracking\"}}' \\"
echo "    --image=curlimages/curl -- sh"
echo
echo "Then, inside:"
echo '  JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)'
echo '  curl -s --request POST \'
echo '    --data "{\"jwt\": \"$JWT\", \"role\": \"tracking\"}" \'
echo '    http://vault.vault.svc:8200/v1/auth/kubernetes/login'
