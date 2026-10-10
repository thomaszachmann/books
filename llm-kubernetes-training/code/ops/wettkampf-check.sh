#!/usr/bin/env bash
# Gesamtprüfung der KI-Plattform (Tag 15): alle Zeilen ✔ = Szenario gelöst
export KUBECONFIG=${KUBECONFIG:-$HOME/ki-lab/rke2.yaml}
API=${API:-https://llm.lab.internal}
export M=${LITELLM_MASTER_KEY:-sk-lab-master-1234}                  # Lab-Wert
check() { if eval "$2" >/dev/null 2>&1; then echo "✔ $1"; else echo "✘ $1"; fi; }
check "6 Nodes Ready" '[ "$(kubectl get nodes --no-headers \
  | awk "\$2==\"Ready\"" | wc -l)" -eq 6 ]'
check "API über VIP" 'curl -sk --max-time 5 https://10.10.20.10:6443/livez'
check "GPU-Slots auf rke2-gpu-1" '[ "$(kubectl get node rke2-gpu-1 \
  -o jsonpath="{.status.allocatable.nvidia\.com/gpu}")" = 4 ]'
check "vllm-chat/-embed/-code Ready" 'for d in vllm-chat vllm-embed vllm-code; do
  kubectl -n ki-models rollout status deploy/$d --timeout=5s || exit 1; done'
check "chat-large lokal (kein Fallback)" 'curl -s -D - -o /dev/null --max-time 60 \
  $API/v1/chat/completions -H "Authorization: Bearer $M" \
  -H "Content-Type: application/json" -d "{\"model\":\"chat-large\",
  \"messages\":[{\"role\":\"user\",\"content\":\"OK\"}],\"max_tokens\":5}" \
  | grep -qi "^x-litellm-model-group: chat-large\s*$"'
check "Team-Budgets nicht erschöpft" '[ "$(curl -s $API/team/list \
  -H "Authorization: Bearer $M" | jq "[.[] | select(.max_budget != null
  and .spend >= .max_budget)] | length")" -eq 0 ]'
check "CNPG litellm-db + owui-db" '
  kubectl -n ki-gateway wait cluster/litellm-db --for=condition=Ready --timeout=5s &&
  kubectl -n ki-chat wait cluster/owui-db --for=condition=Ready --timeout=5s'
check "Longhorn-Volumes healthy" '[ -z "$(kubectl -n longhorn-system get \
  volumes.longhorn.io -o json | jq -r ".items[] | select(.status.state
  == \"attached\") | .status.robustness" | grep -vx healthy)" ]'
check "TLS mit Lab-CA" 'curl -sf --max-time 5 $API/health/readiness'
check "Velero-Ziel verfügbar" '[ "$(kubectl -n velero get backupstoragelocation \
  default -o jsonpath="{.status.phase}")" = Available ]'
