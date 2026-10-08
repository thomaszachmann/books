# Day 13

**Tag 13: Governance – Root-Token, Rekey, Rotation, Namespaces, Konfiguration als Code**

Starts from Tag 12. Leaves no root token, the userpass users `admin` (policy `bao-admin`) and `breakglass`, rotated recovery keys and keyring, the namespace `team-shop`, and an OpenTofu configuration without drift.

The book works in `~/bao-lab/tag13`.

| File | Book step | Goes to |
|---|---|---|
| `bao-admin.hcl` | Drill 1 | `~/bao-lab/tag13/` |
| `break-glass.hcl` | Drill 3 | stdin of `bao policy write break-glass -` |
| `shop-dev.hcl` | Drill 8 | stdin of `bao policy write -namespace=team-shop shop-dev -` |
| `tofu/main.tf` | Drill 9 | `~/bao-lab/tag13/tofu/main.tf` |
| `selfinit/config.hcl.tmpl` | Drill 10 | run inside `~/bao-lab/tag13/selfinit`: `PWD=$PWD envsubst < config.hcl.tmpl > config.hcl` |
| `check.sh` | Kontrollpunkt | `bash check.sh` against that day's lab |
| `challenge/main.tf.append` | Challenge, Lösung | appended: `cat main.tf.append >> ~/bao-lab/tag13/tofu/main.tf` |

`gr.json`, `recovery-neu.json`, `unseal.key`, the OpenTofu state and `.terraform/` hold key material or secrets and are not included.
