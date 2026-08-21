# Keycloak in Practice — companion repository

Everything the book asks you to type, plus the scripts that check your
work. Book Three of the *In Practice* series.

```bash
cp .env.example .env
make check
```

`make check` tells you what is missing before a chapter does.

## What is here

| Path | What it is |
|---|---|
| `VERSIONS.md` | The only place a version number appears |
| `compose.yaml` | The lab: database, Keycloak, a client box, a directory |
| `Makefile` | Every target a chapter asks for; `make help` lists them |
| `chapters/chNN/` | Scripts and state for one chapter |
| `realms/` | Realm definitions, imported by `make realm` |

## Working through the book

Chapter 2 builds the certificates and the names. Nothing before it needs
this repository, and nothing after it works without it.

```bash
make pki          # chapter 2: the CA and the server certificate
make up           # chapter 3: postgres and keycloak
make kcadm-init   # chapter 3: a truststore for the admin CLI
make kcadm-login
make realm        # chapter 3: the meridian realm
```

The directory server is only needed from Chapter 12 and is behind a
profile, so it is not running for the ten chapters that do not use it:

```bash
make ad-up
make ad-down
```

## Resetting

Three levels, as Chapter 2 describes them:

```bash
make realm-reset  # delete the realm, import it again. Seconds.
make down         # containers away, data kept
make clean        # data too. Certificates survive.
make clean-pki    # the CA as well - four trust stores to redo
```

`pki/` is in `.gitignore`. A private key in a public repository is a
habit that starts in a lab.

## Versions

`VERSIONS.md` is read by the scripts; nothing hard-codes a version. CI
runs the labs weekly against the pinned versions and against the current
latest, and the difference becomes an entry in `ERRATA.md`.

## Licence

MIT. Use any of it anywhere.
