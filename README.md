# Books — companion code

Working code for the books by **Thomas Zachmann**.

Each directory is one book and is self-contained: clone the repository,
change into the book's directory, and everything the book prints resolves
from there.

| Book | Directory | Status | Where to get it |
|---|---|---|---|
| *Vault in Practice* | [`vault-in-practice/`](vault-in-practice/) | **published** | [leanpub.com/vault-in-practice](https://leanpub.com/vault-in-practice) |
| *Harbor in Practice* | [`harbor-in-practice/`](harbor-in-practice/) | in progress | — |
| *Keycloak in Practice* | [`keycloak-in-practice/`](keycloak-in-practice/) | in progress | — |
| *Vault in Production* | [`vault-in-production/`](vault-in-production/) | early draft | — |
| *Kubernetes on-premises* | [`kubernetes-on-premises/`](kubernetes-on-premises/) | early draft | — |
| *Sichere Lieferketten zum Anfassen* (German) | [`supply-chain-training/`](supply-chain-training/) | early draft | — |
| *OpenBao zum Anfassen* (German) | [`openbao-training/`](openbao-training/) | early draft | — |

The *Status* column describes how far each **manuscript** has come, not the
code — the labs in a directory are usually complete well before the text
around them is.

This repository is what it says on the tin: companion code, written
alongside the text and kept runnable, but meant to be read *with* the book
rather than instead of it. Cloning it gets you working scripts and no
explanation of why any of them is shaped the way it is.

### Also by the same author

**[Enterprise AI Platform — Lab Guide](https://leanpub.com/enterprise-ai-platform)**
· GPU infrastructure, model serving and the operation of an AI platform
inside a company. 386 pages, 23 labs, with vLLM, KServe, LiteLLM, the NVIDIA
GPU Operator, Keycloak, OpenBao, ArgoCD and pgvector. Its Chapter 12 runs
OpenBao and Keycloak, its Chapter 16 runs Harbor — so the *in Practice*
books above are the deep dives to three of its chapters. That book carries
its labs in its own text and has no directory here.

A German edition of it is free:
[thomaszachmann.de/buch](https://thomaszachmann.de/buch).

**[Field Notes](https://github.com/thomaszachmann/field-notes)** · short,
free guides from a homelab, in German and English, with every command and
every error that happened along the way. The first series, *OpenBao Field Notes*: *OpenBao on Kubernetes*,
*Dynamic Database Credentials*, *OpenBao on a VM*, *Kubernetes Secrets with
ESO*, *Internal PKI with OpenBao*, *Raft Snapshots from the Cluster* and
*Keycloak and OpenBao* — the practical continuation of
Chapters 16–18 of *Vault in Practice*.

---

## Vault in Practice

**A Hands-On Lab Guide to HashiCorp Vault and OpenBao — with full coverage
of the Vault Associate exam objectives**

Twenty-four chapters, each ending in a lab that runs on a laptop in Docker.
No cloud account, no spare server. Kubernetes arrives in Chapter 16, in
both kind and minikube, and OpenBao in Chapter 18.

```bash
git clone https://github.com/thomaszachmann/books.git
cd books/vault-in-practice
./scripts/check-prereqs.sh
make tls && make up && make init && make unseal
```

See [`vault-in-practice/README.md`](vault-in-practice/README.md) for the
full instructions.

The book itself: **[leanpub.com/vault-in-practice](https://leanpub.com/vault-in-practice)**

---

## Harbor in Practice

**A Hands-On Lab Guide to Running a Private Container Registry on Virtual
Machines and Kubernetes**

Twenty-four chapters. Harbor is installed twice — once on a virtual
machine with the official installer, once on Kubernetes with the Helm
chart, in both kind and minikube — and one chapter, with no lab at all,
answers which of the two you should be running.

```bash
git clone https://github.com/thomaszachmann/books.git
cd books/harbor-in-practice
make check
make ch01
```

See [`harbor-in-practice/README.md`](harbor-in-practice/README.md) and
[`harbor-in-practice/VERSIONS.md`](harbor-in-practice/VERSIONS.md) for the
pinned versions.

---

## Sichere Lieferketten zum Anfassen

**Ein Trainingslager für sichere Software-Lieferketten — in German**

Twelve chapters and three appendices, all on a laptop: two local
registries as build and target zone, a kind cluster, GitLab, Nexus,
Vault, Dependency-Track, Kyverno and Argo CD — from the first pipeline to
offline signing, zone transfer, SBOMs, scanner triage, policy as code and
exceptions with an expiry date, joined into one chain in Chapter 11.

```bash
git clone https://github.com/thomaszachmann/books.git
cd books/supply-chain-training
chapters/ch00/check-tools.sh
```

Then start with Chapter 0. The book works in `~/seclab`; the directory
mirrors it chapter by chapter. See
[`supply-chain-training/README.md`](supply-chain-training/README.md).

---

## OpenBao zum Anfassen

**Ein Trainingslager für OpenBao — in German**

Fifteen days and two appendices. Days 1–6 run against a dev server on the
laptop — KV v2, tokens and policies, AppRole and response wrapping,
dynamic database secrets, transit, PKI, identity and audit. Days 7–14
build a three-pod HA cluster with Raft on kind and operate it: TLS from a
lab CA, auto-unseal, Kubernetes auth, External Secrets Operator, the agent
injector, snapshots, a rolling upgrade, governance and eight disaster
drills.

```bash
git clone https://github.com/thomaszachmann/books.git
cd books/openbao-training
```

Then start with Tag 0. The book works in `~/bao-lab`; the directory
mirrors it day by day. *Vault in Practice* introduces OpenBao in its
Chapter 18, and the *OpenBao Field Notes* cover single topics; this book
works through OpenBao alone, from the dev server to the operated cluster.
See [`openbao-training/README.md`](openbao-training/README.md).

---

## Licence

Code in this repository is MIT licensed — see [`LICENSE`](LICENSE). The
text of the books is not covered by that licence and is not included here.

HashiCorp and Vault are trademarks of HashiCorp, Inc. OpenBao, Harbor and
Kubernetes are projects and trademarks of the Linux Foundation. Docker is a
trademark of Docker, Inc. This repository is an independent publication and
is not affiliated with, authorized by, or endorsed by any of them.
