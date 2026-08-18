# Vault, for Part VI

Harbor has no native Vault integration. No plugin, no secrets backend,
no configuration option. Anyone who says otherwise has not tried it.

What Part VI does instead, in three chapters:

| Chapter | What Vault does |
|---|---|
| 18 | Renders `harbor.yml` with Vault Agent; issues Harbor's TLS certificate from Vault PKI; materialises the chart's secrets with VSO and ESO |
| 19 | Holds Harbor robot account tokens, delivered into namespaces as image pull secrets |
| 20 | Holds the Cosign signing key in Transit, so it never leaves Vault |

Nothing in Parts I to V needs any of this. When you get here:

```bash
make vault-up
```

You do not need Book One. Where something from it matters, the chapter
says so and explains it.

Contents arrive with Chapter 18.
