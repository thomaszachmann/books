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
make vault-up     # development mode, in memory, known root token
```

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
