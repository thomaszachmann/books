#!/usr/bin/env bash
# Prüft, ob alle Lab-Werkzeuge im PATH liegen.
set -u
tools="docker kind kubectl helm git jq yq curl openssl cosign syft grype
trivy checkov semgrep gitleaks skopeo oras crane vault kyverno conftest
opa argocd"
missing=0
for t in $tools; do
  if command -v "$t" >/dev/null 2>&1; then
    printf "OK      %s\n" "$t"
  else
    printf "FEHLT   %s\n" "$t"
    missing=$((missing + 1))
  fi
done
docker compose version >/dev/null 2>&1 \
  && echo "OK      docker compose" \
  || { echo "FEHLT   docker compose"; missing=$((missing + 1)); }
echo "Fehlend: $missing"
exit "$missing"
