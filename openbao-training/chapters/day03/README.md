# Day 3

**Tag 3: Auth-Methoden – userpass, AppRole und Response Wrapping**

Starts from a fresh dev server. Leaves userpass (users `thomas`, `anna`, TTL 30m), the AppRole `webshop` bound to `127.0.0.1/32`, the policy `webshop-deployer` and the challenge role `batch-job`.

The book works in `~/bao-lab/tag03`.

| File | Book step | Goes to |
|---|---|---|
| `webshop-deployer.hcl` | Drill 7 | `~/bao-lab/tag03/` |
| `check.sh` | Kontrollpunkt | `bash check.sh` against that day's lab |

Drill 1 copies `../tag02/webshop-read.hcl` — use `../day02/webshop-read.hcl` from here.
