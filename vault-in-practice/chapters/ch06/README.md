# Chapter 06 — Policies

**Starting state:** Vault unsealed, `meridian` kv-v2 mount present.
Chapter 3 creates that mount. If you are starting here after a
`make reset`, run `./scripts/seed-lab.sh` first — without it you get
a 403 on `sys/internal/ui/mounts/meridian/...`, which looks like a
policy problem and is a missing mount.

**What this chapter builds:** Policies, including the broken one

Run `make reset` from the repository root to return to an uninitialised
Vault if you need a clean start.
