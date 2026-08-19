# Chapter 22 — Backup, Restore, and Disaster Recovery

**Starting state:** the VM from Chapter 3, Harbor running.

```bash
./backup.sh plan
./backup.sh quiesce
./backup.sh run /backup/today
./backup.sh verify /backup/today      # offline; this is what CI runs
./restore.sh /backup/today
./restore.sh check
./backup.sh unquiesce
```

## Four stores, three that matter

| Store | Location | Lose it and |
|---|---|---|
| Postgres | `/data/database` | everything |
| Blobs | `/data/registry` or the bucket | Harbor lists what nobody can pull |
| **Secret key** | `/data/secret/keys/secretkey` | Harbor starts; some credentials never decrypt |
| Redis | `/data/redis` | sessions end, tasks hang; nothing is lost |

The key is a **file**, mounted to `/etc/core/key`, and it encrypts
values that live in the database: replication endpoint credentials,
proxy cache upstreams, the LDAP bind password, the OIDC client secret
and every OIDC user's token. User passwords and robot secrets are
*hashed*, not encrypted, which is why login and pulls keep working and
replication does not. That combination is what makes the failure hard to
diagnose.

## The order

**Database first, then blobs.** Derive it rather than remember it:

| Order | The gap between the two snapshots holds | Result |
|---|---|---|
| blobs → database | database rows whose blobs are missing | broken artifacts |
| database → blobs | blobs with no database row | orphans; the next GC removes them |

`backup.sh run --order blobs-first` refuses unless you set
`FORCE_WRONG_ORDER=1`, which the chapter does once, on purpose.

## Read-only is necessary and not sufficient

`read_only: true` rejects every method that is not GET, HEAD or OPTIONS
— with a skip list. On that list: `PUT /api/v2.0/configurations` (so you
can switch it off again), login, and **job callbacks**. Which means a
scheduled or running garbage collection keeps going, and GC deletes
blobs. `backup.sh quiesce` sets read-only *and* checks that the GC
schedule is `None` and no execution is in flight, and exits non-zero if
either is not true.

## verify

Offline, against a backup directory. Checks the four files exist, that
`secret.tar` actually contains `secret/keys/secretkey`, and that the
manifest's timestamps put the database before the blobs:

```
FAIL  order: the database finished at 2026-08-19T10:05:00Z, after the blobs started
      at 2026-08-19T10:00:00Z - the database may reference missing blobs
FAIL  secretkey missing - replication, proxy cache, LDAP and OIDC
      credentials will not decrypt after a restore
```

`restore.sh` runs `verify` first and refuses a backup that fails it. A
backup you have not verified is a hypothesis.

## What the official documents do not cover

- The website's Velero procedure is Kubernetes-only, and states its own
  limitation: *"Backups of external databases are not supported."*
  Chapter 21 tells you to move Postgres out; at that moment the database
  backup becomes another team's procedure.
- The upgrade guide's backup step is `cp -r /data/database`. That is
  correct for a rollback on the same machine and is not a disaster
  recovery procedure — it contains neither the blobs nor the key.
- Neither mentions disabling garbage collection.
