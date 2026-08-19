# Chapter 23 — Upgrades and Version Skew

**Starting state:** Chapter 22 finished, with a backup that verifies.

```bash
./upgrade-check.sh schema            # where the database is
./upgrade-check.sh migrations        # every migration file, and 0 down
FROM=180 ./upgrade-check.sh pending v2.15.2
./upgrade-check.sh certs             # what helm upgrade replaces
./upgrade-check.sh rollback
```

## Forward only, and the files prove it

Thirty-seven `.up.sql` migrations and **zero** `.down.sql`. Core runs
them on start-up with golang-migrate; nothing runs them backwards. The
chart documentation puts it in one line: *"the `helm rollback` is not
supported"*.

`migrations` exits non-zero if a down migration ever appears — at which
point the chapter is stale and should be rewritten rather than trusted.

## Two migrations, one of which you run

| What | Who runs it | When |
|---|---|---|
| `harbor.yml` | you: `goharbor/prepare:<tag> migrate -i …` | before install |
| database schema | core, automatically | on start-up |

The config migrator reads the source version from `_version` **inside**
the file, and `-o` defaults to the input path — it overwrites
`harbor.yml` in place. Copy it first, and check `_version` matches what
is actually installed before you trust the result.

## Patch upgrades usually carry no schema change

There is no `2.15.1` or `2.15.2` migration file, so v2.15.0 → v2.15.2
finds nothing and core logs `No change in schema, skip.` But
`0171_2.14.1_schema.up.sql` exists — a patch *can* carry one. Run
`pending` instead of assuming.

## What `helm upgrade` replaces

```
tls.crt    REPLACED   regenerated on every upgrade
secretKey  same       taken from values, not generated
```

The chart calls `genCA`/`genSignedCert` with **no lookup** of the
existing Secret, so certificates are new on every render. Database and
Redis passwords and `core.secret` *are* looked up and reused. The
difference is not where you would guess, which is why `certs` renders
twice and reports rather than explains.

`secretKey` is the dangerous one: written straight from values, whose
default is `not-a-secure-key`. Upgrade from a values file that does not
carry the one you set and every credential encrypted with it — Chapter
22's list — is lost, with no error. Use `--reuse-values`, or
`existingSecretSecretKey` and Chapter 18.

## Replicas do not make it concurrent

golang-migrate takes `SELECT pg_advisory_lock(...)` first. One core
replica migrates; the rest block on the lock. Harbor's Helm document:
*"the downtime cannot be avoid"*.

## Rollback

There isn't one. `rollback` prints the only procedure that works: stop,
restore Chapter 22's backup, reinstall the old version against the
restored data.
