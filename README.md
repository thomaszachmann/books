# Vault in Practice — Companion Code

Working code for every lab in **Vault in Practice: A Hands-On Lab Guide to
Secrets Management with HashiCorp Vault** by Thomas Zachmann.

> **This repository is not a shortcut.** The labs in the book are written to
> be typed. Typing is how the commands end up in your fingers instead of in
> your bookmarks. Use this repository to check your work, to recover when
> something is broken, and to skip the tedious parts — generating
> certificates, waiting for containers — not to skip the labs.

---

## Requirements

| Software | Version | Needed from |
|---|---|---|
| Docker Engine | 27.x | Chapter 1 |
| Docker Compose | v2.29+ | Chapter 2 |
| Vault CLI | 1.18.x | Chapter 1 |
| `jq` | any | Chapter 3 |
| `openssl` | any | Chapter 2 |
| `kind` | 0.24+ | Chapter 16 |
| `kubectl` | 1.30+ | Chapter 16 |

Check everything at once:

```bash
./scripts/check-prereqs.sh
```

---

## Quick start

```bash
git clone <this-repo> vault-lab
cd vault-lab

./scripts/check-prereqs.sh
make tls          # generate the self-signed certificate
make up           # start Vault
make init         # initialise, save keys to init.json
make unseal       # unseal using init.json
make env          # print the exports to paste into your shell
```

Then follow Chapter 2 onwards in the book.

**The book refers to this directory as `~/vault-lab`.** Clone it there, or
adjust the paths as you read — nothing depends on the location.

---

## Layout

```
lab/                 The environment. It evolves as the book does.
  docker-compose.yml Vault, plus PostgreSQL from Chapter 10
  config/vault.hcl   The configuration built in Chapter 2
  tls/               Certificate generation
scripts/             Helpers used across chapters
policies/            Every policy file the book writes, named by chapter
chapters/            Per-chapter lab scripts and configuration
```

Each `chapters/chNN/` directory has its own `README.md` stating what the
chapter builds and what state it expects to start from.

---

## The rule about state

Every chapter states its starting state. Most chapters continue from the
previous one. When you are lost, or when a chapter asks you to break
something and you want to move on:

```bash
make reset
```

This destroys all Vault data and starts again from an uninitialised server.
It asks for confirmation, because you will eventually run it by accident.

---

## Safety

Everything here is written for a laptop. It is **not** safe for production:

- TLS uses a self-signed certificate
- Unseal keys are written to `init.json` in plain text
- Passwords appear on the command line
- The lab binds to `127.0.0.1` only — keep it that way

`init.json`, `lab/data/`, `lab/logs/` and the certificates are in
`.gitignore`. If you fork this repository, check that they still are.

---

## Chapter index

| Chapter | Directory | Builds |
|---|---|---|
| 2 | `chapters/ch02` | The lab: TLS, config, Compose, reset |
| 3 | `chapters/ch03` | Initialise, unseal, rekey, rotate |
| 4 | `chapters/ch04` | CLI, API and status-code exercises |
| 5 | `chapters/ch05` | Token types, TTL ceilings, accessors |
| 6 | `chapters/ch06` | Policies, including the ones that fail |
| 7 | `chapters/ch07` | userpass and AppRole |
| 8 | `chapters/ch08` | Entities, aliases, groups |
| 9 | `chapters/ch09` | Key/value v1 and v2, versions, CAS |
| 10 | `chapters/ch10` | PostgreSQL and dynamic credentials |
| 11 | `chapters/ch11` | Lease lifecycle, including orphans |

Chapters 12 to 22 are added as the book is written.

---

## Licence

Code is MIT licensed — see `LICENSE`. The text of the book is not covered by
that licence and is not included here.

HashiCorp and Vault are trademarks of HashiCorp, Inc. This repository is an
independent publication and is not affiliated with, authorized by, or
endorsed by HashiCorp, Inc.
