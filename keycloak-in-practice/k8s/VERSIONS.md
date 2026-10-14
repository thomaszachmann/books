# Part IV versions

`VERSIONS.md` in the repository root pins Keycloak and everything the
compose lab runs. This file pins what Part IV adds. The labs of Chapters
15 to 17 were run against exactly these.

```sh
KIND_VERSION=v0.32.0
KIND_NODE_IMAGE=kindest/node:v1.36.1
KUBECTL_MIN=1.34
INGRESS_NGINX_VERSION=controller-v1.15.1
KEYCLOAK_OPERATOR_VERSION=26.5.2
GRAFANA_VERSION=11.6.0
OAUTH2_PROXY_VERSION=v7.15.4
```

## Why these

**kind v0.32.0**, whose default node image is Kubernetes 1.36.1. Chapter
16 needs structured authentication configuration at `apiserver.config.k8s.io/v1`
(GA since 1.34) and its automatic reload when the file changes (since
1.30). An older node image refuses the `v1` file or ignores the change.

**kubectl 1.34 or newer.** Older clients work and print a version-skew
warning against a 1.36 server; `kubectl auth whoami` needs 1.28.

**ingress-nginx controller-v1.15.1**, pinned in
`k8s/ingress-nginx/kustomization.yaml`, not `main`. The project is in
maintenance; the pin keeps the lab reproducible, and the kustomization
is where the one change this book makes to it lives (the controller's
host port is 8443, see `k8s/kind/cluster.yaml`).

**The Keycloak operator** is always the same version as Keycloak
(`KEYCLOAK_VERSION` in the root `VERSIONS.md`); Chapter 15 reads it
from there. It runs Keycloak's default image of the same version.

**Grafana and oauth2-proxy** are pinned in their manifests in
`k8s/base/`; the numbers here are what those manifests say. Chapter 17
depends on Grafana's `role_attribute_path` and oauth2-proxy's
`keycloak-oidc` provider, both stable across these releases.

## minikube

Not pinned, and not what the labs were run on; see
`k8s/minikube/README.md` for the differences.
