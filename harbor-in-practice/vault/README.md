# Vault, for Part VI

Harbor has no native Vault integration. No plugin, no secrets backend,
no configuration option. What it has instead is **hooks**: every secret
in the chart can be read from a Kubernetes secret you supply, and every
field in `harbor.yml` is rendered from a template before Harbor starts.

So the integration is external, and it is built entirely out of two
techniques: an agent that renders a file, and an operator that
materialises a secret.

| Chapter | What Vault does |
|---|---|
| 18 | renders `harbor.yml`; issues Harbor's TLS certificate; materialises the chart's secrets |
| 19 | holds robot tokens, delivered into namespaces as image pull secrets |
| 20 | holds the Cosign signing key, which never leaves Vault |

```bash
make vault-up                  # dev mode, in memory, root token 'root'
VAULT_PORT=8210 make vault-up  # if Book One's Vault holds 8200
make vault-down
```

`vault-up` starts the container and runs `bootstrap.sh`, which is
idempotent: it enables `pki` and `transit`, generates a root CA **only
if there is not one already**, creates the `harbor-signing` transit key
with `exportable=false`, writes the three policies below, and seeds two
placeholder secrets that Chapters 18 and 19 overwrite.

| Policy | Grants | Chapter |
|---|---|---|
| `harbor-secrets` | read `secret/data/harbor`, issue from `pki/harbor` | 18 |
| `harbor-pull` | read `secret/data/harbor-pull` | 19 |
| `harbor-signing` | `update` on `transit/sign/harbor-signing`, `read` on the key | 20 |

Note the `data/` in those kv paths. kv v2 splits the path — the value is
at `secret/data/harbor` even though you write it as `secret/harbor` — so
a policy granting `secret/harbor` grants nothing at all, silently.

That Vault exists so this part can run. It is not one you would keep,
and Book One is about the one you would.

## The cost, stated plainly

Before: Harbor starts if its disk is there.
After: Harbor starts if Vault is reachable, or if the last rendered file
is still on disk and still valid.

For a regulated environment that trade is obviously correct. For a
two-person team with no Vault it is obviously wrong, and the answer is a
password manager and a written procedure. Put the decision in the
architecture document from Chapter 17, next to the availability one.

## Nothing in Parts I to V needs any of this.
