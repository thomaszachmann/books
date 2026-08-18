# Chapter 13 — Running Your Own CA

**Starting state:** Vault unsealed, root token exported.

**What this chapter builds:** an offline root CA (with `openssl`), an
intermediate CA inside Vault, and a role that issues 24-hour certificates
for `meridian.internal`.

```bash
./setup-pki.sh
./scripts/renew-cert.sh api.meridian.internal
```

`root-ca/` is git-ignored. In production its private key would live on
encrypted removable media and never touch a networked machine — the whole
point of keeping the root offline.
