#!/usr/bin/env bash
# Chapter 16 - the Kubernetes auth failures, on purpose.
#
# Needs a cluster and a Vault the cluster can reach:
#   ./chapters/ch16/cluster-up.sh
#   ./chapters/ch16/setup-k8s-auth.sh
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 1
. ./scripts/wwr-lib.sh
wwr_env
command -v kubectl >/dev/null || { echo "kubectl required - see Appendix A"; exit 1; }

NODE="${WWR_K8S_NODE:-$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')}"
IP=$(kubectl get node "$NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
CTX=$(kubectl config current-context)
CA=$(kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"$CTX\")].cluster.certificate-authority-data}" | base64 -d)
ROLE="${WWR_K8S_ROLE:-demo}"
RSA="${WWR_REVIEWER_SA:-vault-reviewer}"
ASA="${WWR_APP_SA:-app}"

reviewer() { kubectl create token "$RSA" --duration=24h; }
appjwt()   { kubectl create token "$ASA" --duration=1h; }
config()   { vault write auth/kubernetes/config kubernetes_host="$1" \
               token_reviewer_jwt="$(reviewer)" kubernetes_ca_cert="$2" >/dev/null; }
login()    { vault write auth/kubernetes/login role="$ROLE" jwt="$1" 2>&1; }

GOOD_HOST="https://${IP}:6443"
config "$GOOD_HOST" "$CA"

wwr_case "the reviewer ServiceAccount has no token secret"
printf '  kubectl get sa %s -o jsonpath={.secrets} -> [%s]\n' \
  "$RSA" "$(kubectl get sa "$RSA" -o jsonpath='{.secrets}' 2>/dev/null)"
echo "Empty. Kubernetes stopped creating them in 1.24, so the old advice"
echo "to read the SA's secret finds nothing. Mint one instead:"
echo "  \$ kubectl create token $RSA --duration=24h"

wwr_case "permission denied on login, with a perfectly valid token"
echo "A real, unexpired token - for the wrong ServiceAccount:"
login "$(kubectl create token "$RSA" --duration=1h)" | grep -E "Code:|^\*|\* " | head -3 | sed 's/^/  /'
echo "That one names the cause. The next three do not."

wwr_case "the three that all say permission denied"
echo "Vault answers the client identically whatever is actually wrong."
echo
printf '  reviewer without TokenReview rights : '
kubectl delete clusterrolebinding "${RSA}-crb" >/dev/null 2>&1; sleep 2
login "$(appjwt)" | grep -oE "permission denied|service account name not authorized" | head -1
kubectl create clusterrolebinding "${RSA}-crb" --clusterrole=system:auth-delegator \
  --serviceaccount="default:$RSA" >/dev/null 2>&1; sleep 2
config "$GOOD_HOST" "$CA"

printf '  kubernetes_host unreachable        : '
config "https://127.0.0.1:6443" "$CA"
login "$(appjwt)" | grep -oE "permission denied" | head -1

printf '  wrong kubernetes_ca_cert           : '
BAD=$(openssl req -x509 -newkey rsa:2048 -sha256 -days 1 -nodes \
        -keyout /dev/null -subj "/CN=not-your-cluster" 2>/dev/null)
config "$GOOD_HOST" "$BAD"
r=$(login "$(appjwt)" | grep -oE "permission denied|^token " | head -1)
case "${r:-}" in
  "permission denied") echo "permission denied" ;;
  *)                   echo "LOGIN SUCCEEDED - which is the finding" ;;
esac
config "$GOOD_HOST" "$CA"

if [ "${r:-}" != "permission denied" ]; then
  echo
  echo "  That succeeded with a certificate from nowhere, and it is not a"
  echo "  Vault bug. The auth backend builds its Kubernetes client once and"
  echo "  keeps it: writing auth/kubernetes/config does NOT rebuild it."
  echo
  echo "  Which has a consequence worth more than the error message:"
  echo "  after correcting a host or a CA, testing immediately tells you"
  echo "  nothing. You are still talking to the old client. Disable and"
  echo "  re-enable the mount, or restart Vault, before you believe a fix:"
  echo "    \$ vault auth disable kubernetes && vault auth enable kubernetes"
fi

echo
echo "Three different faults, one message, and the default log level says"
echo "nothing at all. This is the single most useful thing to know about"
echo "debugging Kubernetes auth: the cause is only visible at debug level,"
echo "on the VAULT side, in a line that begins 'login unauthorized':"
echo
echo "  \$ vault server -log-level=debug ...        # or VAULT_LOG_LEVEL=debug"
echo "  [DEBUG] auth.kubernetes...: login unauthorized:"
echo "      err=\"Post \\\"https://127.0.0.1:6443/apis/authentication...\""
echo
echo "Read the URL in that line. It answers host, certificate and"
echo "reachability at once - the same discipline as Chapter 7's login URL."

wwr_case "a working login, to prove the setup is sound"
login "$(appjwt)" | grep -E "^token |token_policies" | head -2 | sed 's/^/  /'

echo
echo "Not reproduced here: pods that cannot reach an external Vault, and"
echo "a Vault that loses its data on every restart. The first is your"
echo "network rather than Vault's, and the second is a Deployment with no"
echo "volume - Chapter 20's storage question wearing a Kubernetes hat."
wwr_done
