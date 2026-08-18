# Chapter 20 — Storage Backends

**Starting state:** the single Vault container from Chapter 2, unsealed,
with everything the book has put into it.

**What this chapter does:** migrates a live installation from `file` to
Integrated Storage (Raft), which is what unlocks HA in Chapter 21.

```bash
./record-state.sh > /tmp/before.txt   # so you can prove nothing was lost
./migrate-to-raft.sh
./record-state.sh > /tmp/after.txt
diff /tmp/before.txt /tmp/after.txt   # expect no differences
```

The `file` data is left intact. **Do not delete it on migration day** —
delete it after the new backend has survived a week, a restart and a
snapshot restore.
