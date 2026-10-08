# Day 2

**Tag 2: Tokens und Policies**

Starts from a fresh dev server. Leaves the policies `token-creator`, `webshop-read`, `apps-config` and `shop-writer` and test secrets under `secret/webshop`, `secret/billing` and `secret/apps`.

The book works in `~/bao-lab/tag02`.

| File | Book step | Goes to |
|---|---|---|
| `webshop-read.hcl` | Drill 5 | `~/bao-lab/tag02/` |
| `token-creator.hcl` | Drill 3 | stdin of `bao policy write token-creator -` |
| `apps-config.hcl` | Drill 7 | stdin of `bao policy write apps-config -` |
| `shop-writer.hcl` | Drill 8 | `~/bao-lab/tag02/` |
| `check.sh` | Kontrollpunkt | `bash check.sh` against that day's lab |
| `challenge/webshop-ops.hcl` | Challenge, Lösung | stdin of `bao policy write webshop-ops -` |

Policies the book pipes into `bao policy write <name> -` are kept as `<name>.hcl`; `bao policy write <name> <name>.hcl` does the same.
