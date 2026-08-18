# Vault in Practice — Companion Code

Working code for every lab in **Vault in Practice** by Thomas Zachmann.

> **This repository is not a shortcut.** The labs are written to be typed.
> Typing is how commands end up in your fingers instead of your bookmarks.
> Use this to check your work, to recover when something is broken, and to
> skip the tedious parts — generating certificates, waiting for containers.

---

## This repository *is* the lab

Clone it to the path the book uses and work inside it:

```bash
git clone https://github.com/thomaszachmann/books.git
cd books/vault-in-practice
```

Every path printed in the book — `config/vault.hcl`, `tls/vault-cert.pem`,
`init.json` — is relative to **this** directory. The book calls it
`~/vault-lab`; if you prefer that literally, symlink it:

```bash
ln -s "$(pwd)" ~/vault-lab
```

---

## Quick start

```bash
./scripts/check-prereqs.sh
make tls          # generate the self-signed certificate
make up           # start Vault
make init         # initialise, writes init.json
make unseal       # unseal from init.json
make env          # print the exports to paste into your shell
```

Then follow Chapter 2.

---

## Layout — chapter first

```
chapters/
  ch02/  README + setup.sh            build the lab
  ch03/  README                       initialise, unseal, rekey
  ch04/  README                       CLI, API, status codes
  ch05/  README                       tokens
  ch06/  README + policies/*.hcl      policies, including a broken one
  ch07/  README                       userpass and AppRole
  ch08/  README                       entities, aliases, groups
  ch09/  README + policies/*.hcl      key/value v1 and v2
  ch10/  README + setup-database.sh   PostgreSQL, dynamic credentials
  ch11/  README                       lease lifecycle
  ch12/  setup-transit.sh + policies  encryption as a service
  ch13/  setup-pki.sh + renew-cert    your own certificate authority
  ch14/  deliver/consume scripts      wrapped SecretID delivery
  ch15/  setup-agent.sh + agent/      Vault Agent, templating, cache
  ch16/  cluster-up.sh + manifests   kind and minikube, kubernetes auth

docker-compose.yml   the environment; grows as the book does
config/vault.hcl     the configuration built in Chapter 2
tls/                 certificate generation
scripts/             shared helpers
data/  logs/         runtime state, git-ignored
```

Each `chapters/chNN/README.md` states the state that chapter expects to
start from and what it leaves behind. Read it before the chapter if you are
jumping in, and ignore it if you are working straight through.

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
| `minikube` | 1.34+ | Chapter 16 |
| `kubectl` | 1.30+ | Chapter 16 |
| `helm` | 3.15+ | Chapter 16 |

```bash
./scripts/check-prereqs.sh
```

---

## The services

| Service | Port | From |
|---|---|---|
| `vault` | 8200 | Chapter 2 |
| `postgres` | 5432 | Chapter 10 |
| `openbao` | 8300 | Chapter 18 |

Start them individually — the book brings each one in when it is needed:

```bash
docker compose up -d vault
docker compose up -d postgres
docker compose up -d openbao
```

---

## When you are lost

```bash
make reset
```

Destroys all Vault data and returns to an uninitialised server. It asks for
confirmation, because you will eventually run it by accident.

---

## Safety

This is written for a laptop and is **not** safe for production. TLS uses a
self-signed certificate, unseal keys land in `init.json` in plain text,
passwords appear on the command line, and everything binds to `127.0.0.1`.
Keep it that way.

`init.json`, `data/`, `logs/` and the certificates are git-ignored. If you
fork this, check that they still are.

---

## Licence

Code is MIT — see `LICENSE`. The text of the book is not covered by it and
is not included here.

HashiCorp and Vault are trademarks of HashiCorp, Inc. OpenBao is a project
of the Linux Foundation. This repository is an independent publication and
is not affiliated with, authorized by, or endorsed by either.
