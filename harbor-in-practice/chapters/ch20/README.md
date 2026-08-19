# Chapter 20 — Signing Keys That Never Leave Vault

**Starting state:** Chapter 19 finished, a Vault reachable.

```bash
./vault-signing.sh ref hashivault://harbor-signing
./vault-signing.sh env
./vault-signing.sh version 'vault:v2:MEUCIQD...'
```

## The key

```bash
vault secrets enable transit
vault write -f transit/keys/harbor-signing type=ecdsa-p256
vault policy write harbor-signing chapters/ch20/signing-policy.hcl
```

`exportable` is false by default and **cannot be changed afterwards**.
That immutability is the whole guarantee, and it is also why the
decision has to be right the first time.

## The reference

```
hashivault://harbor-signing        openbao://harbor-signing
```

Both schemes reach the same provider, so the licence question from Book
One does not change a single command here.

What follows the scheme is a **key name**: word characters, hyphens and
dots, **no slash**. The mount goes in `TRANSIT_SECRET_ENGINE_PATH`,
which defaults to `transit`. Putting the mount in the reference produces
an error about the reference rather than about the mount, which sends
people looking in the wrong place — `vault-signing.sh ref` says so
before cosign does.

| Variable | Default |
|---|---|
| `VAULT_ADDR` / `BAO_ADDR` | none, required |
| `VAULT_TOKEN` / `BAO_TOKEN` | falls back to a token helper |
| `TRANSIT_SECRET_ENGINE_PATH` | `transit` |

## Sign, verify, rotate

```bash
cosign public-key --key hashivault://harbor-signing > cosign-vault.pub
cosign sign --yes --key hashivault://harbor-signing \
  harbor.meridian.test/platform/vaultsigned:1.0
cosign verify --key cosign-vault.pub \
  harbor.meridian.test/platform/vaultsigned:1.0
```

Signatures carry the key version: `vault:v1:…`, then `vault:v2:…` after
`vault write -f transit/keys/harbor-signing/rotate`. Transit keeps the
earlier versions, so **rotating does not invalidate what you already
signed** — which is the reason key rotation is theoretical for most
people signing with files.

## What it protects

The key cannot be exfiltrated: not by a compromised build agent, not in
a backup, not by someone leaving. What it does not protect is the *use*
of the key — anyone who can call `sign` gets a real signature that
verifies. The question moves from *who has the key* to *who may ask it
to sign*, and that one has an answer: an auth method, the policy above,
and Vault's audit log.

Harbor sees none of it. Per Chapter 10 it does not check who signed, so
for an auditor the evidence is Vault's audit log joined to Harbor's
accessories on the digest.
