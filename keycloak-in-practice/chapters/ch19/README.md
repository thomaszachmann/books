# Chapter 19 — Vault Supplies Keycloak

Expects: Chapter 18. Vault running, Keycloak running.

```bash
./chapters/ch19/setup.sh
```

## The trap, in one sentence

Keycloak reads its database credential once, at start. A credential that
rotates is not picked up, and the failure is delayed and partial —
existing pooled connections keep working while new ones fail.

That is not a Keycloak defect. It is what every process that reads
configuration at boot does, and it is the reason dynamic credentials
need a consumer that can be told, or a restart that is part of the
rotation.

## Undo

```bash
docker compose exec -T vault vault lease revoke -prefix database/creds/
```

Then put the original credential back in `.env` and restart Keycloak.
