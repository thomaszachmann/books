# Books — companion code

Working code for the books by **Thomas Zachmann**.

Each directory is one book and is self-contained: clone the repository,
change into the book's directory, and everything the book prints resolves
from there.

| Book | Directory | Status |
|---|---|---|
| *Vault in Practice* | [`vault-in-practice/`](vault-in-practice/) | in progress |
| *Harbor in Practice* | [`harbor-in-practice/`](harbor-in-practice/) | in progress |

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
