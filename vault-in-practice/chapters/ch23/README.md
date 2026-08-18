# Chapter 23 — Audit and Operations

**Starting state:** the single-node lab, unsealed.

**What this chapter builds:** audit devices, the fail-closed drill, a
backup script that records what a snapshot needs to be restorable, and a
restore rehearsal.

```bash
./setup-audit.sh
./fail-closed-drill.sh    # a total outage caused by a file permission
./backup-vault.sh
./restore-drill.sh
```

`fail-closed-drill.sh` is the one to run. Vault healthy, unsealed, and
refusing every request because it cannot write a log line.
