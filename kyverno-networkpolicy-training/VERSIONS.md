# Versions

The versions *Kyverno & NetworkPolicies zum Anfassen* was written against,
as the book states them. Nothing here is pinned by a script except where a
file says so (Helm `--version`, image tags, CI action tags). The book's
advice when a flag differs: `<befehl> --help` and the official
documentation. Where the book only shows a version in an expected output,
the table says so.

## Kubernetes and base tools

| Component | Version | Day |
|---|---|---|
| kind | 0.33 (the book's output shows v0.33.0) | 0 |
| Kubernetes (kind node image) | 1.37 (`kindest/node:v1.37.0`) | 0, 4 |
| `kubectl` | 1.37 (the book's output shows v1.37.1) | 0 |
| Helm | 4.3 (the book's output shows v4.3.0) | 0 |
| Docker | the book's output shows 29.5.2; give it at least 6 GB RAM | 0 |
| kindnet image | the book's output shows `docker.io/kindest/kindnetd:v20260820-69b56db7` | 0 |

The book notes that kindnet has enforced NetworkPolicies itself
(`kube-network-policies`) since kind 0.24, and proves it in Tag 0, Drill 7.

## Network policy engines

| Component | Version | Day |
|---|---|---|
| Cilium Helm chart `cilium/cilium` | **1.20.2** (values file says "Cilium 1.20") | 4–6, 14 |
| `cilium` CLI | v0.20.1 | 4 |
| `hubble` CLI | v1.20.2 | 4 |
| network-policy-api (CRD `ClusterNetworkPolicy`, `v1alpha2`) | v0.2.0 (April 2026) | 5 |
| `kube-network-policies` (`install-cnp.yaml`) | v1.1.2 | 5 |
| kindnet image swapped in for Tag 5, Drill 4 (no policy engine) | `docker.io/kindest/kindnetd:v20230809-80a64d96` | 5 |
| `policy-assistant` | release `v0.0.1-policy-assistant` (amd64 only) | 6 |

Tag 5: since network-policy-api v0.2.0, AdminNetworkPolicy and
BaselineAdminNetworkPolicy are merged into `ClusterNetworkPolicy`
(`tier: Admin` or `Baseline`). Cilium does not implement the upstream API
(yet); `cilium/cnp-*.yaml` therefore run on `np-lab` with
`kube-network-policies`, `cilium/ccnp-*.yaml` on `cilium-lab`.

## Kyverno

| Component | Version | Day |
|---|---|---|
| Helm chart `kyverno/kyverno` | **3.9.1** (Kyverno v1.19.1) | 7–14 |
| Helm chart 3.9.0 (v1.19.0) | only for the upgrade comparison with `helm template` | 12 |
| Kyverno CLI | 1.19.1 | 0, 7–14, Anhang B |
| Chainsaw | 0.2.15 | 11 |
| Policy Reporter Helm chart | 3.11.0 (images `policy-reporter:3.11.0`, `kyverno-plugin:0.7.2`, `policy-reporter-ui:2.9.0`) | 12 |
| Argo CD Helm chart `argo/argo-cd` | 10.10.2 (`quay.io/argoproj/argocd:v3.5.4`, `redis:8.6.4-alpine`) | 13 |

The book uses the CEL-based policy types available since Kyverno 1.15
(`ValidatingPolicy`, `MutatingPolicy`, `GeneratingPolicy`,
`ImageValidatingPolicy`; on Tag 12 also `DeletingPolicy`) and notes that
`ClusterPolicy` is deprecated in 1.19.

## Supply chain (Tag 10)

| Tool | Version | Day |
|---|---|---|
| cosign | **v3** (the book's output shows v3.1.3) | 0, 10, 14 |
| `crane` | not stated | 10, 14 |
| `syft` | not stated; the SBOM is SPDX-2.3 | 10 |
| Registry image | `registry:2` (in `setup-registry.sh`) | 10, 14 |

Kyverno 1.19.1 did not find cosign v3 signatures on a plain-HTTP registry
in the author's test, even with `allowInsecure`; that is why
`setup-registry.sh` runs the lab registry with TLS (Tag 10, Drill 1).

## Images the labs pull

| Image | Tag in the book | Day |
|---|---|---|
| `nginxinc/nginx-unprivileged` | `1.31-alpine` (all demo servers) | 0– |
| `curlimages/curl` | `8.22.0` (test pods) | 0– |
| `registry` | `2` | 10 |
| kind node image | `kindest/node:v1.37.0` | 0 |

## CI templates

| File | Pins | Day |
|---|---|---|
| `np-tests/ci/github-np-tests.yaml` | `ubuntu-24.04`, `actions/checkout@v7`, `helm/kind-action@v1.15.1` with kind v0.33.0 | 6 |
| `np-tests/ci/gitlab-np-tests.yaml` | `docker:29.1`, `docker:29.1-dind`, kubectl v1.37.0, kind v0.33.0 | 6 |
| `kyverno-ops/tag11/policy-repo/.github/workflows/policies.yaml` | `actions/checkout@v7`, `kyverno/action-install-cli@v0.2.0`, `actions/upload-artifact@v7`, `helm/kind-action@v1.15.1`, `kyverno/action-install-chainsaw@v0.2.15` | 11 |

## What the book says was tested

| Scope | As stated in the book |
|---|---|
| Whole book | kind 0.33 (Kubernetes 1.37), kubectl 1.37, Helm 4.3, Kyverno CLI 1.19 (Vorwort); Kubernetes 1.37, Cilium 1.20, Kyverno 1.19.1 (chart 3.9.1), Kyverno CLI 1.19.1, Chainsaw 0.2.15 (Anhang A) |
| Tag 0 | tested single-node |
| Tag 6 | GitHub workflow checked with `actionlint`; GitLab job not tested live |
| Tag 11 | cluster steps of Drill 6 and the Chainsaw test run not tested live; Chainsaw lint tested live; GitLab pipeline only checked statically (YAML, download URLs) |
| Tag 12 | all cluster outputs not tested live; live: `helm template`, `kubeconform`, Kyverno CLI (chart 3.9.1, Kyverno 1.19.1) |
| Tag 13 | cluster outputs not tested live; live: Kyverno CLI 1.19.1, `helm template`, `kubeconform` |
| Tag 14 | all cluster outputs not tested live; live: Kyverno CLI 1.19.1 (Drill 3, 7, Challenge) and the syntax of all files |
| Anhang B | full-solution output of the exam script not tested live; A5 and A7 checked with the Kyverno CLI 1.19.1 |

For this repository, `code/cilium/` and `code/np-tests/` were compared byte
for byte against the heredocs in the manuscript (see
[`ERRATA.md`](ERRATA.md)). Nothing was run in a cluster for this README.
