# Chapter 14 — Response Wrapping and Secret Zero

**Starting state:** Vault unsealed, root token exported.

**What this chapter builds:** an AppRole whose SecretID is delivered
wrapped, and the interception drill that shows why that matters.

```bash
./setup-wrapping.sh
./deliver-secret-id.sh        # the operator side
./consume-secret-id.sh <wrapping-token>   # the application side
```

Run `consume-secret-id.sh` twice with the same token. The second run
fails, and that failure is the entire point of the chapter.
