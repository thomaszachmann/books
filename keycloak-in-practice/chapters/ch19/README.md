# Chapter 19 — Vault Supplies Keycloak

Expects: Chapter 18. Vault running, Keycloak running.

```bash
./chapters/ch19/setup.sh
```

## The trap, in one sentence

Keycloak reads its database credential once, at start. A credential that
changes underneath it is not picked up. A rotated password fails late
and partially — pooled connections keep working, new ones fail. A
revoked dynamic user fails at once and totally — the open connections
lose their rights, and the log says `permission denied for table …`.

That is not a Keycloak defect. It is what every process that reads
configuration at boot does, and it is the reason dynamic credentials
need a consumer that can be told, or a restart that is part of the
rotation.

## Step 3, concretely

A shell variable beats `.env`, and `--no-deps` keeps the database as it
is:

```bash
CRED=$(vault read -format=json database/creds/keycloak-dynamic)
POSTGRES_USER=$(jq -r .data.username <<<"$CRED") \
POSTGRES_PASSWORD=$(jq -r .data.password <<<"$CRED") \
  docker compose up -d --no-deps keycloak
```

## Two users, on purpose

Vault's users are members of `keycloak`, the role that owns the tables
(otherwise: `permission denied for table databasechangelog`). The static
role owns `keycloak_app`, not `keycloak`: Vault rotates its password at
once, and `.env`'s password must keep working for Vault, `backup.sh`
and `rehearse.sh`.

## Undo

```bash
docker compose up -d --no-deps keycloak    # back to the .env credential
```
