# Chapter 20 — The Cold Start

Expects: Chapters 18 and 19 — Vault running (`make vault-up`), both
`setup.sh` scripts run.

**Run this before the lab, not after:**

```bash
./chapters/ch20/breakglass.sh create
```

The chapter then produces a deadlock deliberately. The script above is
what ends it, and creating it afterwards is not possible — which is the
lesson, and the reason it is in the README rather than in step seven.

## Order

```bash
export VAULT_ADDR=http://localhost:8200 VAULT_TOKEN=root
./chapters/ch20/setup.sh                    # Step 2: the machine edge
make kcadm-init                             # the container was recreated
vault audit enable file file_path=/tmp/audit.log

# Step 4: the cold start
docker compose stop keycloak vault-agent db
vault operator seal
docker compose start db vault-agent keycloak
docker compose logs keycloak | grep kc-start    # "no database credential"
KEY=$(docker compose logs vault | grep 'Unseal Key' | awk '{print $NF}')
vault operator unseal "$KEY"                    # Keycloak follows by itself

# Steps 5 and 6: the deadlock, and the way out
kcadm update realms/meridian -s enabled=false
vault login -method=userpass username=breakglass
kcadm update realms/meridian -s enabled=true
```

## How Keycloak gets its credential now

| Piece | What it does |
|---|---|
| AppRole `keycloak`, policy `keycloak-db` | reads `database/static-creds/keycloak-static` and nothing else |
| `vault/approle/` | role id and secret id, mode 600, git-ignored |
| `vault-agent` (`agent.hcl`) | logs in as the machine, renders `/run/vault/db.env` |
| `kc-start.sh` | Keycloak's entrypoint: waits 30 s for that file, refuses to start without it |
| `compose.yaml` here | adds both to the stack; `setup.sh` puts it into `COMPOSE_FILE` in `.env` |

Vault runs in development mode, which keeps everything in memory:
**never stop it** during this chapter, or Chapters 18 to 20 are gone.
Seal it instead — to everything that depends on it, a sealed Vault is a
Vault that restarted.

## The distinction the chapter is built on

| Edge | Who uses it | Needs Keycloak? |
|---|---|---|
| Keycloak reads its DB credential from Vault | a process, at boot | no |
| An operator logs in to Vault to fix Keycloak | a human | yes |

The first edge is not a cycle. The second is. Most fear about this
arrangement is aimed at the first, and most outages come from the
second.

## Undo

Delete the `COMPOSE_FILE` line from `.env`, then:

```bash
docker compose up -d --no-deps keycloak     # back to .env's credential
docker compose rm -sf vault-agent
make kcadm-init
```
