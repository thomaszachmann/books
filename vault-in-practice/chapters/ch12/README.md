# Chapter 12 — Encryption as a Service

**Starting state:** Vault unsealed, root token exported.

**What this chapter builds:** the transit engine with a key named
`orders`, plus a policy that permits `rewrap` without `decrypt`.

```bash
./setup-transit.sh
```

The point of the chapter is the `rewrap-only` policy: a migration job that
upgrades every record to a new key version and can read none of them.
