# Kyverno & NetworkPolicies zum Anfassen — Companion Code

Working code for the labs in **Kyverno & NetworkPolicies zum Anfassen** by
Thomas Zachmann — a German-language, hands-on training camp for policy as
code and network segmentation in Kubernetes: fifteen days (Tag 0–14) and
two appendices. Everything runs in kind on the laptop, against one small
demo application that comes back in every chapter, across three clusters
that never run at the same time:

| Part | Days | Cluster |
|---|---|---|
| Gelände | 0 | `np-lab` |
| A – NetworkPolicies | 1–3 | `np-lab` (kindnet) |
| B – Cilium und Werkzeuge | 4–6 | `cilium-lab` (Cilium, Hubble) |
| C – Kyverno | 7–10 | `kyverno-lab` (Kyverno) |
| D – Betrieb | 11–14 | `kyverno-lab` (Tag 14, Drill 8 on `cilium-lab`) |

> **Status: free edition, October 2026.** The book states it was tested
> with kind 0.33 (Kubernetes 1.37), kubectl 1.37, Helm 4.3, Cilium 1.20,
> Kyverno 1.19.1 (chart 3.9.1), the Kyverno CLI 1.19.1 and Chainsaw 0.2.15.
> It is explicit about what was **not** run: on Tags 12, 13 and 14 every
> output that depends on a cluster is marked *nicht live getestet* — live
> checks there were `helm template`, `kubeconform` and the Kyverno CLI (on
> Tag 14 also the syntax of all files). On Tag 11 the cluster steps of
> Drill 6 and the Chainsaw test run are untested (the Chainsaw lint was
> run). Both GitLab pipelines (Tag 6, Tag 11) are checked statically only;
> the GitHub workflow of Tag 6 was checked with `actionlint`. Tag 0 was
> tested on a single node. Book: [PDF](https://github.com/thomaszachmann/books/releases/download/kyverno-networkpolicy-training-2026.10/Kyverno-NetworkPolicies-zum-Anfassen.pdf) · [EPUB](https://github.com/thomaszachmann/books/releases/download/kyverno-networkpolicy-training-2026.10/Kyverno-NetworkPolicies-zum-Anfassen.epub) (free, CC BY-NC-ND 4.0)

> **Auf Deutsch:** Dieses Verzeichnis enthält den Begleitcode zum Buch
> *Kyverno & NetworkPolicies zum Anfassen* — ein Trainingslager zum
> Mitmachen mit 15 Tagen (Tag 0–14) und zwei Anhängen: erst
> NetworkPolicies auf kindnet, dann Cilium mit L7, FQDN und Hubble, dann
> Kyverno von der ersten ValidatingPolicy bis zu signierten Images, am Ende
> Betrieb, GitOps und Desaster-Drills. Drei kind-Cluster, eine
> Demo-Anwendung. `code/demo`, `code/kyverno` und `code/kyverno-ops`
> kopierst du, wie das Buch es sagt, nach `~/guard-lab/code/`.
> `code/cilium` und `code/np-tests` tippst du an Tag 4–6 selbst; die
> Dateien hier sind zum Vergleichen. Die Cluster-Ausgaben von Tag 12–14
> sind laut Buch nicht live getestet. Schlüssel, Zertifikate und Berichte
> aus den Labs liegen hier nicht.

> **This repository is not a shortcut.** The book's first training rule is
> *Tippen, nicht kopieren* — every command once by hand. The book itself
> tells you to copy three directories (`demo`, `kyverno`, `kyverno-ops`);
> everything else here is what you type on Tags 4–6. Use it to check your
> work and to recover when something is broken.

---

## The lab lives in `~/guard-lab`, not here

Every path the book prints is under `~/guard-lab`: `code/` for the shared
code, `kind/` for the three cluster configs, and one working directory per
day (`tag01` … `tag14`, then `pruefung` for Anhang B). This directory
holds only the `code/` part:

| Here | Book day(s) | In the lab | How it gets there |
|---|---|---|---|
| `code/demo/` | Tag 0; used on every day and in both appendices | `~/guard-lab/code/demo/` | Tag 0, Drill 2: `cp -R` |
| `code/cilium/values-kind.yaml`, `api-l4.yaml`, `api-l7.yaml`, `client-fqdn.yaml`, `client-entities.yaml` | Tag 4 (`client-fqdn.yaml` again Tag 14, Drill 8) | `~/guard-lab/code/cilium/` | you type them (heredocs) |
| `code/cilium/scraper-l7.yaml` | Tag 4, Challenge | `~/guard-lab/code/cilium/` | *Lösung*: copy of `api-l7.yaml` plus an appended block |
| `code/cilium/ccnp-*.yaml`, `cnp-*.yaml`, `calico-gnp.yaml` | Tag 5 | `~/guard-lab/code/cilium/` | you type them (heredocs) |
| `code/np-tests/policies/`, `matrix.tsv`, `np-matrix.sh`, `probe.json` | Tag 6; `np-matrix.sh` again Tag 14 and Anhang B | `~/guard-lab/code/np-tests/` | you type them (heredocs) |
| `code/np-tests/ci/` | Tag 6, Drill 7 | `~/guard-lab/code/np-tests/ci/` | you type them; templates for your own repo |
| `code/np-tests/solution/50-db-no-egress.yaml` | Tag 6, Challenge | `~/guard-lab/code/np-tests/policies/` | *Lösung* — note the different directory |
| `code/kyverno/tag07/` | Tag 7 | `~/guard-lab/code/kyverno/tag07/`, files copied into `~/guard-lab/tag07` per drill | Tag 7, Drill 1: `cp -R` of `code/kyverno` |
| `code/kyverno/tag08/` | Tag 8; `image-hygiene.yaml` and `values.yaml` again Tag 11, 12, 14 | `~/guard-lab/code/kyverno/tag08/` → `~/guard-lab/tag08` | Tag 8, Drill 1: `cp …/tag08/*.yaml .` |
| `code/kyverno/tag09/` | Tag 9; `tenant-netpol.yaml` again Tag 13, 14 | `~/guard-lab/code/kyverno/tag09/` → `~/guard-lab/tag09` | Tag 9, Drill 1: `cp …/tag09/*.yaml .` |
| `code/kyverno/tag10/` | Tag 10; `setup-registry.sh` again Tag 14, Drill 0 | `~/guard-lab/code/kyverno/tag10/` → `~/guard-lab/tag10` | Tag 10, Drill 1: `cp …/tag10/*.sh .` |
| `code/kyverno-ops/tag11/` | Tag 11 | `~/guard-lab/code/kyverno-ops/tag11/`; `policy-repo/` → `~/guard-lab/tag11/policy-repo` | Tag 11, Drill 1: `cp -R` of `code/kyverno-ops` |
| `code/kyverno-ops/tag12/` | Tag 12; `values-ha.yaml` again Tag 14 (from `~/guard-lab/tag12`) | `~/guard-lab/tag12` | Tag 12, Drill 1: `cp -R …/tag12/. .` |
| `code/kyverno-ops/tag13/` | Tag 13; `policies/`, `tests/`, `tenant-d.yaml` again Tag 14; `gitops/tenants/tenant-d/` in Anhang B | `~/guard-lab/tag13` | Tag 13, Drill 1: `cp -R …/tag13/. .` |

The book clones this repository to `~/books` in Tag 0, Drill 2:

```bash
mkdir -p ~/guard-lab/{code,kind,tag01,tag02,tag03}
git clone https://github.com/thomaszachmann/books.git ~/books 2>/dev/null || git -C ~/books pull
cp -R ~/books/kyverno-networkpolicy-training/code/demo ~/guard-lab/code/
chmod +x ~/guard-lab/code/demo/conncheck.sh
```

Tag 7 and Tag 11 copy the other two directories the same way:

```bash
cp -R ~/books/kyverno-networkpolicy-training/code/kyverno ~/guard-lab/code/       # Tag 7, Drill 1
cp -R ~/books/kyverno-networkpolicy-training/code/kyverno-ops ~/guard-lab/code/   # Tag 11, Drill 1
``` If you
download a ZIP instead of cloning, check that the hidden files
`.github/workflows/policies.yaml` and `.gitlab-ci.yml` in
`kyverno-ops/tag11/policy-repo/` came along — Tag 11, Drill 1 counts 15
files.

---

## Requirements

Docker with **at least 6 GB of RAM** (Tag 0): every kind node is a
container; a node with the demo app needs about 1 GB, with Kyverno or
Cilium more like 2 GB. With little memory, delete the two `worker` lines
from the kind configs — the book says all drills of Part A run on a single
node, and Tag 7 says the same for `kyverno-lab`.

The book's commands are written on macOS: Tag 4 downloads the
`darwin-arm64` builds of `cilium` and `hubble`, Tag 6 uses the
`darwin_amd64` release of `policy-assistant` (via Rosetta on Apple
Silicon) and `pbcopy`, Tag 14 uses BSD `date -v` and names the Linux
variant.

| Tools | Needed from |
|---|---|
| `docker`, `kind`, `kubectl`, `helm` | Tag 0 |
| `cilium` CLI, `hubble` CLI | Tag 4 |
| `policy-assistant`; `go` (for `go run … actionlint`) | Tag 6 |
| `kyverno` CLI, `jq` | Tag 7 |
| `cosign` (v3), `crane`, `syft` | Tag 10 |
| `chainsaw`, `git` | Tag 11 |
| `yq`, `kubeconform` | Tag 12 |
| Argo CD (Helm chart; about 1 GB RAM and a Git repo the cluster can reach) | Tag 13 |

See [`VERSIONS.md`](VERSIONS.md) for the versions the book names.

---

## Versions

| Component | Version |
|---|---|
| kind / Kubernetes | 0.33 / 1.37 (`kindest/node:v1.37.0`) |
| Cilium (Helm chart) | 1.20.2 |
| Kyverno (Helm chart) | 3.9.1 (Kyverno v1.19.1) |
| Kyverno CLI | 1.19.1 |
| cosign | v3.1.3 |
| Chainsaw | 0.2.15 |

---

## Layout

```
README.md  VERSIONS.md  ERRATA.md
code/
  demo/         00-namespaces … 40-client.yaml, conncheck.sh        Tag 0
  cilium/       values-kind.yaml, api-l4/-l7, client-fqdn,
                client-entities, scraper-l7                          Tag 4
                ccnp-tenant-deny, ccnp-metadata-deny,
                cnp-tenant-deny, cnp-monitoring, cnp-pass-shop,
                cnp-baseline, cnp-metadata-deny, calico-gnp          Tag 5
  np-tests/     policies/10…40-*.yaml, matrix.tsv, np-matrix.sh,
                probe.json, ci/ (GitHub, GitLab, kind-ci.yaml),
                solution/50-db-no-egress.yaml                        Tag 6
  kyverno/
    tag07/      Helm values, require-app-label (+v2), test pods      Kyverno basics
    tag08/      pss-baseline/-restricted, require-labels (+v2),
                max-memory, image-hygiene (+ConfigMap), test pods    validate
    tag09/      pod-defaults, no-escalation, tenant-netpol,
                clone-monitoring, tpl-allow-monitoring, ns-c         mutate, generate
    tag10/      setup-registry.sh, make-ivpol.sh                     verifyImages
  kyverno-ops/
    tag11/      policy-repo/ (policies, exceptions, tests, e2e,
                ci, .github, .gitlab-ci.yml), challenge-deploy       testing, CI
    tag12/      values-ha, values-policy-reporter, soft-labels,
                no-privileged-vap, DeletingPolicies + RBAC,
                cleanup-test/                                        operations
    tag13/      policies/, tests/, tenant-d.yaml, gitops/ (Argo CD
                root, apps, tenants/tenant-d), two challenges        onboarding, GitOps
```

Days 1–3 and Tag 14 have no directory: their files are written in the
day's working folder (see *Left out on purpose*). The appendices
(Anhang A, cheat sheet; Anhang B, final exam) create no files here.

---

## How the files relate to the book

There are two kinds of directory:

- **Copied by the book** — `demo/`, `kyverno/`, `kyverno-ops/`. The book
  tells you to copy them (`cp -R ~/books/kyverno-networkpolicy-training/code/…`) and prints only
  excerpts (`sed -n`, `grep`). These files are the reference.
- **Typed in the book** — `cilium/` and `np-tests/`. Every file is the
  content of a heredoc in Tag 4, 5 or 6, which writes it straight into
  `~/guard-lab/code/cilium/` or `~/guard-lab/code/np-tests/`. Both
  directories were compared byte for byte against the manuscript. The only
  differences — one added comment line in twelve `cilium/` files, the
  composed `scraper-l7.yaml`, the `solution/` directory, and `matrix.tsv`
  in its state before the Tag 6 Challenge — are listed in
  [`ERRATA.md`](ERRATA.md).

Left out on purpose:

- `~/guard-lab/code/matrix.sh` — the Tag 0 Challenge. You write it; Tag 1
  starts with it and tells you to go back if it is missing.
- The three kind configs `np-lab.yaml`, `cilium-lab.yaml`,
  `kyverno-lab.yaml` — typed in Tag 0, Drill 3 into `~/guard-lab/kind/`.
- Everything written in a day's working folder: the NetworkPolicies of
  Tags 1–3, `open-tenant-a.yaml` (Tag 5), the Tag 14 files
  (`wettkampf.tsv`, `hit-guard.sh`, `egress-lockdown.yaml`, …) and the
  files of Anhang B in `~/guard-lab/pruefung`.
- Anything the labs generate: the registry certificate under `certs/`,
  the cosign key pairs, `offline.json`, the SBOM, `verify-shop-images.yaml`
  (Tag 10), JUnit reports (Tag 11), rendered Helm output and the dashboard
  JSON (Tag 12), Hubble flows (Tag 6). [`.gitignore`](.gitignore) keeps
  them out if you work in this directory.

---

## Running the scripts

- `demo/conncheck.sh <ns>/<pod|app> <url> [allow|deny]` — the book sets
  `alias cc=~/guard-lab/code/demo/conncheck.sh`. Exit 0 = allowed (or as
  expected), 1 = blocked (or deviation), 2 = usage error. `TIMEOUT=5`
  lengthens the 2 s wait.
- `np-tests/np-matrix.sh [--md] <matrix.tsv>` — runs `conncheck.sh` for
  every line; `CC=` points to another `conncheck.sh` (for example in a CI
  checkout).
- `kyverno/tag10/setup-registry.sh` — run from `~/guard-lab/tag10`; it
  creates `certs/` there, starts `kind-registry` with TLS and trusts it on
  every node of `kyverno-lab`. Tag 14 runs it again from the same folder.
- `kyverno/tag10/make-ivpol.sh cosign.pub > verify-shop-images.yaml` —
  embeds your public key in the ImageValidatingPolicy.
- `kyverno-ops/tag11/policy-repo/ci/kyverno-junit.sh` — run as
  `sh ci/kyverno-junit.sh` from the root of the policy repo; writes
  `reports/`.
- `kyverno-ops/tag13/gitops/argocd/` — `root.yaml` and the two apps point
  to `https://git.example.com/guard-lab/gitops.git`. As the book says on
  Tag 13, replace it with a repo your cluster can reach.

---

## Safety

Everything here is for a laptop and is **not** safe for production. The
book's sixth training rule: lab values stay in the lab — never use the
cosign keys of Tag 10 productively. Their password `lab-cosign-pw` is a
lab value. The policy built by `make-ivpol.sh` sets `insecureIgnoreTlog`
because the lab signs offline without Rekor; the book says that does not
belong in production. The registry certificate is self-signed.
`np-tests/ci/kind-ci.yaml` binds the API server to `0.0.0.0` — in the
book's words acceptable only in a throwaway CI job — and the GitLab jobs
need a privileged runner for `docker:dind`, which the book puts on a
dedicated runner, not a shared one. No private key, certificate or token
is committed; the labs create them in `~/guard-lab`.

---

## Licence

Code is MIT — see [`LICENSE`](../LICENSE). The text of the book is not
covered by that licence and is not included here; it is published under
CC BY-NC-ND 4.0.

Kubernetes, Kyverno, Cilium, Hubble and Argo CD are projects of the Cloud
Native Computing Foundation / Linux Foundation. Calico is a trademark of
Tigera, Inc. Docker is a trademark of Docker, Inc. This repository is an
independent publication and is not affiliated with, authorized by, or
endorsed by any of them.
