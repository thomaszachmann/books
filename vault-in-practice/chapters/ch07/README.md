# Chapter 07 — Authentication Methods

**Starting state:** Vault unsealed, root token exported

**What this chapter builds:** userpass on two mounts, a user on each, and
an AppRole whose SecretID is good for exactly two logins.

```bash
./setup-auth.sh
```

The script also writes the `tracking-read` policy and seeds
`meridian/tracking`, so it works on a Vault that has not seen Chapter 6.

Three things are worth doing by hand afterwards; `setup-auth.sh` prints
them. The second is the one that teaches something: logging in as `sam`
without `-path=contractors` fails, and the useful information is in the
**URL of the error**, not its message. Vault went to
`auth/userpass/login/sam` because `-method=userpass` implies the default
mount.

```bash
./burn-secret-id.sh
```

Logs in three times with one SecretID. The third is refused — and the
token from the first login is still valid for its full hour. Exhausting a
SecretID stops new logins; it revokes nothing.

Run `make reset` from the repository root to return to an uninitialised
Vault if you need a clean start.
