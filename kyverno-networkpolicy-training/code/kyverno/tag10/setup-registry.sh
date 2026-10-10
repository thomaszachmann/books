#!/usr/bin/env bash
# setup-registry.sh - Lab-Registry kind-registry:5000 mit TLS fuer kyverno-lab (Tag 10)
#   Erzeugt ein selbstsigniertes Lab-Zertifikat (certs/), startet registry:2 mit TLS,
#   haengt sie ins kind-Netz und traegt die CA auf jedem Node in containerd ein.
#   Host-Zugriff: https://localhost:${PORT:-5001}
set -euo pipefail
CLUSTER=${CLUSTER:-kyverno-lab}; PORT=${PORT:-5001}; R=kind-registry:5000
mkdir -p certs
[ -f certs/registry.crt ] || openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -subj "/CN=kind-registry" -addext "subjectAltName=DNS:kind-registry,DNS:localhost" \
  -keyout certs/registry.key -out certs/registry.crt 2>/dev/null
if ! docker inspect kind-registry >/dev/null 2>&1; then
  docker create --name kind-registry -p "127.0.0.1:${PORT}:5000" \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
    -e REGISTRY_HTTP_TLS_KEY=/certs/registry.key registry:2 >/dev/null
  docker cp certs kind-registry:/certs
  docker start kind-registry >/dev/null
  docker network connect kind kind-registry
fi
for n in $(kind get nodes --name "$CLUSTER"); do
  docker exec "$n" mkdir -p "/etc/containerd/certs.d/$R"
  docker cp certs/registry.crt "$n:/etc/containerd/certs.d/$R/ca.crt"
  printf '[host."https://%s"]\n  ca = "/etc/containerd/certs.d/%s/ca.crt"\n' "$R" "$R" \
    | docker exec -i "$n" tee "/etc/containerd/certs.d/$R/hosts.toml" >/dev/null
  echo "✔ $n vertraut $R"
done
curl -s --cacert certs/registry.crt "https://localhost:${PORT}/v2/" >/dev/null \
  && echo "✔ Registry erreichbar: https://localhost:${PORT}" \
  || echo "✘ Registry nicht erreichbar"
