# Day 4

**Tag 4: Dynamische Datenbank-Secrets**

Starts from a fresh dev server and a Postgres 16 container `bao-pg`. Leaves the database engine with the connection `webshop-db`, the dynamic role `webshop-ro`, the static role `webshop-app` and the policy `webshop-db`.

The book works in `~/bao-lab/tag04`.

| File | Book step | Goes to |
|---|---|---|
| `webshop-ro.sql` | Drill 4 | `~/bao-lab/tag04/`, used as `creation_statements=@webshop-ro.sql` |
| `webshop-db.hcl` | Drill 9 | stdin of `bao policy write webshop-db -` |
| `check.sh` | Kontrollpunkt | `bash check.sh` against that day's lab |

`lab-pg-pw` and `lab-alt-pw` are lab values. `creds.json` (Drill 5) holds a live database password and is not included.
