# Harbor in Practice — Companion Code

Working code for every lab in **Harbor in Practice** by Thomas Zachmann.

> **This repository is not a shortcut.** The labs are written to be typed.
> Typing is how commands end up in your fingers instead of your bookmarks.
> Use this to check your work, to recover when something is broken, and to
> skip the tedious parts — generating certificates, waiting for containers.

---

## This repository *is* the lab

```bash
git clone https://github.com/thomaszachmann/books.git
cd books/harbor-in-practice
make check
```

Every path printed in the book is relative to **this** directory.

---

## The book installs Harbor twice

That is the point of it, not an accident of structure.

| Part | Where Harbor runs | Chapters |
|---|---|---|
| I–IV | A virtual machine, official installer | 1–14 |
| V | Kubernetes, Helm chart, kind and minikube | 15–17 |
| VI | Either, with Vault beside it | 18–20 |
| VII | Both, under production conditions | 21–24 |

Chapter 17 has no lab. It answers which of the two you should be running
and why, and the short version is on the back cover.

---

## Quick start

Chapter 1 needs nothing but Docker:

```bash
make ch01
```

Chapters 2 and 3 build the virtual machine:

```bash
make vm-up            # Multipass, one command on any platform
# add the printed IP to your hosts file
make vm-shell
```

Chapter 15 moves to Kubernetes:

```bash
make kind-up          # or: make mk-up
```

---

## Apple silicon

`make vm-up` refuses, on purpose. Harbor's released images are amd64
only — a single manifest, not an index — so the arm64 machine Multipass
builds on an M-series Mac cannot run them, and qemu user-mode emulation
does not rescue it: Valkey segfaults under it. Colima with Rosetta does
work. The refusal prints the recipe; Appendix A has the long version.

`ALLOW_ARM64=1 make vm-up` overrides it if you want to watch it fail.

## Layout

```
VERSIONS.md      every pinned version, and why. Scripts read this file.
ERRATA.md        differences found after publication
Makefile         every lab target; 'make help' lists them
vm/              cloud-init and the harbor.yml template
k8s/             kind config, minikube notes, Helm values
vault/           Part VI. Empty until Chapter 18.
chapters/        one directory per chapter
scripts/         check-prereqs, install, diagnose, teardown, harbor-api
scripts/versions.sh
                 sourced by the rest; reads VERSIONS.md so that no
                 version is written down twice
```

Nothing hard-codes a version. `scripts/versions.sh` extracts the pins
from `VERSIONS.md` and every other script sources it, which is why
changing a version is one edit in one file:

```bash
. ./scripts/versions.sh
echo "$HARBOR_VERSION $HARBOR_CHART_VERSION"
```

---

## Versions

The book is written against **Harbor v2.15.2** and **chart v1.19.2**.
`VERSIONS.md` is the single source of truth; nothing hard-codes a version
anywhere else.

The CI runs the labs weekly against the pinned versions **and** against
the current latest. A failure against latest opens an issue rather than
turning this repository red, and the difference is written up in
`ERRATA.md`.

**One honest gap:** Multipass cannot run on GitHub Actions runners, which
have no nested virtualisation. CI runs the Harbor installer directly on
the runner instead, so the virtual machine path is tested but the virtual
machine itself is not.

---

## Harbor has no CLI

You will use `docker` or `podman` to push and pull, and the Harbor API
for everything else. `scripts/harbor-api.sh` is a thin wrapper over it,
and Appendix C is the cookbook.

```bash
HARBOR_PASS=... ./scripts/harbor-api.sh GET /projects | jq .
```

---

## Licence

MIT — see [`LICENSE`](../LICENSE). The text of the book is not covered by
that licence and is not included here.

Harbor and Kubernetes are trademarks of The Linux Foundation. Docker is a
trademark of Docker, Inc. HashiCorp and Vault are trademarks of
HashiCorp, Inc. This repository is an independent publication and is not
affiliated with, authorized by, or endorsed by any of them.
