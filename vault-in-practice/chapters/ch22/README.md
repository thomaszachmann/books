# Chapter 22 — Auto-Unseal

**Starting state:** the single-node lab from Chapter 20 (Raft), unsealed.

**What this chapter builds:** auto-unseal using the OpenBao container from
Chapter 18 as the unsealer — no cloud account required.

```bash
./setup-unsealer.sh       # transit key, policy, periodic token
./migrate-to-autounseal.sh
docker compose restart vault && sleep 6 && vault status

./break-circular.sh       # point the seal at itself, watch it never start
./migrate-to-shamir.sh    # and back, because you should know both
```

The point of the chapter is one line of output after a restart:
`Sealed false`, with nobody having done anything.
