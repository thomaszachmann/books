# Chapter 23 — Upgrades and Version Skew

Expects: a dump from Chapter 22.

```bash
./chapters/ch23/rehearse.sh backup/db-<stamp>.dump 26.5.2
```

## The rule

**The schema migration is one-way.** A newer Keycloak started against
the database migrates it, and there is no downgrade. So the rollback
plan is not "start the old version again" — it is a database restore,
which means the rollback is as long as Chapter 22's restore and needs
the same credential from Chapter 20.

Rehearse against a copy. The number you want is the migration window,
and it is a property of your data, not of the release notes.

## Order, when the operator is involved

1. the two CRDs
2. the operator
3. the Keycloak version in the resource

Backwards produces a controller that cannot read fields it expects, and
the error names a schema rather than a version.
