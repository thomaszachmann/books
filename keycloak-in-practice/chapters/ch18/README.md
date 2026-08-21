# Chapter 18 — Keycloak Authenticates Vault

Expects: Chapter 8's audience mapper, and Vault.

```bash
make vault-up
./chapters/ch18/setup.sh
```

## The audience, again

Both Vault roles set `bound_audiences=vault`. A token whose `aud` is
`account` — which is what Chapter 4 produced before the mapper — is
refused. That is Chapter 8's lab paying for itself in a different
system, and Vault's error message names the audience, which not every
consumer does.

## Two methods, one issuer

`oidc` runs the browser flow for humans. `jwt` validates a token the
caller already holds, for machines. Same discovery document, same keys,
same realm. Only the flow differs.
