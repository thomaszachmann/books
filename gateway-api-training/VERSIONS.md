# Versions

The versions *Gateway API zum Anfassen* was written against, as the book
states them. Nothing here is pinned by a script except where noted. The book
asks you to install current tools (Homebrew or the official release pages,
Tag 0) and says outputs *können abweichen*. When a field differs, it tells you
to check `kubectl explain` and the docs at gateway-api.sigs.k8s.io and
gateway.envoyproxy.io.

## Gateway API and controllers

| Component | Version | Day |
|---|---|---|
| Gateway API CRDs (Experimental channel, shipped with the Envoy Gateway chart) | **v1.6.1** | 1, 9, 12 |
| Envoy Gateway, Helm chart `oci://docker.io/envoyproxy/gateway-helm` | **v1.9.2** (`up.sh`, `dashboards.sh` and `upgrade-eg.sh` use it as the default) | 1, 9, 10, 12, 14 |
| Envoy Gateway CRD chart `gateway-crds-helm` | v1.9.2 | 12, 14 |
| Conformance report read on Tag 12 | Envoy Gateway v1.9.0 / Gateway API v1.6.1 | 12 |
| Gateway API conformance suite (`git clone -b`) | v1.6.1 | 12 |
| cert-manager, chart `oci://quay.io/jetstack/charts/cert-manager` | **v1.21.2** | 4, 9, Anhang B |
| Cilium (RKE2 chart `rke2-cilium`) | 1.20; manifests checked against the 1.20.2 schemas | 8, 9 |
| kube-prometheus-stack | 92.2.0 | 11 |
| ingress-nginx (legacy controller) | chart 4.15.1 / controller v1.15.1, the last release; retired since March 2026 | 13 |

The book's Enterprise-Notiz on Tag 1 says Envoy Gateway v1.9 is built for Gateway API
v1.6.1. The Gateway API manifests use only Standard fields, except where a chapter
says *experimentell* (for example `retry` on Tag 3).

## Kubernetes

| Component | Version | Day |
|---|---|---|
| kind node image | `kindest/node:v1.37.0` (kind's default) | 0 |
| RKE2 | `v1.36.5+rke2r1` (`infra-rke2/group_vars/all.yml`) | 8 |
| kube-vip | v1.2.4 (`infra-rke2/group_vars/all.yml`) | 8 |
| Proxmox VE | 9.x | 8 |
| VM template | Ubuntu 24.04 cloud image | 8 |
| OpenTofu provider `bpg/proxmox` | v0.116.0 (`tofu init` output; `versions.tf` pins `~> 0.116.0`) | 8 |

The Envoy Gateway v1.9 compatibility matrix lists Kubernetes 1.33–1.36 (Tag 0, Tag 12).
The book runs on kind's default 1.37.0 and says it saw no problems. To stay inside the
matrix, it suggests `image: kindest/node:v1.36.x` per node.

## Tools

These versions come from the expected output of Tag 0, Drills 1 and 2. The book says
*Versionen können abweichen*.

| Tool | Version in the book | Day |
|---|---|---|
| `kind` | 0.33.0 | 0 |
| `kubectl` (`kubernetes-cli`) | 1.37.1 | 0 |
| `helm` | 4.3.0 | 0 |
| `cloud-provider-kind` | 0.12.0 (`go install …@v0.12.0` on Linux) | 0 |
| `jq` | 1.8.2 | 0 |
| `grpcurl` | 1.9.4 | 0, 6 |
| Docker | 29.9.0 client / 29.5.2 server | 0 |
| `egctl` | v1.9.2 (Linux release binary; Homebrew on macOS) | 11, 12, 14 |
| `ingress2gateway` | v1.2.0 (Linux release tarball) | 13 |

The book uses these tools without naming a version: `tofu`, `ansible`, `ansible-lint`,
`htpasswd`, `yq`, `cmctl`, `openssl`, `dig`, `go`.

## Images the labs pull

| Image | Tag in the book | Day |
|---|---|---|
| `registry.k8s.io/gateway-api/echo-basic` | `v1.6.0` | 0, 6, 7 |
| `envoyproxy/envoy` (started by cloud-provider-kind for each LoadBalancer service) | `v1.33.2` in the book's output | 0 |
| `busybox` | `1.37` | 6 (tip) |
| `ghcr.io/kube-vip/kube-vip` | `v1.2.4` | 8 |
| `jaegertracing/jaeger` | `2.22.0` | 11 |

## What the book says was checked

This is the book's own account. No new test was run for this repository.

| Part | Statement in the book |
|---|---|
| Preface | *Getestet mit Gateway API v1.6, Envoy Gateway v1.9.2, kind 0.33 (Kubernetes 1.37) und cloud-provider-kind 0.12.0.* |
| Tag 8 | Proxmox, multi-node RKE2 and ARP VIPs cannot be reproduced in kind. All outputs come from the official docs or from static validation (`tofu validate`, `ansible-lint`, `helm template`), and are marked *(gekürzt, kann je nach Version abweichen)*. |
| Tag 9 | All manifests are checked with `kubeconform` against the CRD schemas of Gateway API v1.6.1, Envoy Gateway v1.9.2, Cilium 1.20.2 and cert-manager v1.21.2. Outputs *(gekürzt, kann je nach Version abweichen)*. |
| Tag 10 | `kubeconform` (strict, no unknown fields) against Envoy Gateway v1.9.2 and Gateway API v1.6.1. The CRDs' CEL rules were compared by hand. Outputs are not produced live. |
| Tag 11 | `kubeconform` (CRDs of Envoy Gateway v1.9.2, kube-prometheus-stack 92.2.0) and `promtool`. Outputs are not produced live. |
| Tag 12 | Manifests and Helm renderings are checked with `kubeconform` against the CRDs of Envoy Gateway v1.9.2. Outputs are not produced live. The exception is Drill 8, whose output was checked live against the published conformance report. |
| Tag 13 | The `ingress2gateway` v1.2.0 conversion ran live against the sample files, so those outputs are real. Manifests are checked with `kubeconform`. Cluster outputs are not produced live. |
| Tag 14 | `kubeconform` against Gateway API v1.6.1 and Envoy Gateway v1.9.2; scripts checked with `shellcheck`. Outputs *(gekürzt, kann je nach Version abweichen)*. |

The only checks made for this repository compared the files with the manuscript.

| Check | Result |
|---|---|
| Heredocs in the book whose file is in `code/` (34, Tag 0–7) | 28 are byte-identical. 6 differ only in a comment line or in YAML indentation; see [`ERRATA.md`](ERRATA.md). |
| `demo/shop-v2.yaml` against the `sed` command on Tag 0 that produces it | identical |
| `bash -n` on every `.sh` | all pass |
| YAML parse of all 77 `.yaml`/`.yml` files (not the `.j2` templates) | all pass |
