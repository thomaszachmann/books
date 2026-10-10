#!/usr/bin/env bash
# Abschlussprüfung (Anhang B): prüft Aufgabe 1-9 und zählt Punkte
# Aufruf: PRUEF_KEY=sk-... ./pruefung.sh
export KUBECONFIG=${KUBECONFIG:-$HOME/ki-lab/rke2.yaml}
API=https://llm.lab.internal
M=sk-lab-master-1234                                       # Lab-Wert
P=0; PFLICHT=0
aufgabe() {  # Nummer, Punkte, Titel, Prüfung
  if eval "$4" >/dev/null 2>&1; then
    echo "✔ A$1 $3 (+$2)"; P=$((P + $2)); [ "$1" = 8 ] && PFLICHT=1
  else
    echo "✘ A$1 $3 (0/$2)"
  fi
}
k() { kubectl "$@"; }
prom() {
  k -n monitoring exec prometheus-kube-prometheus-stack-prometheus-0 \
    -c prometheus -- wget -qO- "http://localhost:9090/api/v1/$1"
}
lit() { curl -s "$API$1" -H "Authorization: Bearer $M" "${@:2}"; }
args() {
  k -n ki-models get deploy "$1" -o jsonpath='{.spec.template.spec.containers[0].args}'
}

k -n ki-chat port-forward svc/qdrant 16333:6333 >/dev/null 2>&1 &
PF=$!; trap 'kill $PF 2>/dev/null' EXIT; sleep 2

aufgabe 1 5 "Cluster gesund" '[ "$(k get nodes --no-headers | grep -c " Ready ")" \
  -eq 6 ] && [ "$(k get nodes -l node-role.kubernetes.io/etcd=true --no-headers \
  | wc -l)" -eq 3 ] && curl -sk --max-time 5 https://10.10.20.10:6443/livez'

aufgabe 2 10 "GPU geteilt, Budget < 1" '[ "$(k get node rke2-gpu-1 \
  -o jsonpath="{.status.allocatable.nvidia\.com/gpu}")" = 4 ] && \
  awk "BEGIN {exit !($(for d in vllm-chat vllm-embed vllm-code; do args $d \
  | grep -oE "utilization=[0-9.]+" | cut -d= -f2; done | paste -sd+ -) < 1)}"'

aufgabe 3 15 "vllm-chat fp8 + 8192" 'args vllm-chat | grep -q kv-cache-dtype=fp8 \
  && args vllm-chat | grep -q max-model-len=8192 \
  && k -n ki-models rollout status deploy/vllm-chat --timeout=5s \
  && grep -q kv-cache-dtype=fp8 ~/ki-lab/code/vllm/vllm-chat.yaml'

aufgabe 4 10 "Alias chat-kurz" 'lit /v1/models | jq -e ".data[] | select(.id ==
  \"chat-kurz\")" && [ "$(lit /v1/chat/completions -H "Content-Type: \
  application/json" -d "{\"model\":\"chat-kurz\",\"messages\":[{\"role\":
  \"user\",\"content\":\"Erzähle lange.\"}]}" | jq ".usage.completion_tokens")" \
  -le 128 ]'

aufgabe 5 15 "Team und Key" 'lit /team/list | jq -e ".[] | select(.team_alias ==
  \"team-pruefung\" and .max_budget == 2 and .rpm_limit == 20)" \
  && lit "/key/info?key=$PRUEF_KEY" | jq -e ".info | .key_alias == \"pruefer\"
  and .metadata.disable_fallbacks == true and .expires != null"'

aufgabe 6 10 "Qdrant-Collection pruefung" 'curl -s \
  localhost:16333/collections/pruefung -H "api-key: $(k -n ki-chat get secret \
  qdrant-auth -o jsonpath="{.data.api-key}" | base64 -d)" \
  | jq -e ".result.points_count >= 3 and .result.config.params.vectors.size == 1024"'

aufgabe 7 10 "Alarme + Dashboard" 'prom rules | jq -e "[.data.groups[].rules[]
  | select(.name == \"KIPruefungEmbedWeg\")] | length == 1" && k -n monitoring \
  get configmap -l grafana_dashboard=1 -o name | grep -q ki-dashboard'

aufgabe 8 15 "Backup + etcd-Snapshot (Pflicht)" '[ "$(k -n velero get \
  backup pruefung -o jsonpath="{.status.phase}")" = Completed ] \
  && k -n velero get backup pruefung -o jsonpath="{.spec.includedNamespaces}" \
  | grep -q ki-chat && k get etcdsnapshotfiles -o json | jq -e "[.items[]
  | select(.spec.snapshotName | startswith(\"pruefung\")) | select(.spec.s3)]
  | length > 0"'

aufgabe 9 10 "Störung behoben" '! ~/ki-lab/code/ops/wettkampf-check.sh \
  | grep -q "✘"'

echo "Punkte: $P / 100"
if [ "$P" -ge 70 ] && [ "$PFLICHT" = 1 ]; then echo "✔ bestanden"
else echo "✘ nicht bestanden (mind. 70 Punkte und Aufgabe 8)"; fi
