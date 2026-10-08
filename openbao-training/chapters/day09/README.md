# Day 9

**Tag 9: Init, Unseal, Raft und Failover**

Starts from Tag 8. Leaves the cluster initialised (5 shares, threshold 3), unsealed, with three Raft voters, KV v2 at `secret/` and `secret/failover-test`.

The book works in `~/bao-lab/k8s`.

| File | Book step | Goes to |
|---|---|---|
| `check.sh` | Kontrollpunkt | `bash check.sh` against that day's lab |

Drill 1 writes `~/bao-lab/k8s/init.json` with the unseal keys and the root token. It is not here and must never be committed; `.gitignore` blocks it.
