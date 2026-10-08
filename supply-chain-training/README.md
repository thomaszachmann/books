# Sichere Lieferketten zum Anfassen — Companion Code

Working code for the labs in **Sichere Lieferketten zum Anfassen** by
Thomas Zachmann — a German-language, hands-on training camp for software
supply-chain security: twelve chapters (0–11) and three appendices.

> **Status: free edition, October 2026.** The files below are extracted verbatim from the
> manuscript. They have been syntax-checked, but the labs have **not yet
> been run end-to-end in a fresh lab**. Book: [PDF](https://github.com/thomaszachmann/books/releases/download/supply-chain-training-2026.10/Sichere-Lieferketten-zum-Anfassen.pdf) · [EPUB](https://github.com/thomaszachmann/books/releases/download/supply-chain-training-2026.10/Sichere-Lieferketten-zum-Anfassen.epub) (free, CC BY-NC-ND 4.0)

> **Auf Deutsch:** Dieses Verzeichnis enthält den Begleitcode zum Buch
> *Sichere Lieferketten zum Anfassen* — ein Trainingslager zum Mitmachen
> mit zwölf Kapiteln (0–11) und drei Anhängen. Jede Datei stammt wörtlich
> aus einem Code-Block des Buchs. Das Buch ist ein früher Entwurf; die
> Labore sind noch nicht vollständig in einer frischen Umgebung
> durchgespielt. Alle Passwörter, Tokens und Schlüssel sind Laborwerte.

> **This repository is not a shortcut.** The labs are written to be typed —
> the book's first training rule is *Wer nicht tippt, trainiert nicht.*
> Use this to check your work and to recover when something is broken.

---

## The lab lives in `~/seclab`, not here

Unlike the other books in this repository, every path the book prints is
under `~/seclab` — `~/seclab/demo-app`, `~/seclab/kap04/bin/…`,
`~/seclab/pki/root/…`. This directory mirrors that layout chapter by
chapter, so you can compare or copy:

| Here | In the book |
|---|---|
| `chapters/chNN/…` | `~/seclab/kapNN/…` |
| `chapters/chNN/demo-app/…` | files the chapter writes into `~/seclab/demo-app/` |
| `chapters/ch00/demo-app/` | the demo app as Chapter 0 creates it |
| `chapters/ch05/pki/…` | `~/seclab/pki/…` |

```bash
git clone https://github.com/thomaszachmann/books.git
cd books/supply-chain-training
chapters/ch00/check-tools.sh
```

Then start with Chapter 0. It builds the lab: two registries as build and
target zone, a kind cluster that pulls from both, and the demo app running
in it. Every later chapter builds on that state.

---

## Requirements

macOS or Linux with Docker (Docker Desktop, Colima or Docker Engine), at
least 8 GB RAM for Docker — 16 GB recommended, because GitLab in Chapter 1
is hungry — and about 40 GB of free disk. Internet access for the
installation; later chapters simulate offline operation.

| Tools | Needed from |
|---|---|
| `docker`, `docker compose`, `kind`, `kubectl`, `helm` | Chapter 0 |
| `git`, `jq`, `yq` (mikefarah), `curl`, `openssl` (3.x) | Chapter 0 |
| `argocd` (GitLab runner runs as a container) | Chapter 1 |
| `trivy`, `checkov`, `semgrep`, `gitleaks` | Chapters 2, 8 |
| `skopeo`, `crane`, `oras` | Chapters 3, 4 |
| `cosign` | Chapter 5 |
| `vault` (or `bao`) | Chapter 6 |
| `syft`, `grype` | Chapter 7 |
| `kyverno`, `conftest`, `opa` | Chapter 9 |

`chapters/ch00/check-tools.sh` checks all of them. See
[`VERSIONS.md`](VERSIONS.md) for the versions the book expects, and for
the cosign v2/v3 differences.

---

## Layout

```
README.md  VERSIONS.md  ERRATA.md
chapters/
  ch00/  check-tools.sh, hosts.toml generator, kind.yaml,
         demo-app/ (app.py, requirements*.txt, tests/, Dockerfile,
         .dockerignore, .gitignore, k8s/)                     the lab
  ch01/  gitlab/compose.yaml, runner allow-list,
         demo-app/.gitlab-ci.yml + Jenkinsfile, Argo CD app    CI/CD
  ch02/  legacy/ and hardened/ Dockerfile + build scripts,
         inventar.yaml, bewertung.md                           build review
  ch03/  Nexus proxy JSON (docker, pypi, apt, npm), pip.conf,
         nexus.sources, demo-app/Dockerfile.mirror             mirrors
  ch04/  bin/quarantaene-pruefen.sh, freigeben.sh,
         importieren.sh                                        zone transfer
  ch05/  pki/root + pki/intermediate openssl configs,
         signer.cnf, provenance.json, Kyverno verifyImages     offline signing
  ch06/  Vault policy, SecretStore, ExternalSecret,
         gitleaks pre-commit hook + CI job                     secrets
  ch07/  Dependency-Track compose, Dockerfile.tools,
         SBOM CI jobs                                          SBOM
  ch08/  vulnerable app.py, .semgrep/ rules, .trivyignore,
         .trivyignore.yaml, .checkov.yaml, terraform/main.tf,
         security stage                                        scanners, triage
  ch09/  Kyverno policies + tests, Rego + tests,
         Gatekeeper template/constraint, policy-tools
         Dockerfile, policy CI job                             policy as code
  ch10/  PolicyException, meta-policy, exceptions.yaml,
         check scripts, CronJob, CODEOWNERS, templates         exceptions
  ch11/  demo-app/Dockerfile + full .gitlab-ci.yml,
         Vault policy/JWT role, target-zone policies           the whole chain
```

Each `chapters/chNN/README.md` lists its files with the book step they come
from and where they go under `~/seclab`. `uebung/` subdirectories hold the
files from an exercise's *Lösung*.

---

## How the files were made

Every file is the content of a code block in the manuscript, copied
programmatically, not retyped:

- A heredoc (`cat > file <<'EOF'`) became the finished file.
- A heredoc that expands a shell variable (`<<EOF` with `${HOME}`,
  `${GITLAB_IP}`, `${COMMIT}`, `${EXPIRES}`, `${CREATED}`) became
  `<name>.tmpl` with the variable left in place. Render it like the book
  does, by setting the variable first:
  `EXPIRES=… envsubst < exceptions.yaml.tmpl > exceptions.yaml`.
- Where the book generates a file from runtime input — a loop, a public
  key, command substitution — the block is kept as a script named
  `erzeuge-*.sh`. These three are the only files with added lines: a
  shebang and one comment naming the chapter and step.
- Fragments meant to be merged into a `.gitlab-ci.yml` are kept as
  `gitlab-ci-*.yml`; the runner allow-list as a TOML fragment.
- `chapters/ch08/demo-app/app.py` is Chapter 0's `app.py` with Chapter 8's
  `/ping` route inserted where the book says — above the `if __name__`
  block. It is **deliberately vulnerable**; Chapter 8 fixes it.

Nothing is invented. The book's corrections of 2026-10-08 are listed in
[`ERRATA.md`](ERRATA.md). The `demo-deploy` repository (Chapter 11,
Schritt 11) is created with `git` commands and has no file of its own here.

Left out on purpose:

- **Chapter 6's leak demo** (`leak-demo/config.py`, `replacements.txt`).
  It only works as a Git history you create yourself, and it contains
  token-shaped strings that secret scanners — including GitHub's push
  protection — would flag in this repository. Type it from the book.
- Concept-only snippets that are not part of a lab step (Flux, Harbor API,
  Maven `settings.xml`, NetworkPolicy example).
- Anything the labs generate: keys, certificates, lock files, bundles,
  SBOMs, reports. [`.gitignore`](.gitignore) keeps them out if you work in
  this directory.

`chapters/ch02/legacy/build-legacy.sh` is **not executable on purpose**.
It is the anti-pattern the chapter analyses (`curl | bash`, a password in
the script, a privileged Docker socket); the book says not to run it.

---

## Safety

Everything here is for a laptop and is **not** safe for production. All
passwords, tokens and keys in the book and in these files are lab values —
`lab-nexus-123`, `lab-root-pass`, `lab-cosign-pass`, `VAULT_TOKEN=root`,
`lab-postgres-pw`, `lab-token-123`, `Sommer2024!`. The book's fifth
training rule: *Lab-Werte bleiben im Lager.* No private key, no
`init.json` and no token is committed; the labs create them in `~/seclab`.

---

## Licence

Code is MIT — see [`LICENSE`](../LICENSE). The text of the book is not
covered by that licence and is not included here.

Kubernetes, Harbor and OpenBao are projects and trademarks of the Linux
Foundation. HashiCorp and Vault are trademarks of HashiCorp, Inc. GitLab is
a trademark of GitLab Inc. Docker is a trademark of Docker, Inc. Sonatype
Nexus is a trademark of Sonatype, Inc. This repository is an independent
publication and is not affiliated with, authorized by, or endorsed by any
of them.
