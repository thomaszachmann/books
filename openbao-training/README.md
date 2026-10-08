# OpenBao zum Anfassen — Companion Code

Working code for the labs in **OpenBao zum Anfassen** by Thomas Zachmann —
a German-language, hands-on training camp for OpenBao: fifteen days
(Tag 0–14) and two appendices. Days 1–6 run against a dev server on the
laptop; days 7–14 build and operate a three-pod HA cluster with integrated
Raft storage on kind, and end with eight disaster drills.

> **Status: free edition, October 2026.** The files below are extracted verbatim from the
> manuscript. The dev-mode days (1–6) were tested with `bao` 2.7.1. The
> Kubernetes days (7–14) were rendered with `helm template` and checked
> against a local Raft rebuild with `bao` 2.7.1 — they have **not** been
> run end-to-end in a cluster. Book: [PDF](https://github.com/thomaszachmann/books/releases/download/openbao-training-2026.10/OpenBao-zum-Anfassen.pdf) · [EPUB](https://github.com/thomaszachmann/books/releases/download/openbao-training-2026.10/OpenBao-zum-Anfassen.epub) (free, CC BY-NC-ND 4.0)

> **Auf Deutsch:** Dieses Verzeichnis enthält den Begleitcode zum Buch
> *OpenBao zum Anfassen* — ein Trainingslager zum Mitmachen mit 15 Tagen
> (Tag 0–14) und zwei Anhängen: erst der Dev-Modus auf dem Laptop, dann ein
> hochverfügbarer Raft-Cluster mit drei Pods auf kind, am Ende
> Desaster-Drills. Jede Datei stammt wörtlich aus einem Code-Block des
> Buchs. Das Buch ist ein früher Entwurf; die Kubernetes-Tage sind noch
> nicht in einem echten Cluster durchgespielt. Alle Passwörter sind
> Laborwerte; Schlüssel, Tokens und `init.json` liegen hier nicht.

> **This repository is not a shortcut.** The book's principle is *so wenig
> Text wie möglich, so viel Hands-on wie nötig* — the drills are written to
> be typed. Use this to check your work and to recover when something is
> broken.

---

## The lab lives in `~/bao-lab`, not here

Every path the book prints is under `~/bao-lab`: one directory per day of
Part A (`tag01` … `tag06`), then `k8s/` and `tls/` for the cluster, and
`tag11` … `tag14` for the later days. This directory mirrors it day by day:

| Here | In the book |
|---|---|
| `chapters/dayNN/…` | `~/bao-lab/tagNN/…` |
| `chapters/day07/kind.yaml`, `day08/values.yaml`, `day10/*.yaml`, `day10/autounseal.hcl` | `~/bao-lab/k8s/…` |
| `chapters/day07/openbao.ext`, `erzeuge-*.sh` | `~/bao-lab/tls/…` |
| `chapters/dayNN/check.sh` | the day's *Kontrollpunkt* |
| `chapters/dayNN/challenge/…` | the day's *Challenge*, *Lösung* |

Each `chapters/dayNN/README.md` lists its files with the drill they come
from and where they go.

```bash
git clone https://github.com/thomaszachmann/books.git
cd books/openbao-training
```

Then start with Tag 0 in the book. It installs the tools and creates
`~/bao-lab`; `source chapters/day00/check.sh` in your shell confirms it.

---

## Requirements

macOS or Linux. Part A (Tag 1–6) needs only `bao`, `curl` and `jq` — plus
Docker for the Postgres container on Tag 4. Part B (Tag 7–14) needs Docker
with enough memory for a kind cluster of one control plane and three
workers.

| Tools | Needed from |
|---|---|
| `bao` (OpenBao CLI), `curl`, `jq` | Tag 0 |
| `docker` | Tag 4 (Postgres), Tag 7 (kind) |
| `kind`, `kubectl`, `helm` (v3 or v4) | Tag 7 |
| `openssl` **3.x** — not the LibreSSL in macOS; Tag 0 installs it | Tag 7, Tag 14 |
| `tofu` (OpenTofu) | Tag 13 |

See [`VERSIONS.md`](VERSIONS.md) for the versions the book was written
against.

---

## Versions

| Component | Version |
|---|---|
| `bao` CLI | 2.7.1 |
| Cluster image `quay.io/openbao/openbao` | 2.7.0, upgraded to 2.7.1 on Tag 12 |
| Helm chart `openbao/openbao` | 0.30.2 (app version v2.7.1) |

The dev-mode days were tested with `bao` 2.7.1. The cluster deliberately
starts on 2.7.0 so that Tag 12 has a real rolling upgrade to do.

---

## Layout

```
README.md  VERSIONS.md  ERRATA.md
chapters/
  day00/  shell helpers for ~/.zshrc, baoup                    the lab
  day01/  check only (CLI and curl)                            dev server, KV v2
  day02/  webshop-read, token-creator, apps-config,
          shop-writer, webshop-ops policies                    tokens, policies
  day03/  webshop-deployer policy                              userpass, AppRole
  day04/  webshop-ro.sql, webshop-db policy                    database secrets
  day05/  webshop-encrypt policy                               transit, PKI
  day06/  audit.hcl, second audit device, two policies         identity, audit
  day07/  kind.yaml, openbao.ext, lab CA + server cert         kind, TLS
  day08/  values.yaml (HA, Raft, TLS, 2.7.0)                   Helm install
  day09/  check only                                           init, unseal
  day10/  unsealer-values.yaml, autounseal.hcl,
          values.yaml with transit seal                        auto-unseal
  day11/  eso.yaml, agent-pod.yaml, webshop-read policy,
          values.yaml with injector                            workloads
  day12/  values.yaml with audit + telemetry,
          values-2.7.1.yaml, roll.sh, cronjob.yaml,
          snapshot policy                                      operations
  day13/  bao-admin, break-glass, shop-dev policies,
          tofu/main.tf, selfinit/config.hcl                    governance
  day14/  vorbereitung.sh, wettkampf policy,
          szenario-1 … szenario-8/                             disaster drills
```

The appendices (Anhang A, cheat sheet; Anhang B, final exam) create no
files and have no directory.

---

## How the files were made

Every file is the content of a code block in the manuscript, copied
programmatically, not retyped:

- A heredoc (`cat > file <<'EOF'`) became the finished file. A policy
  piped into `bao policy write <name> - <<'EOF'` became `<name>.hcl`.
- A heredoc that expands a shell variable (`<<EOF` with `$HOME` or `$PWD`)
  became `<name>.tmpl` with the variable left in place. Render it like the
  book does: `envsubst < audit.hcl.tmpl > ~/bao-lab/tag06/audit.hcl`.
- A *Kontrollpunkt* became `check.sh`; the two lab-CA blocks of Tag 7
  became `erzeuge-*.sh`; each block of Tag 14 became one script per step.
  Where the block has no shebang, these files have two added lines: a
  shebang and one comment naming the day and the step.
- Heredocs appended with `>>` are kept as fragments
  (`day06/audit-stdout.hcl`, `day13/challenge/main.tf.append`,
  `day00/lab-helfer.zsh`). `day00/challenge/baoup.zsh` is a shell
  function to `source`, not a script.

**Composed files.** The book edits `~/bao-lab/k8s/values.yaml` in place on
Tags 10, 11 and 12 and prints only the snippets. The `values.yaml` of
those days is the previous day's file with the book's snippets inserted
where the text says — nothing else changed. `day12/values-2.7.1.yaml` is
the same file after Drill 10's tag change. Each day's README names the
insertion points.

Nothing is invented. Inconsistencies found while extracting are listed in
[`ERRATA.md`](ERRATA.md); the code follows the book anyway.

Left out on purpose:

- Anything the labs generate: `init.json`, `unsealer-init.json`,
  `unseal-token.json`, `recovery-neu.json`, `gr.json`, `creds.json`,
  `cert.json`, keys, certificates, snapshots, OpenTofu state.
  [`.gitignore`](.gitignore) keeps them out if you work in this directory.
- Resources the book creates imperatively with `kubectl create`
  (namespaces, the ServiceAccount `webshop`, the secrets `openbao-tls`,
  `openbao-ca`, `openbao-unseal-token`) and the PVC `openbao-backup`,
  which the book asks you to create without printing a manifest.

---

## Running the scripts

- `check.sh`: `bash chapters/dayNN/check.sh` against that day's lab, with
  `BAO_ADDR`, `BAO_TOKEN` (and from Tag 7 on `BAO_CACERT`) exported.
  Exception: `day00/check.sh` must be **sourced** — it checks the shell
  function `labenv`.
- `day14/…`: **source** the files in order, in one shell. Later steps use
  variables set by earlier ones, exactly as when you type them.

---

## Safety

Everything here is for a laptop and is **not** safe for production. All
passwords in the book and in these files are lab values — `lab-pg-pw`,
`lab-alt-pw`, `lab-pw-thomas`, `lab-admin-pw`, `lab-bg-pw`, `lab-shop-pw`, `lab-wk-pw`,
and the dev root token `root`. The cluster from Tag 8 on runs with TLS
from a lab CA; the unsealer of Tag 10 does not (`tls_disable = 1`, marked
*Lab!* in the file). No private key, no `init.json` and no token is committed; the labs
create them in `~/bao-lab`.

---

## Licence

Code is MIT — see [`LICENSE`](../LICENSE). The text of the book is not
covered by that licence and is not included here.

OpenBao and Kubernetes are projects and trademarks of the Linux
Foundation. HashiCorp and Vault are trademarks of HashiCorp, Inc. Docker
is a trademark of Docker, Inc. OpenTofu is a project of the Linux
Foundation. This repository is an independent publication and is not
affiliated with, authorized by, or endorsed by any of them.
