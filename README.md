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

## Licence

Code in this repository is MIT licensed — see [`LICENSE`](LICENSE). The
text of the books is not covered by that licence and is not included here.

HashiCorp and Vault are trademarks of HashiCorp, Inc. OpenBao, Harbor and
Kubernetes are projects and trademarks of the Linux Foundation. Docker is a
trademark of Docker, Inc. This repository is an independent publication and
is not affiliated with, authorized by, or endorsed by any of them.
