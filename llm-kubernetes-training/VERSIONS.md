# Versions

The versions *LLMs auf Kubernetes zum Anfassen* was written against, as
the book states them. Nothing here is pinned by a script beyond what the
files themselves pin. The book says it was tested with kind 0.33,
kubectl 1.37, Helm 4.3 and llama.cpp `server-b11515`, and tells you to
check `--help` and the official documentation when a flag differs. Anhang
A gives the state of the chapters as: kind 0.33, RKE2 v1.36.5, GPU
Operator v26.7.1, vLLM v0.31.0, LiteLLM 1.104.2, Open WebUI chart 16.6.0,
Velero 1.18.

## Laptop tools

Tag 0 installs current tools (Homebrew on macOS; Docker's repository and
the official release pages on Linux). The versions are from the book's
expected output, which says they may differ.

| Tool | Version in the book | Day |
|---|---|---|
| `kind` | 0.33.0 (node image `kindest/node:v1.37.0`) | 0, 1 |
| `kubectl` (`kubernetes-cli`) | 1.37.1 | 0 |
| `helm` | 4.3.0 | 0 |
| `docker` | 29.9.0; Tag 1 relies on Docker 29's containerd image store | 0, 1 |
| `colima` | 0.10.3 | 0 |
| `jq` | 1.8.2 | 0 |
| `k9s` | 0.51.0 | 0 |
| Python | 3.14.8 | 0 |
| OpenAI SDK (`openai`, in `~/ki-lab/.venv`) | 3.27.0 | 0 |
| OpenTofu | `required_version = ">= 1.8"` in `versions.tf` | 7 |

## Part A: kind on the laptop

| Component | Version | Day |
|---|---|---|
| Ingress-NGINX | `controller-v1.15.1`, the last release; discontinued upstream since March 2026 | 1 |
| metrics-server chart | 3.14.0 | 1 |
| llama.cpp image | `ghcr.io/ggml-org/llama.cpp:server-b11515` | 1, 2, 4 |
| Chat model | `Qwen/Qwen2.5-0.5B-Instruct-GGUF`, `Q4_K_M`, alias `qwen2.5-0.5b` | 2 |
| Embedding model | `second-state/All-MiniLM-L6-v2-Embedding-GGUF`, `all-MiniLM-L6-v2-Q8_0.gguf` (384 dimensions) | 4 |
| vLLM | v0.31.0, image `vllm/vllm-openai:v0.31.0` | 3 |
| vLLM on CPU (optional) | the text names `vllm/vllm-openai-cpu:v0.31.0-arm64`; `vllm-cpu.yaml` uses `vllm/vllm-openai-cpu:v0.31.0` — see [`ERRATA.md`](ERRATA.md) | 3 |
| vLLM production-stack chart `vllm-stack` | 0.1.13 (`helm template` only) | 3 |
| LiteLLM | 1.104.2 — pip `litellm[proxy]==1.104.2`, image `ghcr.io/berriai/litellm:v1.104.2`, chart `oci://ghcr.io/berriai/litellm-helm` 1.104.2 | 4 |
| Open WebUI | 0.11.4 (`-slim` image), chart `open-webui/open-webui` 16.6.0 | 5 |

## Part B: Proxmox, OpenTofu, RKE2

| Component | Version | Day |
|---|---|---|
| Proxmox VE | 9.x; the book's output shows `pve-manager/9.1.4`, kernel `6.17.2-1-pve` | 0, 6 |
| VM template | Ubuntu 24.04 cloud image (`noble-server-cloudimg-amd64.img`) | 6 |
| Provider `bpg/proxmox` | `~> 0.116`; `tofu init` installs v0.116.0 | 6, 7 |
| RKE2 | `v1.36.4+rke2r1`, upgraded to `v1.36.5+rke2r1` | 8 |
| RKE2 (upgrade example) | `v1.36.6+rke2r1` | 15 |
| kube-vip | v1.2.4 | 8 |
| system-upgrade-controller | v0.20.2 | 8 |
| Cilium, Traefik | as shipped with RKE2 (`rke2-cilium`, `rke2-traefik`) | 8, 9 |
| cert-manager chart | v1.21.2 | 9, 15 |
| Longhorn chart | 1.13.0 | 9, 15 |
| local-path-provisioner | v0.0.37 | 9 |
| kube-prometheus-stack chart | 92.2.0 | 9 |

## Part C: GPU and models

| Component | Version | Day |
|---|---|---|
| NVIDIA driver in the guest | branch `580-server` (DRA needs ≥ 580); the book's output shows 580.95.05 | 10 |
| NVIDIA driver as container (alternative, `gpu-operator-driver-values.yaml`) | 595.91.07 | 10 |
| NVIDIA GPU Operator chart | v26.7.1 | 10 |
| CUDA test image | `nvcr.io/nvidia/cuda:13.0.2-base-ubuntu24.04` | 10 |
| DRA | `resource.k8s.io/v1` (GA since Kubernetes 1.34); experimental `GPUCluster` mode in Operator v26.7 | 10 |
| vLLM | v0.31.0, image `vllm/vllm-openai:v0.31.0` | 11, 13, 14 |
| vLLM (upgrade example) | v0.31.1 — the book says to check the tag on docs.vllm.ai | 15 |
| KEDA chart | 2.21.0 | 11 |
| Chat model | `Qwen/Qwen3-8B-FP8` as `qwen3-8b` (challenge: `Qwen/Qwen3-8B-AWQ`) | 11 |

## Part D: gateway, applications, operations

| Component | Version | Day |
|---|---|---|
| CloudNativePG chart | 0.29.1 | 12 |
| Redis | `redis:8.8-alpine` | 12 |
| LiteLLM chart | 1.104.2 (image tag `1.104.2`) | 12 |
| External Secrets Operator chart | 2.12.0, API `external-secrets.io/v1` | 12 |
| Fallback model | `mistral/mistral-small-latest` (Mistral API) | 12 |
| Embedding model | `BAAI/bge-m3` as `bge-m3` (1024 dimensions) | 13 |
| Qdrant chart | 1.19.2 | 13 |
| Open WebUI chart | 16.6.0 | 13 |
| Code model | `Qwen/Qwen2.5-Coder-7B-Instruct-AWQ` as `qwen2.5-coder-7b` | 14 |
| Tabby | the book's output shows v0.32.0 | 14 |
| Continue | `~/.continue/config.yaml`, `schema: v1` | 14 |
| Velero | 1.18, chart `vmware-tanzu/velero` 12.2.1 | 15 |
| Garage (S3 target) | `dxflrs/garage:v2.4.1` | 15 |

## Images the labs pull

| Image | Tag in the book | Day |
|---|---|---|
| `hashicorp/http-echo` | `1.0` | 1 |
| `busybox` | `1.37` | 1, 9 |
| `ghcr.io/ggml-org/llama.cpp` | `server-b11515` | 1, 2, 4 |
| `vllm/vllm-openai` | `v0.31.0` | 11, 13, 14 (Tag 3 only validates the manifest) |
| `ghcr.io/berriai/litellm` | `v1.104.2` | 4 |
| `ghcr.io/open-webui/open-webui` | `0.11.4-slim` | 5 |
| `traefik/whoami` | `v1.12` | 9 |
| `nvcr.io/nvidia/cuda` | `13.0.2-base-ubuntu24.04` | 10, 15 |
| `redis` | `8.8-alpine` | 12 |
| `curlimages/curl` | `8.16.0` | 14 |
| `dxflrs/garage` | `v2.4.1` | 15 |
| `rancher/rke2-upgrade` | no tag; the Plan's `version` selects it | 8 |

## How this was checked

No additional checks were run on these files for this repository. The
table lists what the book itself says, in its own words, about testing.

| Day | What the book says |
|---|---|
| Vorwort | Tested with kind 0.33, kubectl 1.37, Helm 4.3 and llama.cpp `server-b11515`. |
| 3 | The vLLM API on the GPU (Drill 4) and vLLM on the CPU (Drill 5) are "nicht live getestet". |
| 4 | Tested with LiteLLM v1.104.2. The embedding server and Postgres are "nicht live in kind getestet"; readiness, keys, budgets, rate limits, fallback and metrics were run "live gegen lokalen Proxy", the rollout in kind was not. |
| 5 | Open WebUI tested with 0.11.4; admin creation, smoke test, users, PersistentConfig and RAG were run with `pip install open-webui==0.11.4` / `open-webui serve`; install and pod restart in kind were not. |
| 6 | "Proxmox- und GPU-Befehle in diesem Kapitel sind gegen die offizielle Doku geprüft (pve.proxmox.com für PVE 9, registry.terraform.io/providers/bpg/proxmox v0.116), aber nicht live getestet." |
| 7 | The plan output was generated against a dummy endpoint; `apply` and the Ansible ping are not live-tested. |
| 8, 9 | Cluster outputs are marked "nicht live getestet". |
| 10 | "Ohne GPU auf dieser Maschine sind alle GPU-Ausgaben gegen die NVIDIA- und RKE2-Doku (GPU Operator v26.7.1, RKE2 v1.36) geprüft, aber nicht live getestet." Manifests and values validated with `helm template` + `kubeconform` and `kubectl apply --dry-run=server`, the Ansible role with `ansible-lint`. |
| 11 | vLLM logs, API answers and metrics checked against docs.vllm.ai (v0.31), not live-tested. Live-tested: sizing script, model metadata from Hugging Face, all manifests with `kubectl apply --dry-run=server`. |
| 12 | Live-tested: the complete `config.yaml` with LiteLLM 1.104.2 (pip venv) against Ollama on the laptop instead of vLLM and Mistral, including two proxy instances on one Redis, Postgres, teams, keys, fallback, guardrail and `/metrics`. Kubernetes parts validated with `helm template` + `kubeconform` and `kubectl apply --dry-run=server`; cluster output marked "nicht live getestet". |
| 13, 14 | Expected outputs are marked only "kann je nach Version abweichen"; the book states no test status. Tag 14, Drill 5 shows a laptop run against Ollama with `ministral-3:3b`; the challenge is "doc-geprüft". |
| 15 | Cluster outputs checked against the official documentation (docs.rke2.io, velero.io, docs.vllm.ai, docs.litellm.ai, longhorn.io, cloudnative-pg.io), not live-tested. Live-checked: dashboard generator, PromQL syntax of all rules, manifests with `kubeconform`, Velero chart with `helm template`, LiteLLM metric names and error texts in the v1.104.2 source. |
