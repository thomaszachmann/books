# Day 6

**Tag 6: Identität, Gruppen und Audit**

Starts from a fresh dev server **with** `-config=$HOME/bao-lab/tag06/audit.hcl`. Leaves the entity `thomas` with two aliases (userpass, AppRole), the group `platform-team` and two audit devices, `file/` and `stdout/`.

The book works in `~/bao-lab/tag06`.

| File | Book step | Goes to |
|---|---|---|
| `audit.hcl.tmpl` | Drill 1 | `envsubst < audit.hcl.tmpl > ~/bao-lab/tag06/audit.hcl` (needs `$HOME`) |
| `webshop-read.hcl`, `ops-admin.hcl` | Drill 3 | stdin of `bao policy write …` |
| `audit-stdout.hcl` | Drill 10 | appended: `cat audit-stdout.hcl >> ~/bao-lab/tag06/audit.hcl`, then SIGHUP |
| `check.sh` | Kontrollpunkt | `bash check.sh` against that day's lab |

This `webshop-read.hcl` is shorter than Tag 2's — the book writes a new one for this day.
