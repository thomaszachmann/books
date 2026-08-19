# Chapter 08 — Identity, Entities, and Groups

**Starting state:** Vault unsealed, root token exported. Needs `jq`.

**What this chapter builds:** one entity with two aliases on two different
auth mounts, and a group that carries a third policy.

```bash
./setup-identity.sh
```

Two `userpass` mounts (`login-a`, `login-b`) stand in for userpass and
OIDC. The mechanism is identical and this needs no identity provider. The
usernames differ on purpose — `alice` on one mount, `p.raghavan` on the
other — because that is what a real person looks like across two systems.

The script prints the entity ID and the commands that prove the point:
both logins produce the **same `entity_id`** and the **same three
policies**, despite different usernames on different mounts. Neither
policy is mentioned anywhere in the auth method configuration.

```bash
./revoke-drill.sh
```

Disables the entity, tries both logins, re-enables it. One flag closes
both doors. Note what it does not do: tokens already issued keep working
until they expire.

```bash
./templated-policy.sh
```

`{{identity.entity.name}}` in a policy path. The entity may write to its
own personal path and not to anyone else's — one policy, correct for
every entity, with no per-person maintenance.

Run `make reset` from the repository root to return to an uninitialised
Vault if you need a clean start.
