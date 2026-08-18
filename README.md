# Books — companion code

Working code for the books by **Thomas Zachmann**.

Each directory is one book and is self-contained: clone the repository,
change into the book's directory, and everything the book prints resolves
from there.

| Book | Directory | Status |
|---|---|---|
| *Vault in Practice* | [`vault-in-practice/`](vault-in-practice/) | in progress |

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

## Licence

Code in this repository is MIT licensed — see [`LICENSE`](LICENSE). The
text of the books is not covered by that licence and is not included here.

HashiCorp and Vault are trademarks of HashiCorp, Inc. OpenBao is a project
of the Linux Foundation. This repository is an independent publication and
is not affiliated with, authorized by, or endorsed by either.
