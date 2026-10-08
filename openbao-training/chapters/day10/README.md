# Day 10

**Tag 10: Auto-Unseal und Seal-Migration**

Starts from Tag 9. Leaves a second release `bao-unsealer` (namespace `unsealer`, standalone, pebbledb) with the transit key `autounseal`, and the `openbao` cluster migrated from Shamir to the transit seal — the five Shamir keys are now recovery keys.

The book works in `~/bao-lab/k8s`.

| File | Book step | Goes to |
|---|---|---|
| `unsealer-values.yaml` | Drill 1 | `~/bao-lab/k8s/unsealer-values.yaml` |
| `autounseal.hcl` | Drill 4 | `~/bao-lab/k8s/autounseal.hcl` |
| `values.yaml` | Drill 5 | `~/bao-lab/k8s/values.yaml` — Tag 8's file plus the two snippets, **composed** |
| `check.sh` | Kontrollpunkt | `bash check.sh` against that day's lab |

`values.yaml` is Tag 8's file with Drill 5's two snippets inserted where the book says: `extraSecretEnvironmentVars` under `server:` after `extraEnvironmentVars`, and `seal "transit"` at the end of `server.ha.raft.config`. `unsealer-init.json` and `unseal-token.json` hold a root token and the transit token; they are not here.
