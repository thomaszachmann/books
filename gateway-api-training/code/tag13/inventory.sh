#!/usr/bin/env bash
# Inventur aller Ingress-Ressourcen: Klassen, Hosts, Annotationen (Tag 13).
# Aufruf: inventory.sh [datei.json]   ohne Datei: live aus dem Cluster
set -euo pipefail
T=$(mktemp)
if [ $# -gt 0 ]; then cat "$1"; else kubectl get ingress -A -o json; fi > "$T"
echo "== Ingress pro Klasse"
jq -r '.items[] | .spec.ingressClassName
  // .metadata.annotations["kubernetes.io/ingress.class"] // "(keine)"' "$T" \
  | sort | uniq -c
echo "== Hosts"
jq -r '.items[] | .spec.rules[]?.host // "*"' "$T" | sort | uniq -c
echo "== Annotationen (Häufigkeit)"
jq -r '.items[].metadata.annotations // {} | keys[]
  | select(test("nginx|traefik"))' "$T" | sort | uniq -c | sort -rn
echo "== Risiko: Snippets und Regex"
jq -r '.items[] | select(.metadata.annotations // {} | keys
  | any(test("snippet|use-regex|rewrite-target|auth-")))
  | "\(.metadata.namespace)/\(.metadata.name)"' "$T"
rm -f "$T"
