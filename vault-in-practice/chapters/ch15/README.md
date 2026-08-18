# Chapter 15 — Vault Agent

**Starting state:** Vault unsealed, root token exported.

**What this chapter builds:** a Vault Agent that authenticates on its own,
keeps its token alive, caches, and renders secrets into a file an
application reads without knowing Vault exists.

```bash
./setup-agent.sh
cd agent && vault agent -config=agent.hcl -log-level=info
```

Then in a second terminal:

```bash
cat agent/config.json
VAULT_ADDR=http://127.0.0.1:8007 VAULT_TOKEN= \
  vault kv get meridian/tracking
```

Token TTLs are deliberately one minute so renewal and re-authentication
happen while you are watching.
