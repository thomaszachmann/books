# Pinned versions

Every lab in *Keycloak in Practice* runs against these versions. They are
pinned in one place so that the book, the scripts and the CI cannot drift
apart. Scripts read this file directly:

```bash
eval "$(grep -E '^[A-Z_]+=' VERSIONS.md)"
```

Anything assigned at the start of a line below is the source of truth.

```sh
KEYCLOAK_VERSION=26.5.2
POSTGRES_VERSION=17
UBUNTU_SERIES=24.04
KC_REALM=meridian
KC_HOSTNAME=https://sso.meridian.test
AD_REALM=MERIDIAN.TEST
AD_DOMAIN=MERIDIAN
VAULT_VERSION=1.20.4
```

## Why these

**Keycloak 26.5.2.** Pinned to a patch release rather than a minor,
because the book prints expected output and a minor release changes it.
Three things in this book are specific to 26.x and would be wrong on
older releases: `KC_BOOTSTRAP_ADMIN_USERNAME` and its password variable
(before 26 these were `KEYCLOAK_ADMIN` and `KEYCLOAK_ADMIN_PASSWORD`),
the hostname option taking a full URL rather than a host, and health and
metrics living on the management port. Chapter 3 says all three out loud
for exactly this reason.

**PostgreSQL 17**, pinned to the major only. Keycloak's schema
migrations are the thing under test in Chapter 23, not Postgres's patch
level, and pinning a patch here would mean a repository commit every few
weeks for no reading benefit.

**Ubuntu 24.04** is the base for the directory server image. It is not a
community Samba image, and that is deliberate — see below.

## The directory server is built, not pulled

Chapters 12 to 14 need an Active Directory. Community Samba domain
controller images exist, and most of them publish `linux/amd64` only,
which makes them unusable on Apple silicon without emulation.

So this repository builds one, from Ubuntu, with `samba-ad-dc` from the
distribution. Ubuntu publishes `arm64` and `amd64`, Samba is a package
rather than a binary somebody cross-compiled, and the result runs
natively on every machine the book targets. It costs a two-minute build
on first use and removes an entire class of "works on my laptop".

The version of Samba is therefore whatever Ubuntu 24.04 ships. That is
the correct choice here: the book teaches the LDAP and Kerberos
integration, not Samba's release notes, and Ubuntu's package is the
version a reader would meet on a real Samba host.

**Samba is not Active Directory.** Where the two differ, the book says
so in an *On real AD* box rather than pretending otherwise.

**Vault 1.20.4** arrives in Part V and is pinned here now that it does.
Parts I to IV do not start it; `make vault-up` does, and the container
runs in development mode, which is the one place this book uses a
development mode deliberately. Book One of this series is about why you
would not do that with real secrets.

## Not pinned here

**kind and minikube** are pinned in `k8s/VERSIONS.md` when Part IV
arrives, as in the two previous books.

## When these go stale

The CI runs the labs weekly against **both** the versions above and the
current latest. A failure against latest opens an issue; it does not turn
this repository red, because the book is written against the pin.

Differences found after publication are recorded in `ERRATA.md`.
